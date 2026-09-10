package com.blistra.habits;

import com.blistra.habits.domain.HabitFrequency;
import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.domain.HabitType;
import com.blistra.habits.dto.HabitRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.util.List;

import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * CRUD, validation, and default behaviour of the habit resource.
 */
class HabitIntegrationTest extends HabitsTestSupport {

    private static final String HABITS_URL = "/api/v1/habits";

    @Test
    void unauthenticatedRequestsAreRejected() throws Exception {
        mockMvc.perform(get(HABITS_URL))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void createReturnsCreatedWithDefaults() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(habitRequest("Read 20 minutes", HabitType.DURATION,
                        null, null, 20, null))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.name", is("Read 20 minutes")))
                .andExpect(jsonPath("$.type", is("DURATION")))
                .andExpect(jsonPath("$.targetMinutes", is(20)))
                .andExpect(jsonPath("$.status", is("ACTIVE")))
                .andExpect(jsonPath("$.createdAt").isNotEmpty())
                .andExpect(jsonPath("$.updatedAt").isNotEmpty());
    }

    @Test
    void createCannotForceArchivedStatusOnNewHabit() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(habitRequest("Run", HabitType.BOOLEAN,
                        null, null, null, HabitStatus.ARCHIVED))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status", is("ACTIVE")));
    }

    @Test
    void rejectCountHabitWithDurationTarget() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        HabitRequest request = HabitRequest.builder()
                .name("Glasses of water")
                .type(HabitType.COUNT)
                .targetValue(new BigDecimal("8"))
                .targetUnit("glasses")
                .targetMinutes(10)
                .build();

        mockMvc.perform(post(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void rejectBooleanHabitWithTargetValue() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        HabitRequest request = HabitRequest.builder()
                .name("Read")
                .type(HabitType.BOOLEAN)
                .targetValue(new BigDecimal("5"))
                .build();

        mockMvc.perform(post(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void rejectBlankName() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"\",\"type\":\"BOOLEAN\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void listReturnsOwnHabitsPaged() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        createBooleanHabit(token, "Read a book");
        createBooleanHabit(token, "Walk outside");

        mockMvc.perform(get(HABITS_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(2)))
                .andExpect(jsonPath("$.totalElements", is(2)))
                .andExpect(jsonPath("$.page", is(0)));
    }

    @Test
    void getReturnsOwnedHabit() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String id = createBooleanHabit(token, "Drink water");

        mockMvc.perform(get(HABITS_URL + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id", is(id)))
                .andExpect(jsonPath("$.name", is("Drink water")))
                .andExpect(jsonPath("$.status", is("ACTIVE")));
    }

    @Test
    void updateModifiesHabit() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String id = createBooleanHabit(token, "Drink water");

        mockMvc.perform(put(HABITS_URL + "/" + id)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(habitRequest("Drink more water", HabitType.BOOLEAN,
                        null, null, null, HabitStatus.PAUSED))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name", is("Drink more water")))
                .andExpect(jsonPath("$.status", is("PAUSED")));
    }

    @Test
    void archiveHidesHabitFromDefaultListing() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String id = createBooleanHabit(token, "Meditate");

        mockMvc.perform(delete(HABITS_URL + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .param("status", "ACTIVE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)));

        mockMvc.perform(get(HABITS_URL)
                .header("Authorization", "Bearer " + token)
                .param("status", "ARCHIVED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.content[0].id", is(id)));
    }

    @Test
    void todayListsOnlyActiveDueHabitsWithCompletionState() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String activeDaily = createBooleanHabit(token, "Daily stretch");
        String paused = createBooleanHabit(token, "Paused habit");
        String archived = createBooleanHabit(token, "Archived habit");
        upsertSchedule(token, activeDaily, HabitFrequency.DAILY, null);
        upsertSchedule(token, paused, HabitFrequency.DAILY, null);

        mockMvc.perform(delete(HABITS_URL + "/" + archived)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(put(HABITS_URL + "/" + paused)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(habitRequest("Paused habit", HabitType.BOOLEAN,
                        null, null, null, HabitStatus.PAUSED))))
                .andExpect(status().isOk());

        mockMvc.perform(get(HABITS_URL + "/today")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id", is(activeDaily)))
                .andExpect(jsonPath("$[0].completedToday", is(false)))
                .andExpect(jsonPath("$[0].schedule.frequency", is("DAILY")));
    }

    @Test
    void userCannotReadUpdateReplaceOrArchiveAnotherUsersHabit() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceHabitId = createBooleanHabit(alice, "Alice habit");

        mockMvc.perform(get(HABITS_URL + "/" + aliceHabitId)
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(put(HABITS_URL + "/" + aliceHabitId)
                .header("Authorization", "Bearer " + bob)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(habitRequest("Stolen", HabitType.BOOLEAN,
                        null, null, null, null))))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(HABITS_URL + "/" + aliceHabitId)
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(get(HABITS_URL + "/" + aliceHabitId)
                .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk());
    }

    @Test
    void todayIgnoresScheduleOfOtherUsers() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceHabitId = createBooleanHabit(alice, "Alice daily");

        mockMvc.perform(put(HABITS_URL + "/" + aliceHabitId + "/schedule")
                .header("Authorization", "Bearer " + bob)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(com.blistra.habits.dto.ScheduleRequest.builder()
                        .frequency(HabitFrequency.WEEKLY)
                        .daysOfWeek(List.of(DayOfWeek.MONDAY))
                        .build())))
                .andExpect(status().isNotFound());

        mockMvc.perform(get(HABITS_URL + "/today")
                .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }
}