package com.blistra.diet.dto;

import com.blistra.diet.domain.MealType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MealSummaryResponse {

    private UUID id;
    private MealType mealType;
    private String title;
    private OffsetDateTime consumedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private long itemCount;
}