package com.blistra.diet.application;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * A user's local calendar day expressed as a half-open instants range
 * {@code [start, end)}.
 *
 * <p>The day boundary is derived from a client-provided UTC offset in minutes
 * (the user's <em>current</em> local offset) instead of server-local time, so
 * "today" and "yesterday" follow the user's calendar day. The offset is a
 * request-scoped hint and is never stored: DST transitions are safe because
 * each request carries the offset in force <em>now</em> while all persisted
 * moments stay UTC. The window is half-open so a row exactly at midnight
 * belongs to exactly one day.</p>
 */
public record DayRange(OffsetDateTime start, OffsetDateTime end) {

    public static DayRange of(LocalDate date, int offsetMinutes) {
        ZoneOffset offset = ZoneOffset.ofTotalSeconds(offsetMinutes * 60);
        return new DayRange(
                date.atStartOfDay().atOffset(offset),
                date.plusDays(1).atStartOfDay().atOffset(offset));
    }
}