package com.blistra.habits.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.habits.domain.Habit;
import com.blistra.habits.domain.HabitSchedule;
import com.blistra.habits.dto.ScheduleRequest;
import com.blistra.habits.dto.ScheduleResponse;
import com.blistra.habits.repository.HabitRepository;
import com.blistra.habits.repository.HabitScheduleRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * Owns the single recurring schedule of a habit. A habit can have at most one
 * schedule; {@code upsert} creates or replaces it.
 */
@Service
@Transactional
public class HabitScheduleService {

    private final HabitScheduleRepository scheduleRepository;
    private final HabitRepository habitRepository;
    private final CurrentUserProvider currentUserProvider;

    public HabitScheduleService(HabitScheduleRepository scheduleRepository,
                                HabitRepository habitRepository,
                                CurrentUserProvider currentUserProvider) {
        this.scheduleRepository = scheduleRepository;
        this.habitRepository = habitRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public ScheduleResponse get(UUID habitId) {
        getOwned(habitId);
        HabitSchedule schedule = scheduleRepository.findByHabitId(habitId)
                .orElseThrow(() -> new ResourceNotFoundException("Schedule not found"));
        return ScheduleConverter.toResponse(schedule);
    }

    public ScheduleResponse upsert(UUID habitId, ScheduleRequest request) {
        Habit habit = getOwned(habitId);
        HabitSchedule schedule = scheduleRepository.findByHabitId(habitId)
                .orElseGet(() -> new HabitSchedule(habit, request.getFrequency()));
        schedule.setFrequency(request.getFrequency());
        schedule.setDaysOfWeek(request.getDaysOfWeek());
        return ScheduleConverter.toResponse(scheduleRepository.save(schedule));
    }

    private Habit getOwned(UUID habitId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return habitRepository.findByIdAndUserId(habitId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Habit not found"));
    }
}