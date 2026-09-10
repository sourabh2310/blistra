package com.blistra.health.dto;

import com.blistra.health.domain.MeasurementType;
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
public class MeasurementResponse {

    private UUID id;
    private MeasurementType type;
    private OffsetDateTime measuredAt;
    private BigDecimal value;
    private BigDecimal valueDiastolic;
    private String unit;
    private String source;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}