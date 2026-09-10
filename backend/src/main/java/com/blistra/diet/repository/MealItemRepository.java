package com.blistra.diet.repository;

import com.blistra.diet.domain.MealItem;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MealItemRepository extends JpaRepository<MealItem, UUID> {

    Optional<MealItem> findByIdAndMealId(UUID id, UUID mealId);

    List<MealItem> findAllByMealIdOrderByCreatedAtAsc(UUID mealId);

    List<MealItem> findAllByMealIdIn(Collection<UUID> mealIds);

    }