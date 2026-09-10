package com.blistra.diet.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WaterResponse {

    private UUID id;
    private BigDecimal amount;
    private String unit;
    private OffsetDateTime consumedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}