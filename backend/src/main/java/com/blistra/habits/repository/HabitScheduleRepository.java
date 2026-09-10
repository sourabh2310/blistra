package com.blistra.habits.repository;

import com.blistra.habits.domain.HabitSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface HabitScheduleRepository extends JpaRepository<HabitSchedule, UUID> {

    Optional<HabitSchedule> findByHabitIdAndHabitUserId(UUID habitId, UUID userId);

    Optional<HabitSchedule> findByHabitId(UUID habitId);
}