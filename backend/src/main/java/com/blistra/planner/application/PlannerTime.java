package com.blistra.planner.application;

import com.blistra.common.time.UserTime;
import org.springframework.stereotype.Component;

import java.time.*;
import java.time.temporal.ChronoUnit;

/**
 * Minimal, injectable time foundation for Planner.
 *
 * <p>Planner is date/time sensitive. User-facing boundaries ("today", "overdue")
 * are computed in the {@link UserTime} zone - never the server-local zone - so
 * a user-local calendar day is interpreted correctly. This class only adds
 * Planner-specific day arithmetic; the zone itself is owned by
 * {@link UserTime}.</p>
 */
@Component
public class PlannerTime {

    private final ZoneId userZone;

    public PlannerTime(UserTime userTime) {
        this.userZone = userTime.zone();
    }

    public ZoneId userZone() {
        return userZone;
    }

    public OffsetDateTime now() {
        return OffsetDateTime.now(userZone);
    }

    public OffsetDateTime todayStart() {
        return ZonedDateTime.now(userZone).truncatedTo(ChronoUnit.DAYS).toOffsetDateTime();
    }

    public OffsetDateTime tomorrowStart() {
        return ZonedDateTime.now(userZone).toLocalDate().plusDays(1).atStartOfDay(userZone).toOffsetDateTime();
    }

    /**
     * Half-open day window for an explicit calendar date in the user zone.
     * Used for date navigation so "previous/next day" reloads exactly one day.
     */
    public OffsetDateTime dayStart(LocalDate date) {
        return date.atStartOfDay(userZone).toOffsetDateTime();
    }

    public OffsetDateTime dayEndExclusive(LocalDate date) {
        return date.plusDays(1).atStartOfDay(userZone).toOffsetDateTime();
    }

    public OffsetDateTime rangeEndExclusive(LocalDate date, int days) {
        int safeDays = Math.min(Math.max(days, 1), 31);
        return date.plusDays(safeDays).atStartOfDay(userZone).toOffsetDateTime();
    }

    /**
     * Resolves the user-facing calendar fields to a precise instant in the user
     * timezone. An all-day deadline resolves to the start of that calendar day.
     */
    public OffsetDateTime resolveDueAt(LocalDate dueDate, LocalTime dueTime) {
        if (dueDate == null) {
            return null;
        }
        LocalTime time = dueTime != null ? dueTime : LocalTime.MIDNIGHT;
        return LocalDateTime.of(dueDate, time).atZone(userZone).toOffsetDateTime();
    }
}