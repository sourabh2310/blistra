package com.blistra.health.dto;

import com.blistra.health.domain.ActivityType;
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
public class ActivityResponse {

    private UUID id;
    private ActivityType type;
    private OffsetDateTime performedAt;
    private Integer durationMinutes;
    private BigDecimal distanceKm;
    private Integer caloriesBurned;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}