package com.blistra.habits.controller;

import com.blistra.habits.application.HabitCompletionService;
import com.blistra.habits.dto.CompletionRequest;
import com.blistra.habits.dto.CompletionResponse;
import com.blistra.habits.dto.HabitStatisticsResponse;
import com.blistra.habits.dto.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/habits/{habitId}/completions")
@Tag(name = "Habits", description = "Habit tracking for the current user")
public class HabitCompletionController {

    private final HabitCompletionService completionService;

    public HabitCompletionController(HabitCompletionService completionService) {
        this.completionService = completionService;
    }

    @PostMapping
    @Operation(summary = "Record a completion for a habit on a given day")
    public ResponseEntity<CompletionResponse> record(@PathVariable UUID habitId,
                                                     @Valid @RequestBody CompletionRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(completionService.record(habitId, request));
    }

    @DeleteMapping("/{completedOn}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Remove the completion of a habit for a given day")
    public void remove(@PathVariable UUID habitId,
                       @PathVariable @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate completedOn) {
        completionService.remove(habitId, completedOn);
    }

    @GetMapping
    @Operation(summary = "List the completion history of a habit")
    public ResponseEntity<PageResponse<CompletionResponse>> history(
            @PathVariable UUID habitId,
            @PageableDefault(size = 20, sort = "completedOn", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(completionService.history(habitId, pageable));
    }

    @GetMapping("/statistics")
    @Operation(summary = "Completion and streak statistics of a habit")
    public ResponseEntity<HabitStatisticsResponse> statistics(@PathVariable UUID habitId) {
        return ResponseEntity.ok(completionService.statistics(habitId));
    }
}