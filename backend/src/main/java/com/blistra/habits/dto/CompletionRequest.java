package com.blistra.habits.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Payload for recording a completion.
 *
 * <p>{@code completedOn} is the calendar day the completion is recorded for
 * (the client supplies its local date so the server stays timezone-agnostic).
 * {@code value} is meaningful only for {@code COUNT} habits and
 * {@code durationMinutes} only for {@code DURATION} habits; the service rejects
 * inconsistent shapes.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CompletionRequest {

    @NotNull(message = "Completed on is required")
    @PastOrPresent(message = "Completed on cannot be in the future")
    private LocalDate completedOn;

    @DecimalMin(value = "0.0", message = "Value cannot be negative")
    private BigDecimal value;

    @Min(value = 1, message = "Duration must be at least 1 minute")
    private Integer durationMinutes;

    @AssertTrue(message = "Value and duration must not both be provided")
    public boolean isNotAmbiguous() {
        return value == null || durationMinutes == null;
    }
}