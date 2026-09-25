package com.blistra.medicines.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Create/update payload for a refill record.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RefillRequest {

    @NotNull(message = "Refill date is required")
    private LocalDate refillDate;

    @NotNull(message = "Quantity is required")
    @DecimalMin(value = "0.01", message = "Quantity must be greater than zero")
    @Digits(integer = 12, fraction = 4, message = "Quantity has too many digits")
    private BigDecimal quantity;

    @DecimalMin(value = "0.0", message = "Remaining quantity cannot be negative")
    @Digits(integer = 12, fraction = 4, message = "Remaining quantity has too many digits")
    private BigDecimal remainingQuantity;

    @Size(max = 500, message = "Notes must be at most 500 characters")
    private String notes;
}