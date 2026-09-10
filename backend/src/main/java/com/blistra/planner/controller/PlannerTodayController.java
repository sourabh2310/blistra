package com.blistra.planner.controller;

import com.blistra.planner.application.PlannerTodayService;
import com.blistra.planner.dto.TodayResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/planner/today")
@Tag(name = "Planner Today", description = "Aggregated Planner-owned view of the current day")
public class PlannerTodayController {

    private final PlannerTodayService todayService;

    public PlannerTodayController(PlannerTodayService todayService) {
        this.todayService = todayService;
    }

    @GetMapping
    @Operation(summary = "Get the current user's today view",
            description = "Overdue tasks, tasks due today, and events overlapping today (Planner data only)")
    public ResponseEntity<TodayResponse> today() {
        return ResponseEntity.ok(todayService.getToday());
    }
}