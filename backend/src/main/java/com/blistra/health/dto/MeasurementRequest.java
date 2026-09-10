package com.blistra.health.dto;

import com.blistra.health.domain.MeasurementType;
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
public class MeasurementRequest {

    @NotNull(message = "Measurement type is required")
    private MeasurementType type;

    @NotNull(message = "Measured at is required")
    @PastOrPresent(message = "Measurement time cannot be in the future")
    private OffsetDateTime measuredAt;

    @NotNull(message = "Value is required")
    @DecimalMin(value = "0.01", message = "Value must be greater than zero")
    private BigDecimal value;

    @DecimalMin(value = "0.01", message = "Diastolic value must be greater than zero")
    private BigDecimal valueDiastolic;

    @NotBlank(message = "Unit is required")
    @Size(max = 10, message = "Unit must be at most 10 characters")
    private String unit;

    @Size(max = 50, message = "Source must be at most 50 characters")
    private String source;

    @Size(max = 500, message = "Notes must be at most 500 characters")
    private String notes;
}