package com.blistra.habits.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * Streak and completion summary for a habit.
 *
 * <p>{@code completionRate} is the fraction of due occurrences completed over
 * the habit's observed window (null when nothing was due yet). It describes
 * recorded behavior only.</p>
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
    private int dueOccurrences;
    private int completedDueOccurrences;
    private Double completionRate;
}