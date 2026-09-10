package com.blistra.diet.dto;

import com.blistra.diet.domain.DietaryPreference;
import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class DietProfileResponse {

    private DietaryPreference dietaryPreference;
    private String customPreference;
    private String dislikedFoods;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}