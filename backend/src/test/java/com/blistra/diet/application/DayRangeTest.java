package com.blistra.diet.application;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Date-boundary regression tests for request-scoped day windows.
 */
class DayRangeTest {

    @Test
    void istDayMapsToCorrectUtcInstants() {
        DayRange range = DayRange.of(LocalDate.parse("2026-09-10"), 330);

        assertThat(range.start()).isEqualTo(OffsetDateTime.parse("2026-09-09T18:30:00Z"));
        assertThat(range.end()).isEqualTo(OffsetDateTime.parse("2026-09-10T18:30:00Z"));
    }

    @Test
    void utcDayIsMidnightToMidnight() {
        DayRange range = DayRange.of(LocalDate.parse("2026-09-10"), 0);

        assertThat(range.start()).isEqualTo(OffsetDateTime.parse("2026-09-10T00:00:00Z"));
        assertThat(range.end()).isEqualTo(OffsetDateTime.parse("2026-09-11T00:00:00Z"));
    }

    @Test
    void extremeOffsetsStay24Hours() {
        // Kiritimati (+14:00) and Baker Island (-12:00): the full legal range.
        DayRange plus = DayRange.of(LocalDate.parse("2026-09-10"), 840);
        assertThat(plus.start()).isEqualTo(OffsetDateTime.parse("2026-09-09T10:00:00Z"));
        assertThat(plus.end()).isEqualTo(OffsetDateTime.parse("2026-09-10T10:00:00Z"));

        DayRange minus = DayRange.of(LocalDate.parse("2026-09-10"), -720);
        assertThat(minus.start()).isEqualTo(OffsetDateTime.parse("2026-09-10T12:00:00Z"));
        assertThat(minus.end()).isEqualTo(OffsetDateTime.parse("2026-09-11T12:00:00Z"));

        assertThat(plus.start().toInstant().plusSeconds(86400)).isEqualTo(plus.end().toInstant());
        assertThat(minus.start().toInstant().plusSeconds(86400)).isEqualTo(minus.end().toInstant());
    }

    @Test
    void windowIsHalfOpen() {
        DayRange range = DayRange.of(LocalDate.parse("2026-09-10"), 330);

        // [start, end): start belongs to the day, end belongs to the next day.
        assertThat(range.start().toLocalDateTime().toLocalTime().toSecondOfDay()).isZero();
        assertThat(range.start().getOffset()).isEqualTo(ZoneOffset.ofHoursMinutes(5, 30));
        assertThat(range.end()).isEqualTo(range.start().plusDays(1));
    }
}
