package com.blistra.habits.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.habits.domain.Habit;
import com.blistra.habits.domain.HabitCompletion;
import com.blistra.habits.domain.HabitSchedule;
import com.blistra.habits.domain.HabitType;
import com.blistra.habits.dto.CompletionRequest;
import com.blistra.habits.dto.CompletionResponse;
import com.blistra.habits.dto.HabitStatisticsResponse;
import com.blistra.habits.dto.PageResponse;
import com.blistra.common.time.UserTime;
import com.blistra.habits.repository.HabitCompletionRepository;
import com.blistra.habits.repository.HabitRepository;
import com.blistra.habits.repository.HabitScheduleRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Owns single-day completion records. At most one completion may exist per
 * habit per day; recording the same day again updates the stored value rather
 * than creating a duplicate.
 */
@Service
@Transactional
public class HabitCompletionService {

    private final HabitCompletionRepository completionRepository;
    private final HabitRepository habitRepository;
    private final HabitScheduleRepository scheduleRepository;
    private final CurrentUserProvider currentUserProvider;
    private final UserTime userTime;

    public HabitCompletionService(HabitCompletionRepository completionRepository,
                                  HabitRepository habitRepository,
                                  HabitScheduleRepository scheduleRepository,
                                  CurrentUserProvider currentUserProvider,
                                  UserTime userTime) {
        this.completionRepository = completionRepository;
        this.habitRepository = habitRepository;
        this.scheduleRepository = scheduleRepository;
        this.currentUserProvider = currentUserProvider;
        this.userTime = userTime;
    }

    public CompletionResponse record(UUID habitId, CompletionRequest request) {
        Habit habit = getOwned(habitId);
        validateShape(habit, request);
        HabitCompletion completion = completionRepository
                .findByHabitIdAndCompletedOn(habitId, request.getCompletedOn())
                .orElseGet(() -> new HabitCompletion(habit, request.getCompletedOn()));
        completion.setValue(request.getValue());
        completion.setDurationMinutes(request.getDurationMinutes());
        return toResponse(completionRepository.save(completion));
    }

    public void remove(UUID habitId, LocalDate completedOn) {
        getOwned(habitId);
        HabitCompletion completion = completionRepository.findByHabitIdAndCompletedOn(habitId, completedOn)
                .orElseThrow(() -> new ResourceNotFoundException("Completion not found"));
        completionRepository.delete(completion);
    }

    @Transactional(readOnly = true)
    public PageResponse<CompletionResponse> history(UUID habitId, Pageable pageable) {
        getOwned(habitId);
        Page<HabitCompletion> page = completionRepository
                .findAllByHabitIdOrderByCompletedOnDesc(habitId, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    @Transactional(readOnly = true)
    public HabitStatisticsResponse statistics(UUID habitId) {
        Habit habit = getOwned(habitId);
        HabitSchedule schedule = scheduleRepository.findByHabitId(habitId).orElse(null);
        List<HabitCompletion> completions = completionRepository
                .findAllByHabitIdOrderByCompletedOnAsc(habitId);
        Set<LocalDate> completedDays = completions.stream()
                .map(HabitCompletion::getCompletedOn)
                .collect(Collectors.toSet());
        LocalDate today = userTime.today();
        LocalDate createdOn = habit.getCreatedAt() == null ? today : habit.getCreatedAt().toLocalDate();
        LocalDate firstCompletedOn = completions.isEmpty() ? createdOn : completions.get(0).getCompletedOn();
        LocalDate lowerBound = firstCompletedOn.isBefore(createdOn) ? firstCompletedOn : createdOn;
        LocalDate lastCompleted = completions.isEmpty()
                ? null
                : completions.get(completions.size() - 1).getCompletedOn();
        return HabitStatisticsResponse.builder()
                .totalCompletions(completions.size())
                .currentStreak(HabitStreakCalculator.currentStreak(schedule, completedDays, lowerBound, today))
                .bestStreak(HabitStreakCalculator.bestStreak(schedule, completedDays, lowerBound, today))
                .lastCompletedOn(lastCompleted)
                .build();
    }

    private void validateShape(Habit habit, CompletionRequest request) {
        if (habit.getType() == HabitType.BOOLEAN
                && (request.getValue() != null || request.getDurationMinutes() != null)) {
            throw new BadRequestException("Boolean habits only accept the completion date");
        }
        if (habit.getType() == HabitType.COUNT && request.getDurationMinutes() != null) {
            throw new BadRequestException("Count habits do not record duration");
        }
        if (habit.getType() == HabitType.DURATION && request.getValue() != null) {
            throw new BadRequestException("Duration habits do not record a value");
        }
    }

    private Habit getOwned(UUID habitId) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return habitRepository.findByIdAndUserId(habitId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Habit not found"));
    }

    private CompletionResponse toResponse(HabitCompletion completion) {
        return CompletionResponse.builder()
                .id(completion.getId())
                .habitId(completion.getHabit().getId())
                .completedOn(completion.getCompletedOn())
                .value(scale(completion.getValue()))
                .durationMinutes(completion.getDurationMinutes())
                .createdAt(completion.getCreatedAt())
                .updatedAt(completion.getUpdatedAt())
                .build();
    }

    private BigDecimal scale(BigDecimal value) {
        return value == null ? null : value.setScale(4);
    }
}