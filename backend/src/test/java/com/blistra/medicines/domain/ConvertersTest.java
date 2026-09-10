package com.blistra.medicines.domain;

import org.junit.jupiter.api.Test;

import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ConvertersTest {

    private final LocalTimeListConverter timeConverter = new LocalTimeListConverter();
    private final DayOfWeekListConverter dayConverter = new DayOfWeekListConverter();

    @Test
    void localTimeListRoundTrips() {
        List<LocalTime> times = List.of(LocalTime.of(8, 0), LocalTime.of(20, 30));
        String db = timeConverter.convertToDatabaseColumn(times);
        assertThat(db).isEqualTo("08:00,20:30");
        assertThat(timeConverter.convertToEntityAttribute(db)).containsExactlyElementsOf(times);
    }

    @Test
    void localTimeListHandlesEmptyAndNull() {
        assertThat(timeConverter.convertToDatabaseColumn(null)).isEmpty();
        assertThat(timeConverter.convertToDatabaseColumn(List.of())).isEmpty();
        assertThat(timeConverter.convertToEntityAttribute("")).isEmpty();
        assertThat(timeConverter.convertToEntityAttribute(null)).isEmpty();
    }

    @Test
    void dayOfWeekListRoundTrips() {
        List<DayOfWeek> days = List.of(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY);
        String db = dayConverter.convertToDatabaseColumn(days);
        assertThat(db).isEqualTo("MONDAY,WEDNESDAY");
        assertThat(dayConverter.convertToEntityAttribute(db)).containsExactlyElementsOf(days);
    }

    @Test
    void dayOfWeekListHandlesEmptyAndNull() {
        assertThat(dayConverter.convertToDatabaseColumn(null)).isEmpty();
        assertThat(dayConverter.convertToDatabaseColumn(List.of())).isEmpty();
        assertThat(dayConverter.convertToEntityAttribute("")).isEmpty();
        assertThat(dayConverter.convertToEntityAttribute(null)).isEmpty();
    }
}