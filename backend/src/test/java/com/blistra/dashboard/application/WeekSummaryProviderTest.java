package com.blistra.dashboard.application;

import com.blistra.common.time.UserTime;
import com.blistra.habits.domain.Habit;
import com.blistra.habits.domain.HabitCompletion;
import com.blistra.habits.domain.HabitFrequency;
import com.blistra.habits.domain.HabitSchedule;
import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.repository.HabitCompletionRepository;
import com.blistra.habits.repository.HabitRepository;
import com.blistra.habits.repository.HabitScheduleRepository;
import com.blistra.planner.domain.Task;
import com.blistra.planner.repository.TaskRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WeekSummaryProviderTest {

    @Mock
    private CurrentUserProvider currentUserProvider;

    @Mock
    private UserTime userTime;

    @Mock
    private TaskRepository taskRepository;

    @Mock
    private HabitRepository habitRepository;

    @Mock
    private HabitScheduleRepository habitScheduleRepository;

    @Mock
    private HabitCompletionRepository habitCompletionRepository;

    private WeekSummaryProvider provider;
    private UUID userId;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        provider = new WeekSummaryProvider(currentUserProvider, userTime, taskRepository,
                habitRepository, habitScheduleRepository, habitCompletionRepository);
        lenient().when(currentUserProvider.getCurrentUser()).thenReturn(user(new User(), userId));
        lenient().when(userTime.today()).thenReturn(LocalDate.of(2026, 9, 24));
        lenient().when(userTime.zone()).thenReturn(ZoneId.of("Asia/Kolkata"));
    }

    @Test
    void summarizesActualWeekRecordsAndExpectedHabitOccurrences() {
        LocalDate start = LocalDate.of(2026, 9, 21);
        LocalDate end = LocalDate.of(2026, 9, 27);
        OffsetDateTime startAt = start.atStartOfDay(userTime.zone()).toOffsetDateTime();
        OffsetDateTime endAt = end.plusDays(1).atStartOfDay(userTime.zone()).toOffsetDateTime();
        when(taskRepository.findCompletedInRange(userId, startAt, endAt))
                .thenReturn(List.of(completedTask(start), completedTask(start.plusDays(1))));
        when(taskRepository.countCompletedDueOrScheduledInRange(userId, startAt, endAt)).thenReturn(2L);
        when(taskRepository.countDistinctDueOrScheduledInRange(userId, startAt, endAt)).thenReturn(3L);

        Habit daily = habit(HabitStatus.ACTIVE);
        Habit weekly = habit(HabitStatus.ACTIVE);
        HabitSchedule dailySchedule = schedule(daily, HabitFrequency.DAILY, List.of());
        HabitSchedule weeklySchedule = schedule(weekly, HabitFrequency.WEEKLY,
                List.of(DayOfWeek.MONDAY, DayOfWeek.WEDNESDAY));
        when(habitRepository.findAllByUserIdAndStatusOrderByCreatedAtDesc(userId, HabitStatus.ACTIVE))
                .thenReturn(List.of(daily, weekly));
        when(habitScheduleRepository.findAllByHabitUserIdAndHabitIdIn(
                userId, List.of(daily.getId(), weekly.getId())))
                .thenReturn(List.of(dailySchedule, weeklySchedule));

        HabitCompletion first = completion(daily, start);
        HabitCompletion second = completion(weekly, start.plusDays(2));
        when(habitCompletionRepository.findAllForUserInRange(userId, start, end))
                .thenReturn(List.of(first, second));

        var summary = provider.getWeekSummary(LocalDate.of(2026, 9, 24), 330);

        assertThat(summary.isUnavailable()).isFalse();
        assertThat(summary.getStart()).isEqualTo(start);
        assertThat(summary.getEnd()).isEqualTo(end);
        assertThat(summary.getCompletedTasks()).isEqualTo(2);
        assertThat(summary.getTasksDueOrScheduled()).isEqualTo(3);
        assertThat(summary.getHabitCompletions()).isEqualTo(2);
        assertThat(summary.getExpectedHabitOccurrences()).isEqualTo(9);
        assertThat(summary.getActiveDays()).isEqualTo(3);
    }

    @Test
    void failsWithoutLeakingUserContext() {
        when(currentUserProvider.getCurrentUser()).thenThrow(new RuntimeException("DB down"));

        var summary = provider.getWeekSummary(LocalDate.of(2026, 9, 24), 330);

        assertThat(summary.getStart()).isEqualTo(LocalDate.of(2026, 9, 21));
        assertThat(summary.getEnd()).isEqualTo(LocalDate.of(2026, 9, 27));
        assertThat(summary.isUnavailable()).isTrue();
        assertThat(summary.getError()).isEqualTo("Week summary unavailable");
    }

    @Test
    void scopesEveryRecordLookupToAuthenticatedUser() {
        LocalDate start = LocalDate.of(2026, 9, 21);
        LocalDate end = LocalDate.of(2026, 9, 27);
        OffsetDateTime startAt = start.atStartOfDay(userTime.zone()).toOffsetDateTime();
        OffsetDateTime endAt = end.plusDays(1).atStartOfDay(userTime.zone()).toOffsetDateTime();
        when(taskRepository.findCompletedInRange(userId, startAt, endAt)).thenReturn(List.of());
        when(taskRepository.countCompletedDueOrScheduledInRange(userId, startAt, endAt)).thenReturn(0L);
        when(taskRepository.countDistinctDueOrScheduledInRange(userId, startAt, endAt)).thenReturn(0L);
        when(habitCompletionRepository.findAllForUserInRange(userId, start, end)).thenReturn(List.of());
        when(habitRepository.findAllByUserIdAndStatusOrderByCreatedAtDesc(userId, HabitStatus.ACTIVE))
                .thenReturn(List.of());

        provider.getWeekSummary(LocalDate.of(2026, 9, 24), 330);

        verify(taskRepository).findCompletedInRange(userId, startAt, endAt);
        verify(taskRepository).countCompletedDueOrScheduledInRange(userId, startAt, endAt);
        verify(taskRepository).countDistinctDueOrScheduledInRange(userId, startAt, endAt);
        verify(habitCompletionRepository).findAllForUserInRange(userId, start, end);
        verify(habitRepository).findAllByUserIdAndStatusOrderByCreatedAtDesc(userId, HabitStatus.ACTIVE);
    }

    private static User user(User user, UUID id) {
        user.setId(id);
        return user;
    }

    private static Task completedTask(LocalDate date) {
        Task task = new Task();
        task.setCompletedAt(date.atTime(LocalTime.NOON).atOffset(java.time.ZoneOffset.ofTotalSeconds(19800)));
        return task;
    }

    private static Habit habit(HabitStatus status) {
        Habit habit = new Habit();
        habit.setId(UUID.randomUUID());
        habit.setStatus(status);
        return habit;
    }

    private static HabitSchedule schedule(Habit habit, HabitFrequency frequency,
                                          List<DayOfWeek> daysOfWeek) {
        HabitSchedule schedule = new HabitSchedule(habit, frequency);
        schedule.setId(UUID.randomUUID());
        schedule.setDaysOfWeek(daysOfWeek);
        return schedule;
    }

    private static HabitCompletion completion(Habit habit, LocalDate date) {
        return new HabitCompletion(habit, date);
    }
}
