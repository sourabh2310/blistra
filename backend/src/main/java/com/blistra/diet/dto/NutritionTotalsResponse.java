package com.blistra.diet.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Aggregated nutrition values for a set of meal items. Values are summed only
 * from explicitly recorded data; missing values are excluded, not treated as
 * zero.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NutritionTotalsResponse {

    private MacroTotalsResponse caloriesKcal;
    private MacroTotalsResponse proteinG;
    private MacroTotalsResponse carbohydratesG;
    private MacroTotalsResponse fatG;
    private MacroTotalsResponse fiberG;
}