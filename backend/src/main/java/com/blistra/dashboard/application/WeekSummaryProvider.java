package com.blistra.dashboard.application;

import com.blistra.common.time.UserTime;
import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.habits.application.HabitStreakCalculator;
import com.blistra.habits.domain.Habit;
import com.blistra.habits.domain.HabitSchedule;
import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.repository.HabitCompletionRepository;
import com.blistra.habits.repository.HabitRepository;
import com.blistra.habits.repository.HabitScheduleRepository;
import com.blistra.planner.domain.Task;
import com.blistra.planner.repository.TaskRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

@Component
public class WeekSummaryProvider {

    private final CurrentUserProvider currentUserProvider;
    private final UserTime userTime;
    private final TaskRepository taskRepository;
    private final HabitRepository habitRepository;
    private final HabitScheduleRepository habitScheduleRepository;
    private final HabitCompletionRepository habitCompletionRepository;

    public WeekSummaryProvider(CurrentUserProvider currentUserProvider,
                               UserTime userTime,
                               TaskRepository taskRepository,
                               HabitRepository habitRepository,
                               HabitScheduleRepository habitScheduleRepository,
                               HabitCompletionRepository habitCompletionRepository) {
        this.currentUserProvider = currentUserProvider;
        this.userTime = userTime;
        this.taskRepository = taskRepository;
        this.habitRepository = habitRepository;
        this.habitScheduleRepository = habitScheduleRepository;
        this.habitCompletionRepository = habitCompletionRepository;
    }

    @Transactional(readOnly = true)
    public DashboardResponse.WeekSummary getWeekSummary(LocalDate targetDate, int offsetMinutes) {
        ZoneId zone = ZoneOffset.ofTotalSeconds(offsetMinutes * 60);
        LocalDate effectiveDate = targetDate != null ? targetDate : LocalDate.now(zone);
        LocalDate start = effectiveDate.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        LocalDate end = start.plusDays(6);
        try {
            UUID userId = currentUserProvider.getCurrentUser().getId();
            OffsetDateTime startAt = start.atStartOfDay(zone).toOffsetDateTime();
            OffsetDateTime endAt = end.plusDays(1).atStartOfDay(zone).toOffsetDateTime();
            List<Task> completedTasks = taskRepository.findCompletedInRange(userId, startAt, endAt);
            int completedTasksDueOrScheduled = Math.toIntExact(
                    taskRepository.countCompletedDueOrScheduledInRange(userId, startAt, endAt));
            int tasksDueOrScheduled = Math.toIntExact(
                    taskRepository.countDistinctDueOrScheduledInRange(userId, startAt, endAt));
            var allCompletions = habitCompletionRepository.findAllForUserInRange(userId, start, end);
            Map<UUID, HabitSchedule> schedules = activeSchedules(userId);
            var completions = allCompletions.stream()
                    .filter(completion -> {
                        HabitSchedule schedule = schedules.get(completion.getHabit().getId());
                        return schedule != null
                                && HabitStreakCalculator.isDue(schedule, completion.getCompletedOn());
                    })
                    .toList();
            int expectedHabitOccurrences = schedules.values().stream()
                    .mapToInt(schedule -> HabitStreakCalculator.dueOccurrences(schedule, start, end))
                    .sum();
            Set<LocalDate> activeDays = new HashSet<>();
            completedTasks.stream()
                    .map(Task::getCompletedAt)
                    .filter(java.util.Objects::nonNull)
                    .map(completedAt -> completedAt.atZoneSameInstant(zone).toLocalDate())
                    .forEach(activeDays::add);
            completions.stream()
                    .map(completion -> completion.getCompletedOn())
                    .forEach(activeDays::add);
            return DashboardResponse.WeekSummary.builder()
                    .start(start)
                    .end(end)
                    .completedTasks(completedTasksDueOrScheduled)
                    .tasksDueOrScheduled(tasksDueOrScheduled)
                    .habitCompletions(completions.size())
                    .expectedHabitOccurrences(expectedHabitOccurrences)
                    .activeDays(activeDays.size())
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.WeekSummary.builder()
                    .start(start)
                    .end(end)
                    .unavailable(true)
                    .error("Week summary unavailable")
                    .build();
        }
    }

    private Map<UUID, HabitSchedule> activeSchedules(UUID userId) {
        List<Habit> habits = habitRepository.findAllByUserIdAndStatusOrderByCreatedAtDesc(
                userId, HabitStatus.ACTIVE);
        if (habits.isEmpty()) {
            return Map.of();
        }
        List<UUID> habitIds = habits.stream().map(Habit::getId).toList();
        return habitScheduleRepository.findAllByHabitUserIdAndHabitIdIn(userId, habitIds).stream()
                .collect(Collectors.toMap(schedule -> schedule.getHabit().getId(), Function.identity()));
    }
}
