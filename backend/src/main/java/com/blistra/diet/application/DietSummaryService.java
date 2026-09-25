package com.blistra.diet.application;

import com.blistra.diet.domain.Meal;
import com.blistra.diet.domain.MealItem;
import com.blistra.diet.dto.DietSummaryResponse;
import com.blistra.diet.dto.MacroTotalsResponse;
import com.blistra.diet.dto.MealItemResponse;
import com.blistra.diet.dto.MealResponse;
import com.blistra.diet.dto.NutritionTotalsResponse;
import com.blistra.diet.dto.WaterResponse;
import com.blistra.diet.mapper.MealMapper;
import com.blistra.diet.mapper.WaterMapper;
import com.blistra.diet.repository.MealItemRepository;
import com.blistra.diet.repository.MealRepository;
import com.blistra.diet.repository.WaterIntakeRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Builds a per-user daily summary from recorded data.
 *
 * <p>Nutrition totals are plain sums of explicitly recorded values; values that
 * were never entered are excluded from the sum. The result is a factual record,
 * not a recommendation.</p>
 */
@Service
public class DietSummaryService {

    private final MealRepository mealRepository;
    private final MealItemRepository mealItemRepository;
    private final WaterIntakeRepository waterIntakeRepository;

    public DietSummaryService(MealRepository mealRepository,
                              MealItemRepository mealItemRepository,
                              WaterIntakeRepository waterIntakeRepository) {
        this.mealRepository = mealRepository;
        this.mealItemRepository = mealItemRepository;
        this.waterIntakeRepository = waterIntakeRepository;
    }

    @Transactional(readOnly = true)
    public DietSummaryResponse dailySummary(UUID userId, LocalDate date, int offsetMinutes) {
        DayRange range = DayRange.of(date, offsetMinutes);

        List<Meal> meals = mealRepository
                .findAllByUserIdAndConsumedAtGreaterThanEqualAndConsumedAtLessThanOrderByConsumedAtAsc(
                        userId, range.start(), range.end());
        List<UUID> mealIds = meals.stream().map(Meal::getId).toList();
        List<MealItem> items = mealIds.isEmpty()
                ? List.of()
                : mealItemRepository.findAllByMealIdIn(mealIds);
        Map<UUID, List<MealItem>> itemsByMeal = items.stream()
                .collect(Collectors.groupingBy(item -> item.getMeal().getId()));

        List<MealResponse> mealResponses = meals.stream()
                .map(meal -> MealMapper.toResponse(meal,
                        itemsByMeal.getOrDefault(meal.getId(), List.of())))
                .toList();

        List<WaterResponse> water = waterIntakeRepository
                .findAllByUserIdAndConsumedAtGreaterThanEqualAndConsumedAtLessThanOrderByConsumedAtAsc(
                        userId, range.start(), range.end()).stream()
                .map(WaterMapper::toResponse)
                .toList();

        return DietSummaryResponse.builder()
                .date(date)
                .offsetMinutes(offsetMinutes)
                .mealCount(mealResponses.size())
                .meals(mealResponses)
                .waterCount(water.size())
                .water(water)
                .waterTotalMilliliters(totalMilliliters(water))
                .nutrition(computeNutrition(mealResponses))
                .build();
    }

    private NutritionTotalsResponse computeNutrition(List<MealResponse> meals) {
        List<MealItemResponse> items = meals.stream()
                .flatMap(m -> m.getItems().stream())
                .toList();

        return NutritionTotalsResponse.builder()
                .caloriesKcal(totals(items, MealItemResponse::getCaloriesKcal))
                .proteinG(totals(items, MealItemResponse::getProteinG))
                .carbohydratesG(totals(items, MealItemResponse::getCarbohydratesG))
                .fatG(totals(items, MealItemResponse::getFatG))
                .fiberG(totals(items, MealItemResponse::getFiberG))
                .build();
    }

    private MacroTotalsResponse totals(List<MealItemResponse> items,
                                       Function<MealItemResponse, BigDecimal> extractor) {
        BigDecimal total = null;
        long recordedItems = 0;
        for (MealItemResponse item : items) {
            BigDecimal value = extractor.apply(item);
            if (value != null) {
                total = (total == null) ? value : total.add(value);
                recordedItems++;
            }
        }
        return MacroTotalsResponse.builder().total(total).recordedItems(recordedItems).build();
    }

    /**
     * Derives a total in millilitres from entries recorded in ml or litres.
     * Entries with non-numeric descriptors (e.g. "glass") are excluded from the
     * total but remain part of the day's list.
     */
    private BigDecimal totalMilliliters(List<WaterResponse> water) {
        BigDecimal total = null;
        for (WaterResponse entry : water) {
            BigDecimal milliliters = toMilliliters(entry);
            if (milliliters != null) {
                total = (total == null) ? milliliters : total.add(milliliters);
            }
        }
        return total;
    }

    private BigDecimal toMilliliters(WaterResponse entry) {
        return switch (entry.getUnit()) {
            case "ml", "mL", "ML" -> entry.getAmount();
            case "L", "l" -> entry.getAmount().multiply(BigDecimal.valueOf(1000));
            default -> null;
        };
    }
}