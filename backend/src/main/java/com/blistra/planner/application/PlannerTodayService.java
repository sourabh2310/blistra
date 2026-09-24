package com.blistra.planner.application;

import com.blistra.planner.dto.ScheduleResponse;
import com.blistra.planner.dto.TodayResponse;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Planner-owned "today" aggregation. Combines Planner tasks and events only;
 * cross-module aggregation (Health appointments, medication schedules, ...) is
 * intentionally left for the future Dashboard phase.
 */
@Service
@Transactional(readOnly = true)
public class PlannerTodayService {

    private final CurrentUserProvider currentUserProvider;
    private final PlannerTaskService taskService;
    private final PlannerEventService eventService;
    private final PlannerTime time;

    public PlannerTodayService(CurrentUserProvider currentUserProvider,
                               PlannerTaskService taskService,
                               PlannerEventService eventService,
                               PlannerTime time) {
        this.currentUserProvider = currentUserProvider;
        this.taskService = taskService;
        this.eventService = eventService;
        this.time = time;
    }

    public TodayResponse getToday() {
        User user = currentUserProvider.getCurrentUser();
        return new TodayResponse(
                taskService.overdueForToday(user.getId()),
                taskService.dueToday(user.getId()),
                eventService.eventsForToday(user.getId()));
    }

    /**
     * Schedule for an explicit calendar window (date navigation / week view).
     * Only the requested window is queried; never a lifetime of events.
     */
    public ScheduleResponse getSchedule(LocalDate date, int days) {
        User user = currentUserProvider.getCurrentUser();
        LocalDate effectiveDate = date != null ? date : time.userZone() != null
                ? LocalDate.now(time.userZone()) : LocalDate.now();
        int safeDays = Math.min(Math.max(days, 1), 31);
        OffsetDateTime start = time.dayStart(effectiveDate);
        OffsetDateTime end = time.rangeEndExclusive(effectiveDate, safeDays);
        return new ScheduleResponse(
                effectiveDate,
                safeDays,
                taskService.dueInRange(user.getId(), start, end),
                eventService.eventsForRange(user.getId(), start, end));
    }
}