package com.blistra.health.dto;

import com.blistra.health.domain.BloodType;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Past;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HealthProfileRequest {

    @DecimalMin(value = "0.01", message = "Height must be greater than zero")
    @DecimalMax(value = "300.00", message = "Height is outside a plausible range")
    private BigDecimal heightCm;

    private BloodType bloodType;

    @Past(message = "Date of birth must be in the past")
    private LocalDate dateOfBirth;
}