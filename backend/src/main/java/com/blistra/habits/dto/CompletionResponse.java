package com.blistra.habits.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Completion representation returned to clients.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CompletionResponse {

    private UUID id;
    private UUID habitId;
    private LocalDate completedOn;
    private BigDecimal value;
    private Integer durationMinutes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}