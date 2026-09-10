package com.blistra.habits;

import com.blistra.habits.domain.HabitFrequency;
import com.blistra.habits.dto.ScheduleRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.DayOfWeek;
import java.util.List;

import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The single recurring schedule attached to a habit.
 */
class HabitScheduleIntegrationTest extends HabitsTestSupport {

    private static final String HABITS_URL = "/api/v1/habits";

    @Test
    void getScheduleWithoutOneReturnsNotFound() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Meditate");

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void upsertDailySchedule() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Meditate");

        mockMvc.perform(put(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(ScheduleRequest.builder()
                        .frequency(HabitFrequency.DAILY)
                        .build())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.habitId", is(habitId)))
                .andExpect(jsonPath("$.frequency", is("DAILY")))
                .andExpect(jsonPath("$.daysOfWeek", empty()));

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.frequency", is("DAILY")));
    }

    @Test
    void upsertWeeklyScheduleRequiresDays() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Gym");

        mockMvc.perform(put(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(ScheduleRequest.builder()
                        .frequency(HabitFrequency.WEEKLY)
                        .daysOfWeek(List.of(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY, DayOfWeek.FRIDAY))
                        .build())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.daysOfWeek", hasSize(3)));

        mockMvc.perform(put(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(ScheduleRequest.builder()
                        .frequency(HabitFrequency.WEEKLY)
                        .build())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void dailyScheduleRejectsSpecificDays() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Stretch");

        mockMvc.perform(put(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(ScheduleRequest.builder()
                        .frequency(HabitFrequency.DAILY)
                        .daysOfWeek(List.of(DayOfWeek.MONDAY))
                        .build())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void upsertTwiceKeepsSingleSchedule() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Water");

        upsertSchedule(token, habitId, HabitFrequency.DAILY, List.of());
        upsertSchedule(token, habitId, HabitFrequency.WEEKLY, List.of(DayOfWeek.SUNDAY));

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/schedule")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.frequency", is("WEEKLY")))
                .andExpect(jsonPath("$.daysOfWeek", hasSize(1)));
    }

    @Test
    void userCannotManageAnotherUsersSchedule() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceHabitId = createBooleanHabit(alice, "Alice habit");
        upsertSchedule(alice, aliceHabitId, HabitFrequency.DAILY, List.of());

        mockMvc.perform(get(HABITS_URL + "/" + aliceHabitId + "/schedule")
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(put(HABITS_URL + "/" + aliceHabitId + "/schedule")
                .header("Authorization", "Bearer " + bob)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(ScheduleRequest.builder()
                        .frequency(HabitFrequency.DAILY)
                        .build())))
                .andExpect(status().isNotFound());
    }
}