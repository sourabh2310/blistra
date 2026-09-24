package com.blistra.planner.dto;

import java.time.LocalDate;
import java.util.List;

/**
 * Planner-owned schedule for an explicit calendar window.
 *
 * <p>Aggregates only Planner-owned data (tasks due + overlapping events).
 * Cross-module items (medicines, meals, habits, health appointments) are NOT
 * duplicated here; the mobile Planner merges them client-side from the
 * Dashboard payload (same backend source Home uses) when showing "today".</p>
 */
public record ScheduleResponse(LocalDate date,
                               int days,
                               List<TaskResponse> tasks,
                               List<EventResponse> events) {
}
