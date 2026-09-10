package com.blistra.medicines.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Refill record representation returned to clients.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RefillResponse {

    private UUID id;
    private UUID medicineId;
    private LocalDate refillDate;
    private BigDecimal quantity;
    private BigDecimal remainingQuantity;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}