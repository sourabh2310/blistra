package com.blistra.habits.controller;

import com.blistra.habits.application.HabitService;
import com.blistra.habits.domain.HabitStatus;
import com.blistra.habits.dto.HabitRequest;
import com.blistra.habits.dto.HabitResponse;
import com.blistra.habits.dto.HabitTodayResponse;
import com.blistra.habits.dto.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/habits")
@Tag(name = "Habits", description = "Habit tracking for the current user")
public class HabitController {

    private final HabitService habitService;

    public HabitController(HabitService habitService) {
        this.habitService = habitService;
    }

    @GetMapping
    @Operation(summary = "List the current user's habits")
    public ResponseEntity<PageResponse<HabitResponse>> list(
            @RequestParam(required = false) HabitStatus status,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(habitService.list(status, pageable));
    }

    @PostMapping
    @Operation(summary = "Create a habit")
    public ResponseEntity<HabitResponse> create(@Valid @RequestBody HabitRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(habitService.create(request));
    }

    @GetMapping("/today")
    @Operation(summary = "List active habits due today with their completion state")
    public ResponseEntity<List<HabitTodayResponse>> today() {
        return ResponseEntity.ok(habitService.today());
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's habits")
    public ResponseEntity<HabitResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(habitService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's habits")
    public ResponseEntity<HabitResponse> update(@PathVariable UUID id,
                                                @Valid @RequestBody HabitRequest request) {
        return ResponseEntity.ok(habitService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Archive one of the current user's habits")
    public void archive(@PathVariable UUID id) {
        habitService.archive(id);
    }
}