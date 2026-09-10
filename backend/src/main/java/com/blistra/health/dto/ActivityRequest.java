package com.blistra.health.dto;

import com.blistra.health.domain.ActivityType;
import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ActivityRequest {

    @NotNull(message = "Activity type is required")
    private ActivityType type;

    @NotNull(message = "Performed at is required")
    @PastOrPresent(message = "Activity time cannot be in the future")
    private OffsetDateTime performedAt;

    @NotNull(message = "Duration is required")
    @Min(value = 1, message = "Duration must be at least 1 minute")
    @Max(value = 1440, message = "Duration must be at most 1440 minutes")
    private Integer durationMinutes;

    @DecimalMin(value = "0.0", message = "Distance cannot be negative")
    @DecimalMax(value = "1000.0", message = "Distance is outside a plausible range")
    private BigDecimal distanceKm;

    @Min(value = 0, message = "Calories cannot be negative")
    @Max(value = 100000, message = "Calories is outside a plausible range")
    private Integer caloriesBurned;

    @Size(max = 1000, message = "Notes must be at most 1000 characters")
    private String notes;
}