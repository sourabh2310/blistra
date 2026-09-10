package com.blistra.diet.dto;

import com.blistra.diet.domain.MealType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateMealRequest {

    @NotNull(message = "Meal type is required")
    private MealType mealType;

    @NotBlank(message = "Meal title is required")
    @Size(max = 200, message = "Meal title cannot exceed 200 characters")
    private String title;

    @Size(max = 2000, message = "Meal notes cannot exceed 2000 characters")
    private String notes;

    @NotNull(message = "Consumption time is required")
    @PastOrPresent(message = "Consumption time cannot be in the future")
    private OffsetDateTime consumedAt;
}