package com.blistra.habits.dto;

import com.blistra.habits.domain.HabitFrequency;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.DayOfWeek;
import java.util.HashSet;
import java.util.List;

/**
 * Create/update payload for a {@link com.blistra.habits.domain.HabitSchedule}.
 *
 * <p>A {@code DAILY} schedule is due every day and must not carry
 * {@code daysOfWeek}. A {@code WEEKLY} schedule must declare at least one day
 * of the week.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ScheduleRequest {

    @NotNull(message = "Frequency is required")
    private HabitFrequency frequency;

    @Size(max = 7, message = "At most 7 days of the week are allowed")
    private List<DayOfWeek> daysOfWeek;

    @AssertTrue(message = "A weekly schedule must declare at least one day of the week")
    public boolean isWeeklyDaysValid() {
        if (frequency == HabitFrequency.WEEKLY) {
            return daysOfWeek != null && !daysOfWeek.isEmpty();
        }
        return true;
    }

    @AssertTrue(message = "A daily schedule must not declare specific days of the week")
    public boolean isDailyDaysValid() {
        if (frequency == HabitFrequency.DAILY) {
            return daysOfWeek == null || daysOfWeek.isEmpty();
        }
        return true;
    }

    @AssertTrue(message = "Days of the week must be unique")
    public boolean isDaysUnique() {
        return daysOfWeek == null || daysOfWeek.size() == new HashSet<>(daysOfWeek).size();
    }
}