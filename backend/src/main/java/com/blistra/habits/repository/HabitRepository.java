package com.blistra.habits.repository;

import com.blistra.habits.domain.Habit;
import com.blistra.habits.domain.HabitStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface HabitRepository extends JpaRepository<Habit, UUID> {

    Optional<Habit> findByIdAndUserId(UUID id, UUID userId);

    boolean existsByIdAndUserId(UUID id, UUID userId);

    Page<Habit> findAllByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Page<Habit> findAllByUserIdAndStatusOrderByCreatedAtDesc(UUID userId, HabitStatus status, Pageable pageable);

    List<Habit> findAllByUserIdAndStatusOrderByCreatedAtDesc(UUID userId, HabitStatus status);
}