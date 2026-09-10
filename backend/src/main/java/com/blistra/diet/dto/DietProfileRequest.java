package com.blistra.diet.dto;

import com.blistra.diet.domain.DietaryPreference;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DietProfileRequest {

    private DietaryPreference dietaryPreference;

    @Size(max = 100, message = "Custom preference cannot exceed 100 characters")
    private String customPreference;

    @Size(max = 1000, message = "Disliked foods cannot exceed 1000 characters")
    private String dislikedFoods;

    @Size(max = 2000, message = "Notes cannot exceed 2000 characters")
    private String notes;
}