package com.blistra.habits.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.habits.domain.Habit;
import com.blistra.habits.domain.HabitSchedule;
import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.dto.HabitRequest;
import com.blistra.habits.dto.HabitResponse;
import com.blistra.habits.dto.HabitTodayResponse;
import com.blistra.habits.dto.PageResponse;
import com.blistra.habits.dto.ScheduleResponse;
import com.blistra.common.time.UserTime;
import com.blistra.habits.repository.HabitCompletionRepository;
import com.blistra.habits.repository.HabitRepository;
import com.blistra.habits.repository.HabitScheduleRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Owns habit CRUD. Every operation is scoped to the authenticated user.
 * Deletion is implemented as archiving so completion history stays meaningful.
 */
@Service
@Transactional
public class HabitService {

    private final HabitRepository habitRepository;
    private final HabitScheduleRepository scheduleRepository;
    private final HabitCompletionRepository completionRepository;
    private final CurrentUserProvider currentUserProvider;
    private final UserTime userTime;

    public HabitService(HabitRepository habitRepository,
                        HabitScheduleRepository scheduleRepository,
                        HabitCompletionRepository completionRepository,
                        CurrentUserProvider currentUserProvider,
                        UserTime userTime) {
        this.habitRepository = habitRepository;
        this.scheduleRepository = scheduleRepository;
        this.completionRepository = completionRepository;
        this.currentUserProvider = currentUserProvider;
        this.userTime = userTime;
    }

    @Transactional(readOnly = true)
    public PageResponse<HabitResponse> list(HabitStatus status, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        Page<Habit> page = status == null
                ? habitRepository.findAllByUserIdOrderByCreatedAtDesc(user.getId(), pageable)
                : habitRepository.findAllByUserIdAndStatusOrderByCreatedAtDesc(user.getId(), status, pageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public HabitResponse create(HabitRequest request) {
        validateTargets(request);
        User user = currentUserProvider.getCurrentUser();
        Habit habit = new Habit(user, request.getName(), request.getType());
        applyRequest(habit, request);
        if (request.getStatus() != null && request.getStatus() != HabitStatus.ARCHIVED) {
            habit.setStatus(request.getStatus());
        }
        return toResponse(habitRepository.save(habit));
    }

    @Transactional(readOnly = true)
    public HabitResponse get(UUID id) {
        return toResponse(getOwned(id));
    }

    public HabitResponse update(UUID id, HabitRequest request) {
        validateTargets(request);
        Habit habit = getOwned(id);
        applyRequest(habit, request);
        if (request.getStatus() != null) {
            habit.setStatus(request.getStatus());
        }
        return toResponse(habitRepository.save(habit));
    }

    /**
     * Soft delete: the habit is archived and disappears from active lists.
     */
    public void archive(UUID id) {
        Habit habit = getOwned(id);
        habit.setStatus(HabitStatus.ARCHIVED);
        habitRepository.save(habit);
    }

    /**
     * The active habits the user owes today (or has already completed today),
     * each annotated with its completion state for the current calendar day.
     */
    @Transactional(readOnly = true)
    public List<HabitTodayResponse> today() {
        User user = currentUserProvider.getCurrentUser();
        LocalDate today = userTime.today();
        List<Habit> habits = habitRepository
                .findAllByUserIdAndStatusOrderByCreatedAtDesc(user.getId(), HabitStatus.ACTIVE);
        if (habits.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = habits.stream().map(Habit::getId).toList();
        Map<UUID, HabitSchedule> schedules = scheduleRepository.findAllByHabitIdIn(ids)
                .stream().collect(java.util.stream.Collectors.toMap(
                        s -> s.getHabit().getId(), s -> s, (a, b) -> a));
        java.util.Set<UUID> completed = new java.util.HashSet<>(completionRepository
                .findAllByHabitIdInAndCompletedOn(ids, today)
                .stream().map(c -> c.getHabit().getId()).toList());
        List<HabitTodayResponse> result = new ArrayList<>();
        for (Habit habit : habits) {
            HabitSchedule schedule = schedules.get(habit.getId());
            boolean completedToday = completed.contains(habit.getId());
            if (HabitStreakCalculator.isDue(schedule, today) || completedToday) {
                result.add(toTodayResponse(habit, schedule, completedToday));
            }
        }
        return result;
    }

    public Habit getOwned(UUID id) {
        UUID userId = currentUserProvider.getCurrentUser().getId();
        return habitRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Habit not found"));
    }

    private void applyRequest(Habit habit, HabitRequest request) {
        habit.setName(request.getName());
        habit.setDescription(request.getDescription());
        habit.setType(request.getType());
        habit.setTargetValue(request.getTargetValue());
        habit.setTargetUnit(request.getTargetUnit());
        habit.setTargetMinutes(request.getTargetMinutes());
    }

    static void validateTargets(HabitRequest request) {
        if (request == null || request.getType() == null) {
            return;
        }
        boolean valid = switch (request.getType()) {
            case BOOLEAN -> request.getTargetValue() == null
                    && request.getTargetUnit() == null
                    && request.getTargetMinutes() == null;
            case COUNT -> request.getTargetValue() != null
                    && request.getTargetValue().signum() > 0
                    && request.getTargetUnit() != null
                    && !request.getTargetUnit().isBlank()
                    && request.getTargetMinutes() == null;
            case DURATION -> request.getTargetMinutes() != null
                    && request.getTargetMinutes() > 0
                    && request.getTargetValue() == null
                    && request.getTargetUnit() == null;
        };
        if (!valid) {
            throw new BadRequestException("Target fields are inconsistent with the habit type");
        }
    }

    private HabitResponse toResponse(Habit habit) {
        return HabitResponse.builder()
                .id(habit.getId())
                .name(habit.getName())
                .description(habit.getDescription())
                .type(habit.getType())
                .status(habit.getStatus())
                .targetValue(habit.getTargetValue())
                .targetUnit(habit.getTargetUnit())
                .targetMinutes(habit.getTargetMinutes())
                .createdAt(habit.getCreatedAt())
                .updatedAt(habit.getUpdatedAt())
                .build();
    }

    private HabitTodayResponse toTodayResponse(Habit habit, HabitSchedule schedule, boolean completedToday) {
        ScheduleResponse scheduleResponse = schedule == null ? null : ScheduleConverter.toResponse(schedule);
        return HabitTodayResponse.builder()
                .id(habit.getId())
                .name(habit.getName())
                .description(habit.getDescription())
                .type(habit.getType())
                .targetValue(habit.getTargetValue())
                .targetUnit(habit.getTargetUnit())
                .targetMinutes(habit.getTargetMinutes())
                .schedule(scheduleResponse)
                .completedToday(completedToday)
                .build();
    }
}