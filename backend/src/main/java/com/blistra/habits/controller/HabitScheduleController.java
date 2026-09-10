package com.blistra.habits.controller;

import com.blistra.habits.application.HabitScheduleService;
import com.blistra.habits.dto.ScheduleRequest;
import com.blistra.habits.dto.ScheduleResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/habits/{habitId}/schedule")
@Tag(name = "Habits", description = "Habit tracking for the current user")
public class HabitScheduleController {

    private final HabitScheduleService scheduleService;

    public HabitScheduleController(HabitScheduleService scheduleService) {
        this.scheduleService = scheduleService;
    }

    @GetMapping
    @Operation(summary = "Get the schedule of one of the current user's habits")
    public ResponseEntity<ScheduleResponse> get(@PathVariable UUID habitId) {
        return ResponseEntity.ok(scheduleService.get(habitId));
    }

    @PutMapping
    @Operation(summary = "Create or replace the schedule of one of the current user's habits")
    public ResponseEntity<ScheduleResponse> upsert(@PathVariable UUID habitId,
                                                   @Valid @RequestBody ScheduleRequest request) {
        return ResponseEntity.ok(scheduleService.upsert(habitId, request));
    }
}