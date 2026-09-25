package com.blistra.planner.application;

import com.blistra.common.time.UserTime;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Deterministic semantics for all-day (date-only) vs timed tasks.
 * All-day tasks resolve to midnight for storage but must be compared
 * by calendar date (todayStart boundary), never against "now".
 */
class PlannerTimeTest {

    private final PlannerTime time = new PlannerTime(new UserTime("Asia/Kolkata"));

    private static boolean isOverdueModel(LocalDate dueDate, LocalTime dueTime,
                                          OffsetDateTime dueAt, OffsetDateTime todayStart,
                                          OffsetDateTime now) {
        if (dueAt == null) {
            return false;
        }
        // Mirrors PlannerTaskService.isOverdue + TaskRepository.findOverdue:
        // all-day (dueTime == null) is overdue only when before today's start.
        boolean beforeToday = dueAt.isBefore(todayStart);
        boolean dueEarlierToday = dueTime != null && dueAt.isBefore(now);
        return beforeToday || dueEarlierToday;
    }

    @Test
    void allDayDueToday_isNotOverdue() {
        LocalDate today = LocalDate.of(2026, 3, 10);
        OffsetDateTime todayStart = today.atStartOfDay(time.userZone()).toOffsetDateTime();
        OffsetDateTime now = today.atTime(12, 0).atZone(time.userZone()).toOffsetDateTime();
        OffsetDateTime dueAt = time.resolveDueAt(today, null);
        assertThat(isOverdueModel(today, null, dueAt, todayStart, now)).isFalse();
    }

    @Test
    void allDayDueYesterday_isOverdue() {
        LocalDate today = LocalDate.of(2026, 3, 10);
        OffsetDateTime todayStart = today.atStartOfDay(time.userZone()).toOffsetDateTime();
        OffsetDateTime now = today.atTime(0, 1).atZone(time.userZone()).toOffsetDateTime();
        LocalDate yesterday = today.minusDays(1);
        assertThat(isOverdueModel(yesterday, null, time.resolveDueAt(yesterday, null),
                todayStart, now)).isTrue();
    }

    @Test
    void allDayDueTomorrow_isNotOverdue() {
        LocalDate today = LocalDate.of(2026, 3, 10);
        OffsetDateTime todayStart = today.atStartOfDay(time.userZone()).toOffsetDateTime();
        OffsetDateTime now = today.atTime(23, 59).atZone(time.userZone()).toOffsetDateTime();
        LocalDate tomorrow = today.plusDays(1);
        assertThat(isOverdueModel(tomorrow, null, time.resolveDueAt(tomorrow, null),
                todayStart, now)).isFalse();
    }

    @Test
    void timedEarlierToday_isOverdue() {
        LocalDate today = LocalDate.of(2026, 3, 10);
        OffsetDateTime todayStart = today.atStartOfDay(time.userZone()).toOffsetDateTime();
        OffsetDateTime now = today.atTime(12, 0).atZone(time.userZone()).toOffsetDateTime();
        LocalTime earlier = LocalTime.of(9, 0);
        assertThat(isOverdueModel(today, earlier, time.resolveDueAt(today, earlier),
                todayStart, now)).isTrue();
    }

    @Test
    void timedLaterToday_isNotOverdue() {
        LocalDate today = LocalDate.of(2026, 3, 10);
        OffsetDateTime todayStart = today.atStartOfDay(time.userZone()).toOffsetDateTime();
        OffsetDateTime now = today.atTime(12, 0).atZone(time.userZone()).toOffsetDateTime();
        LocalTime later = LocalTime.of(18, 0);
        assertThat(isOverdueModel(today, later, time.resolveDueAt(today, later),
                todayStart, now)).isFalse();
    }

    @Test
    void midnightBoundary_allDayTodayNotOverdueJustAfterMidnight() {
        LocalDate today = LocalDate.of(2026, 3, 10);
        OffsetDateTime todayStart = today.atStartOfDay(time.userZone()).toOffsetDateTime();
        OffsetDateTime justAfterMidnight = today.atTime(0, 0, 1).atZone(time.userZone()).toOffsetDateTime();
        assertThat(isOverdueModel(today, null, time.resolveDueAt(today, null),
                todayStart, justAfterMidnight)).isFalse();
    }

    @Test
    void configuredTimezone_isHonored() {
        PlannerTime auckland = new PlannerTime(new UserTime("Pacific/Auckland"));
        assertThat(auckland.userZone().getId()).isEqualTo("Pacific/Auckland");
        LocalDate date = LocalDate.of(2026, 3, 10);
        assertThat(auckland.resolveDueAt(date, null).getOffset())
                .isEqualTo(date.atStartOfDay(auckland.userZone()).getOffset());
    }
}
