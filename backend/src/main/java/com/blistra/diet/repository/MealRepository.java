package com.blistra.diet.repository;

import com.blistra.diet.domain.Meal;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MealRepository extends JpaRepository<Meal, UUID> {

    Optional<Meal> findByIdAndUserId(UUID id, UUID userId);

    Page<Meal> findAllByUserIdOrderByConsumedAtDesc(UUID userId, Pageable pageable);

    Page<Meal> findAllByUserIdAndConsumedAtBetweenOrderByConsumedAtDesc(
            UUID userId, OffsetDateTime start, OffsetDateTime end, Pageable pageable);

    List<Meal> findAllByUserIdAndConsumedAtBetweenOrderByConsumedAtAsc(
            UUID userId, OffsetDateTime start, OffsetDateTime end);

    }