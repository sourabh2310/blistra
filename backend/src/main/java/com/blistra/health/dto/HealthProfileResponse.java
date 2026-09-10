package com.blistra.health.dto;

import com.blistra.health.domain.BloodType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HealthProfileResponse {

    private UUID id;
    private BigDecimal heightCm;
    private BloodType bloodType;
    private LocalDate dateOfBirth;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}