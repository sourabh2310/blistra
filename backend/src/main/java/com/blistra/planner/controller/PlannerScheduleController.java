package com.blistra.planner.controller;

import com.blistra.planner.application.PlannerTodayService;
import com.blistra.planner.dto.ScheduleResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/planner/schedule")
@Tag(name = "Planner Schedule", description = "Date-navigable Planner schedule (tasks + events, Planner-owned only)")
public class PlannerScheduleController {

    private final PlannerTodayService todayService;

    public PlannerScheduleController(PlannerTodayService todayService) {
        this.todayService = todayService;
    }

    @GetMapping
    @Operation(summary = "Get the current user's schedule for a date window",
            description = "Defaults to today in the user timezone. days=1 for day view, days=7 for week view (max 31).")
    public ResponseEntity<ScheduleResponse> schedule(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(defaultValue = "1") int days) {
        return ResponseEntity.ok(todayService.getSchedule(date, days));
    }
}
