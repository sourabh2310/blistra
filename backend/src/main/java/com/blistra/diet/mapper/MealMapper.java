package com.blistra.diet.mapper;

import com.blistra.diet.domain.Meal;
import com.blistra.diet.domain.MealItem;
import com.blistra.diet.dto.CreateMealItemRequest;
import com.blistra.diet.dto.MealItemResponse;
import com.blistra.diet.dto.MealResponse;
import com.blistra.diet.dto.MealSummaryResponse;

import java.util.List;

public final class MealMapper {

    private MealMapper() {
    }

    public static MealSummaryResponse toSummaryResponse(Meal meal, long itemCount) {
        return MealSummaryResponse.builder()
                .id(meal.getId())
                .mealType(meal.getMealType())
                .title(meal.getTitle())
                .consumedAt(meal.getConsumedAt())
                .createdAt(meal.getCreatedAt())
                .updatedAt(meal.getUpdatedAt())
                .itemCount(itemCount)
                .build();
    }

    public static MealResponse toResponse(Meal meal, List<MealItem> items) {
        return MealResponse.builder()
                .id(meal.getId())
                .mealType(meal.getMealType())
                .title(meal.getTitle())
                .notes(meal.getNotes())
                .consumedAt(meal.getConsumedAt())
                .createdAt(meal.getCreatedAt())
                .updatedAt(meal.getUpdatedAt())
                .items(items.stream().map(MealMapper::itemToResponse).toList())
                .build();
    }

    public static MealItemResponse itemToResponse(MealItem item) {
        return MealItemResponse.builder()
                .id(item.getId())
                .name(item.getName())
                .quantity(item.getQuantity())
                .unit(item.getUnit())
                .caloriesKcal(item.getCaloriesKcal())
                .proteinG(item.getProteinG())
                .carbohydratesG(item.getCarbohydratesG())
                .fatG(item.getFatG())
                .fiberG(item.getFiberG())
                .notes(item.getNotes())
                .createdAt(item.getCreatedAt())
                .updatedAt(item.getUpdatedAt())
                .build();
    }

    public static MealItem newItem(Meal meal, CreateMealItemRequest request) {
        return new MealItem(
                meal,
                request.getName().trim(),
                request.getQuantity(),
                request.getUnit() == null ? null : request.getUnit().trim(),
                request.getCaloriesKcal(),
                request.getProteinG(),
                request.getCarbohydratesG(),
                request.getFatG(),
                request.getFiberG(),
                request.getNotes());
    }

    public static void applyItemRequest(MealItem item, CreateMealItemRequest request) {
        item.setName(request.getName().trim());
        item.setQuantity(request.getQuantity());
        item.setUnit(request.getUnit() == null ? null : request.getUnit().trim());
        item.setCaloriesKcal(request.getCaloriesKcal());
        item.setProteinG(request.getProteinG());
        item.setCarbohydratesG(request.getCarbohydratesG());
        item.setFatG(request.getFatG());
        item.setFiberG(request.getFiberG());
        item.setNotes(request.getNotes());
    }
}