package com.blistra.habits.application;

import com.blistra.habits.domain.HabitSchedule;
import com.blistra.habits.dto.ScheduleResponse;

/**
 * Maps {@link HabitSchedule} to its response representation.
 */
public final class ScheduleConverter {

    private ScheduleConverter() {
    }

    public static ScheduleResponse toResponse(HabitSchedule schedule) {
        return ScheduleResponse.builder()
                .id(schedule.getId())
                .habitId(schedule.getHabit().getId())
                .frequency(schedule.getFrequency())
                .daysOfWeek(schedule.getDaysOfWeek())
                .createdAt(schedule.getCreatedAt())
                .updatedAt(schedule.getUpdatedAt())
                .build();
    }
}