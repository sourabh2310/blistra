package com.blistra.medicines.dto;

import com.blistra.medicines.domain.MedicineStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Medicine representation returned to clients. Never exposes ownership or
 * internal persistence details.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MedicineResponse {

    private UUID id;
    private String name;
    private String genericName;
    private String form;
    private BigDecimal strength;
    private String strengthUnit;
    private String notes;
    private MedicineStatus status;
    private LocalDate startDate;
    private LocalDate endDate;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}