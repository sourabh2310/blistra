package com.blistra.habits.dto;

import com.blistra.habits.domain.HabitFrequency;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Schedule representation returned to clients.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ScheduleResponse {

    private UUID id;
    private UUID habitId;
    private HabitFrequency frequency;
    private List<DayOfWeek> daysOfWeek;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}