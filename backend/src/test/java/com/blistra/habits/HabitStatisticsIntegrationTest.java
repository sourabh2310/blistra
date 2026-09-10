package com.blistra.habits;

import com.blistra.habits.domain.HabitFrequency;
import org.junit.jupiter.api.Test;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;

import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Streak and completion summarisation, exercising the recurrence rules the
 * statistics are derived from.
 */
class HabitStatisticsIntegrationTest extends HabitsTestSupport {

    private static final String HABITS_URL = "/api/v1/habits";

    @Test
    void newHabitHasEmptyStatistics() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Read");

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/statistics")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCompletions", is(0)))
                .andExpect(jsonPath("$.currentStreak", is(0)))
                .andExpect(jsonPath("$.bestStreak", is(0)))
                .andExpect(jsonPath("$.lastCompletedOn", nullValue()));
    }

    @Test
    void dailyCurrentStreakCountsTodayWhenCompleted() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Stretch");
        upsertSchedule(token, habitId, HabitFrequency.DAILY, List.of());
        LocalDate today = LocalDate.now();

        recordCompletion(token, habitId, today.minusDays(1), null, null);
        recordCompletion(token, habitId, today, null, null);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/statistics")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCompletions", is(2)))
                .andExpect(jsonPath("$.currentStreak", is(2)))
                .andExpect(jsonPath("$.bestStreak", is(2)))
                .andExpect(jsonPath("$.lastCompletedOn", is(today.toString())));
    }

    @Test
    void pendingTodayDoesNotBreakDailyStreak() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Stretch");
        upsertSchedule(token, habitId, HabitFrequency.DAILY, List.of());

        recordCompletion(token, habitId, LocalDate.now().minusDays(1), null, null);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/statistics")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCompletions", is(1)))
                .andExpect(jsonPath("$.currentStreak", is(1)))
                .andExpect(jsonPath("$.bestStreak", is(1)))
                .andExpect(jsonPath("$.lastCompletedOn", is(LocalDate.now().minusDays(1).toString())));
    }

    @Test
    void missedDayBreaksCurrentStreak() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Stretch");
        upsertSchedule(token, habitId, HabitFrequency.DAILY, List.of());
        LocalDate today = LocalDate.now();

        recordCompletion(token, habitId, today.minusDays(2), null, null);
        recordCompletion(token, habitId, today, null, null);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/statistics")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCompletions", is(2)))
                .andExpect(jsonPath("$.currentStreak", is(1)))
                .andExpect(jsonPath("$.bestStreak", is(1)));
    }

    @Test
    void backfilledDaysCountTowardCurrentStreak() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Run");
        upsertSchedule(token, habitId, HabitFrequency.DAILY, List.of());
        LocalDate today = LocalDate.now();

        recordCompletion(token, habitId, today.minusDays(3), null, null);
        recordCompletion(token, habitId, today.minusDays(2), null, null);
        recordCompletion(token, habitId, today.minusDays(1), null, null);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/statistics")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCompletions", is(3)))
                .andExpect(jsonPath("$.currentStreak", is(3)))
                .andExpect(jsonPath("$.bestStreak", is(3)))
                .andExpect(jsonPath("$.lastCompletedOn", is(today.minusDays(1).toString())));
    }

    @Test
    void gapSeparatesBestStreakRuns() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Run");
        upsertSchedule(token, habitId, HabitFrequency.DAILY, List.of());
        LocalDate today = LocalDate.now();

        recordCompletion(token, habitId, today.minusDays(5), null, null);
        recordCompletion(token, habitId, today.minusDays(4), null, null);
        recordCompletion(token, habitId, today, null, null);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/statistics")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCompletions", is(3)))
                .andExpect(jsonPath("$.currentStreak", is(1)))
                .andExpect(jsonPath("$.bestStreak", is(2)));
    }

    @Test
    void weeklyStreakCountsOnlySelectedDays() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String habitId = createBooleanHabit(token, "Gym");
        LocalDate today = LocalDate.now();
        LocalDate d1 = today.minusDays(6);
        LocalDate d2 = today.minusDays(4);
        LocalDate d3 = today.minusDays(2);
        List<DayOfWeek> selected = List.of(d1.getDayOfWeek(), d2.getDayOfWeek(), d3.getDayOfWeek());

        upsertSchedule(token, habitId, HabitFrequency.WEEKLY, selected);
        recordCompletion(token, habitId, d1, null, null);
        recordCompletion(token, habitId, d2, null, null);
        recordCompletion(token, habitId, d3, null, null);

        mockMvc.perform(get(HABITS_URL + "/" + habitId + "/statistics")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalCompletions", is(3)))
                .andExpect(jsonPath("$.currentStreak", is(3)))
                .andExpect(jsonPath("$.bestStreak", is(3)));
    }

    @Test
    void userCannotReadAnotherUsersStatistics() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");
        String aliceHabitId = createBooleanHabit(alice, "Read");

        mockMvc.perform(get(HABITS_URL + "/" + aliceHabitId + "/statistics")
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }
}