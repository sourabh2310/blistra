package com.blistra.medicines.dto;

import com.blistra.medicines.domain.ScheduleType;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;

/**
 * Create/update payload for a medication schedule.
 *
 * <p>{@link #getTimes()} holds time-of-day values as {@code HH:mm} strings
 * (for example {@code ["08:00", "20:00"]}). Times reflect the user's local
 * intent and are interpreted in the user's timezone.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ScheduleRequest {

    @NotNull(message = "Schedule type is required")
    private ScheduleType scheduleType;

    @Size(max = 10, message = "At most 10 times are allowed per schedule")
    private List<String> times;

    private List<DayOfWeek> daysOfWeek;

    @DecimalMin(value = "0.0", message = "Dose amount cannot be negative")
    @Digits(integer = 12, fraction = 4, message = "Dose amount has too many digits")
    private BigDecimal doseAmount;

    @Size(max = 25, message = "Dose unit must be at most 25 characters")
    private String doseUnit;

    private LocalDate startDate;

    private LocalDate endDate;

    private Boolean active;

    @AssertTrue(message = "At least one time is required for daily or weekly schedules")
    public boolean isTimesValid() {
        if (scheduleType == ScheduleType.AS_NEEDED) {
            return times == null || times.isEmpty();
        }
        return times != null && !times.isEmpty();
    }

    @AssertTrue(message = "At least one day of the week is required for weekly schedules")
    public boolean isDaysValid() {
        if (scheduleType == ScheduleType.DAILY || scheduleType == ScheduleType.AS_NEEDED) {
            return true;
        }
        return daysOfWeek != null && !daysOfWeek.isEmpty();
    }

    @AssertTrue(message = "End date must not be before the start date")
    public boolean isDatesValid() {
        return startDate == null || endDate == null || !endDate.isBefore(startDate);
    }
}