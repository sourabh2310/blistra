package com.blistra.habits.dto;

import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.domain.HabitType;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Create/update payload for a {@link com.blistra.habits.domain.Habit}.
 *
 * <p>Ownership fields (user id) and audit timestamps are never accepted from
 * the client. The recurring schedule is managed through the habit's schedule
 * endpoint.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HabitRequest {

    @NotBlank(message = "Name is required")
    @Size(max = 100, message = "Name must be at most 100 characters")
    private String name;

    @Size(max = 500, message = "Description must be at most 500 characters")
    private String description;

    @NotNull(message = "Type is required")
    private HabitType type;

    private HabitStatus status;

    @DecimalMin(value = "0.0", message = "Target value cannot be negative")
    @Digits(integer = 12, fraction = 4, message = "Target value has too many digits")
    private BigDecimal targetValue;

    @Size(max = 25, message = "Target unit must be at most 25 characters")
    private String targetUnit;

    @Min(value = 1, message = "Target minutes must be at least 1")
    private Integer targetMinutes;

    /**
     * Keeps the target shape consistent with the habit type so the database
     * never stores contradictory records.
     */
    @AssertTrue(message = "Target fields are inconsistent with the habit type")
    public boolean isTargetsValid() {
        if (type == HabitType.BOOLEAN) {
            return targetValue == null && targetUnit == null && targetMinutes == null;
        }
        if (type == HabitType.COUNT) {
            return targetMinutes == null;
        }
        if (type == HabitType.DURATION) {
            return targetValue == null && targetUnit == null;
        }
        return true;
    }
}