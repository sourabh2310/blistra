package com.blistra.habits.application;

import com.blistra.habits.domain.HabitSchedule;

import java.time.LocalDate;
import java.util.Set;

/**
 * Pure functions for the recurrence and streak semantics of a habit.
 *
 * <p>A habit without a schedule is treated as due every day so that ad-hoc
 * completions still produce meaningful streaks.</p>
 */
public final class HabitStreakCalculator {

    private HabitStreakCalculator() {
    }

    /**
     * Whether the habit is expected on {@code date} given its schedule.
     */
    public static boolean isDue(HabitSchedule schedule, LocalDate date) {
        if (schedule == null) {
            return true;
        }
        return switch (schedule.getFrequency()) {
            case DAILY -> true;
            case WEEKLY -> schedule.getDaysOfWeek().contains(date.getDayOfWeek());
        };
    }

    /**
     * Number of consecutive due days completed counting backwards from
     * {@code today}. A missed due day before today breaks the streak; a due
     * day equal to today that has not been completed yet does not break it
     * (the streak stays "alive" until the day ends). Non-due days are skipped.
     */
    public static int currentStreak(HabitSchedule schedule, Set<LocalDate> completedDays,
                                    LocalDate lowerBound, LocalDate today) {
        int streak = 0;
        LocalDate cursor = today;
        while (!cursor.isBefore(lowerBound)) {
            if (!isDue(schedule, cursor)) {
                cursor = cursor.minusDays(1);
                continue;
            }
            if (completedDays.contains(cursor)) {
                streak++;
                cursor = cursor.minusDays(1);
                continue;
            }
            if (cursor.isEqual(today)) {
                cursor = cursor.minusDays(1);
                continue;
            }
            break;
        }
        return streak;
    }

    /**
     * Longest run of consecutive completed due days up to {@code today} in the
     * habit's history. Missed due days reset the run; non-due days are skipped.
     */
    public static int bestStreak(HabitSchedule schedule, Set<LocalDate> completedDays,
                                 LocalDate lowerBound, LocalDate today) {
        int run = 0;
        int best = 0;
        LocalDate cursor = lowerBound;
        while (!cursor.isAfter(today)) {
            if (isDue(schedule, cursor)) {
                if (completedDays.contains(cursor)) {
                    run++;
                    if (run > best) {
                        best = run;
                    }
                } else {
                    run = 0;
                }
            }
            cursor = cursor.plusDays(1);
        }
        return best;
    }
}