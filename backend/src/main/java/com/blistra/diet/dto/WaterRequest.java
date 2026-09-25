package com.blistra.diet.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
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
public class WaterRequest {

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.0", inclusive = false, message = "Amount must be positive")
    @Digits(integer = 8, fraction = 2, message = "Amount is out of range")
    private BigDecimal amount;

    @NotBlank(message = "Unit is required")
    @Pattern(regexp = "^(ml|mL|ML|L|l|glass|glasses|GLASS|cup|cups|CUP)$", message = "Unit is not supported")
    private String unit;

    @NotNull(message = "Consumption time is required")
    @PastOrPresent(message = "Consumption time cannot be in the future")
    private OffsetDateTime consumedAt;
}