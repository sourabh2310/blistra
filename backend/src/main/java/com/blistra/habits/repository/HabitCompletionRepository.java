package com.blistra.habits.repository;

import com.blistra.habits.domain.HabitCompletion;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface HabitCompletionRepository extends JpaRepository<HabitCompletion, UUID> {

    Optional<HabitCompletion> findByHabitIdAndCompletedOn(UUID habitId, LocalDate completedOn);

    boolean existsByHabitIdAndCompletedOn(UUID habitId, LocalDate completedOn);

    Page<HabitCompletion> findAllByHabitIdOrderByCompletedOnDesc(UUID habitId, Pageable pageable);

    long countByHabitId(UUID habitId);

    List<HabitCompletion> findAllByHabitIdOrderByCompletedOnAsc(UUID habitId);

    List<HabitCompletion> findAllByHabitIdInAndCompletedOn(java.util.Collection<UUID> habitIds,
                                                           LocalDate completedOn);
}