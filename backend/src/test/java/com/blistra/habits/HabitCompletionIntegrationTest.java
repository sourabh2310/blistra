package com.blistra.habits;

import com.blistra.habits.domain.HabitType;
import com.blistra.habits.dto.CompletionRequest;
import com.blistra.habits.dto.HabitRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Single-day completion records, including the upsert semantics per habit/day.
 */
class HabitCompletionIntegrationTest extends HabitsTestSupport {

    private static final String HABITS_URL = "/api/v1/habits";

    @Test
    void recordBooleanCompletion() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Read");

        mockMvc.perform(post(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(CompletionRequest.builder()
                        .completedOn(LocalDate.now())
                        .build())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.habitId", is(habitId)))
                .andExpect(jsonPath("$.completedOn", is(LocalDate.now().toString())))
                .andExpect(jsonPath("$.value", nullValue()))
                .andExpect(jsonPath("$.durationMinutes", nullValue()));
    }

    @Test
    void recordingSameDayUpdatesNotDuplicates() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createHabit(token, habitRequest("Glasses of water", HabitType.COUNT,
                new BigDecimal("8"), "glasses", null, null));

        recordCompletion(token, habitId, LocalDate.now(), new BigDecimal("5"), null);

        MvcResult result = mockMvc.perform(post(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(CompletionRequest.builder()
                        .completedOn(LocalDate.now())
                        .value(new BigDecimal("6"))
                        .build())))
                .andExpect(status().isCreated())
                .andReturn();
        String updatedValue = jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("value").asText();

        org.junit.jupiter.api.Assertions.assertEquals("6.0000", updatedValue);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(1)))
                .andExpect(jsonPath("$.totalElements", is(1)));
    }

    @Test
    void recordCountWithDurationRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createHabit(token, habitRequest("Push-ups", HabitType.COUNT,
                new BigDecimal("20"), "reps", null, null));

        mockMvc.perform(post(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(CompletionRequest.builder()
                        .completedOn(LocalDate.now())
                        .durationMinutes(20)
                        .build())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void recordBooleanWithValueRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Read");

        mockMvc.perform(post(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(CompletionRequest.builder()
                        .completedOn(LocalDate.now())
                        .value(new BigDecimal("5"))
                        .build())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void recordDurationWithValueRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createHabit(token, habitRequest("Meditate", HabitType.DURATION,
                null, null, 20, null));

        mockMvc.perform(post(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(CompletionRequest.builder()
                        .completedOn(LocalDate.now())
                        .value(new BigDecimal("20"))
                        .build())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void futureCompletionRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Read");

        mockMvc.perform(post(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(CompletionRequest.builder()
                        .completedOn(LocalDate.now().plusDays(1))
                        .build())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void historyIsNewestFirst() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Read");
        LocalDate today = LocalDate.now();

        recordCompletion(token, habitId, today.minusDays(3), null, null);
        recordCompletion(token, habitId, today.minusDays(1), null, null);
        recordCompletion(token, habitId, today.minusDays(2), null, null);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(3)))
                .andExpect(jsonPath("$.content[0].completedOn", is(today.minusDays(1).toString())))
                .andExpect(jsonPath("$.content[2].completedOn", is(today.minusDays(3).toString())));
    }

    @Test
    void removeDeletesCompletion() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Read");
        LocalDate yesterday = LocalDate.now().minusDays(1);
        recordCompletion(token, habitId, yesterday, null, null);

        mockMvc.perform(delete(HABITS_URL + "/" + habitId + "/completions/" + yesterday)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/completions")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content", hasSize(0)));
    }

    @Test
    void removeMissingCompletionReturnsNotFound() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Read");

        mockMvc.perform(delete(HABITS_URL + "/" + habitId + "/completions/" + LocalDate.now().minusDays(5))
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotManageAnotherUsersCompletions() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceHabitId = createBooleanHabit(alice, "Alice habit");

        mockMvc.perform(post(HABITS_URL + "/" + aliceHabitId + "/completions")
                .header("Authorization", "Bearer " + bob)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(CompletionRequest.builder()
                        .completedOn(LocalDate.now())
                        .build())))
                .andExpect(status().isNotFound());

        mockMvc.perform(get(HABITS_URL + "/" + aliceHabitId + "/completions")
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(HABITS_URL + "/" + aliceHabitId + "/completions/" + LocalDate.now())
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }
}