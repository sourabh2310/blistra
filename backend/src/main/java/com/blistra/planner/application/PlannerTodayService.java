package com.blistra.planner.application;

import com.blistra.planner.dto.TodayResponse;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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

    public PlannerTodayService(CurrentUserProvider currentUserProvider,
                               PlannerTaskService taskService,
                               PlannerEventService eventService) {
        this.currentUserProvider = currentUserProvider;
        this.taskService = taskService;
        this.eventService = eventService;
    }

    public TodayResponse getToday() {
        User user = currentUserProvider.getCurrentUser();
        return new TodayResponse(
                taskService.overdueForToday(user.getId()),
                taskService.dueToday(user.getId()),
                eventService.eventsForToday(user.getId()));
    }
}