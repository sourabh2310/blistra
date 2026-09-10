package com.blistra.planner.dto;

import java.util.List;

/**
 * Planner "Today" view. Aggregates only Planner-owned data; cross-module data
 * (Health appointments, medication schedules, ...) is intentionally excluded.
 */
public record TodayResponse(List<TaskResponse> overdueTasks,
                            List<TaskResponse> todayTasks,
                            List<EventResponse> todayEvents) {
}