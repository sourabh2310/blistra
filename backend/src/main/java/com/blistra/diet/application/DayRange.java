package com.blistra.diet.application;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * A user's local calendar day expressed as an instants range.
 *
 * <p>The day boundary is derived from a client-provided UTC offset in minutes
 * (the user's current local offset) instead of server-local time, so "today"
 * and "yesterday" follow the user's calendar day.</p>
 */
public record DayRange(OffsetDateTime start, OffsetDateTime end) {

    public static DayRange of(LocalDate date, int offsetMinutes) {
        ZoneOffset offset = ZoneOffset.ofTotalSeconds(offsetMinutes * 60);
        return new DayRange(
                date.atStartOfDay().atOffset(offset),
                date.plusDays(1).atStartOfDay().atOffset(offset));
    }
}