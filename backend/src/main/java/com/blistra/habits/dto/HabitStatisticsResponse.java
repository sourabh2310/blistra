package com.blistra.habits.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * Streak and completion summary for a habit.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HabitStatisticsResponse {

    private long totalCompletions;
    private int currentStreak;
    private int bestStreak;
    private LocalDate lastCompletedOn;
}