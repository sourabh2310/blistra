package com.blistra.habits.dto;

import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.domain.HabitType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Habit representation returned to clients. Never exposes ownership or
 * internal persistence details.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HabitResponse {

    private UUID id;
    private String name;
    private String description;
    private HabitType type;
    private HabitStatus status;
    private BigDecimal targetValue;
    private String targetUnit;
    private Integer targetMinutes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}