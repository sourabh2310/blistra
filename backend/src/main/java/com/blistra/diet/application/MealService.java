package com.blistra.diet.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.diet.domain.Meal;
import com.blistra.diet.domain.MealItem;
import com.blistra.diet.dto.CreateMealItemRequest;
import com.blistra.diet.dto.CreateMealRequest;
import com.blistra.diet.dto.MealItemResponse;
import com.blistra.diet.dto.MealResponse;
import com.blistra.diet.dto.MealSummaryResponse;
import com.blistra.diet.dto.PageResponse;
import com.blistra.diet.dto.UpdateMealRequest;
import com.blistra.diet.mapper.MealMapper;
import com.blistra.diet.repository.MealItemRepository;
import com.blistra.diet.repository.MealRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class MealService {

    private static final Sort CONSUMED_AT_DESC = Sort.by(Sort.Direction.DESC, "consumedAt");

    private final MealRepository mealRepository;
    private final MealItemRepository mealItemRepository;

    public MealService(MealRepository mealRepository, MealItemRepository mealItemRepository) {
        this.mealRepository = mealRepository;
        this.mealItemRepository = mealItemRepository;
    }

    @Transactional
    public MealResponse create(UUID userId, CreateMealRequest request) {
        Meal meal = new Meal(userId, request.getMealType(), request.getTitle().trim(),
                request.getNotes(), request.getConsumedAt());
        if (request.getItems() != null) {
            for (CreateMealItemRequest itemRequest : request.getItems()) {
                meal.addItem(MealMapper.newItem(meal, itemRequest));
            }
        }
        Meal saved = mealRepository.save(meal);
        return loadResponse(userId, saved.getId());
    }

    @Transactional(readOnly = true)
    public MealResponse get(UUID userId, UUID mealId) {
        return loadResponse(userId, mealId);
    }

    @Transactional
    public MealResponse update(UUID userId, UUID mealId, UpdateMealRequest request) {
        Meal meal = ownedMeal(userId, mealId);
        meal.setMealType(request.getMealType());
        meal.setTitle(request.getTitle().trim());
        meal.setNotes(request.getNotes());
        meal.setConsumedAt(request.getConsumedAt());
        mealRepository.save(meal);
        return loadResponse(userId, mealId);
    }

    @Transactional
    public void delete(UUID userId, UUID mealId) {
        Meal meal = ownedMeal(userId, mealId);
        // Items are removed through the owning meal (cascade + orphan removal).
        mealRepository.delete(meal);
    }

    @Transactional(readOnly = true)
    public PageResponse<MealSummaryResponse> list(UUID userId, LocalDate date, int offsetMinutes,
                                                  int page, int size) {
        PageRequest pageable = PageRequest.of(page, size, CONSUMED_AT_DESC);
        Page<Meal> result;
        if (date != null) {
            DayRange range = DayRange.of(date, offsetMinutes);
            result = mealRepository
                    .findAllByUserIdAndConsumedAtGreaterThanEqualAndConsumedAtLessThanOrderByConsumedAtDesc(
                            userId, range.start(), range.end(), pageable);
        } else {
            result = mealRepository.findAllByUserIdOrderByConsumedAtDesc(userId, pageable);
        }

        List<Meal> meals = result.getContent();
        Map<UUID, Long> itemCounts = itemCounts(meals);

        return PageResponse.<MealSummaryResponse>builder()
                .content(meals.stream()
                        .map(m -> MealMapper.toSummaryResponse(m,
                                itemCounts.getOrDefault(m.getId(), 0L)))
                        .toList())
                .page(result.getNumber())
                .size(result.getSize())
                .totalElements(result.getTotalElements())
                .totalPages(result.getTotalPages())
                .build();
    }

    @Transactional(readOnly = true)
    public List<MealItemResponse> listItems(UUID userId, UUID mealId) {
        Meal meal = ownedMeal(userId, mealId);
        return mealItemRepository.findAllByMealIdOrderByCreatedAtAsc(meal.getId()).stream()
                .map(MealMapper::itemToResponse)
                .toList();
    }

    @Transactional
    public MealItemResponse addItem(UUID userId, UUID mealId, CreateMealItemRequest request) {
        Meal meal = ownedMeal(userId, mealId);
        MealItem item = mealItemRepository.save(MealMapper.newItem(meal, request));
        return MealMapper.itemToResponse(item);
    }

    @Transactional
    public MealItemResponse updateItem(UUID userId, UUID mealId, UUID itemId,
                                       CreateMealItemRequest request) {
        Meal meal = ownedMeal(userId, mealId);
        MealItem item = mealItemRepository.findByIdAndMealId(itemId, meal.getId())
                .orElseThrow(() -> notFound("Meal item not found"));
        MealMapper.applyItemRequest(item, request);
        return MealMapper.itemToResponse(mealItemRepository.save(item));
    }

    @Transactional
    public void deleteItem(UUID userId, UUID mealId, UUID itemId) {
        Meal meal = ownedMeal(userId, mealId);
        MealItem item = mealItemRepository.findByIdAndMealId(itemId, meal.getId())
                .orElseThrow(() -> notFound("Meal item not found"));
        mealItemRepository.delete(item);
    }

    private MealResponse loadResponse(UUID userId, UUID mealId) {
        Meal meal = ownedMeal(userId, mealId);
        List<MealItem> items = mealItemRepository.findAllByMealIdOrderByCreatedAtAsc(meal.getId());
        return MealMapper.toResponse(meal, items);
    }

    private Meal ownedMeal(UUID userId, UUID mealId) {
        return mealRepository.findByIdAndUserId(mealId, userId)
                .orElseThrow(() -> notFound("Meal not found"));
    }

    private Map<UUID, Long> itemCounts(List<Meal> meals) {
        if (meals.isEmpty()) {
            return Map.of();
        }
        List<UUID> mealIds = meals.stream().map(Meal::getId).toList();
        // find by meal ids then group by meal id.
        return mealItemRepository.findAllByMealIdIn(mealIds).stream()
                .collect(Collectors.groupingBy(item -> item.getMeal().getId(), Collectors.counting()));
    }

    private ResourceNotFoundException notFound(String message) {
        return new ResourceNotFoundException(message);
    }
}