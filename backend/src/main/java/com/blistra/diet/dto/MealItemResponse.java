package com.blistra.diet.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MealItemResponse {

    private UUID id;
    private String name;
    private BigDecimal quantity;
    private String unit;
    private BigDecimal caloriesKcal;
    private BigDecimal proteinG;
    private BigDecimal carbohydratesG;
    private BigDecimal fatG;
    private BigDecimal fiberG;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}