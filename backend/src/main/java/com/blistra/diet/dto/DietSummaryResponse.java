package com.blistra.diet.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * A user's food and nutrition summary for one local calendar day.
 *
 * <p>{@code offsetMinutes} is the client-reported UTC offset used to define the
 * day boundary. {@code waterTotalMilliliters} is derived only from entries whose
 * unit is a millilitre/litre value; other descriptors are excluded from the
 * total but still listed in {@code water}.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class DietSummaryResponse {

    private LocalDate date;
    private int offsetMinutes;
    private long mealCount;
    private List<MealResponse> meals;
    private long waterCount;
    private List<WaterResponse> water;
    private BigDecimal waterTotalMilliliters;
    private NutritionTotalsResponse nutrition;
}