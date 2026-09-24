package com.blistra.planner.controller;

import com.blistra.planner.application.PlannerEventService;
import com.blistra.planner.dto.EventCreateRequest;
import com.blistra.planner.dto.EventResponse;
import com.blistra.planner.dto.EventUpdateRequest;
import com.blistra.planner.dto.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/planner/events")
@Tag(name = "Planner Events", description = "Simple time-blocked planner events owned by the user")
public class PlannerEventController {

    private final PlannerEventService eventService;

    public PlannerEventController(PlannerEventService eventService) {
        this.eventService = eventService;
    }

    @GetMapping
    @Operation(summary = "List the current user's events with pagination")
    public ResponseEntity<PageResponse<EventResponse>> list(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(eventService.list(pageable));
    }

    @PostMapping
    @Operation(summary = "Create an event")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Event created"),
            @ApiResponse(responseCode = "400", description = "Invalid request or end time not after start time")
    })
    public ResponseEntity<EventResponse> create(@Valid @RequestBody EventCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(eventService.create(request));
    }

    @GetMapping("/{eventId}")
    @Operation(summary = "Get one of the current user's events")
    public ResponseEntity<EventResponse> get(@PathVariable UUID eventId) {
        return ResponseEntity.ok(eventService.get(eventId));
    }

    @PutMapping("/{eventId}")
    @Operation(summary = "Update one of the current user's events")
    public ResponseEntity<EventResponse> update(@PathVariable UUID eventId,
                                                @Valid @RequestBody EventUpdateRequest request) {
        return ResponseEntity.ok(eventService.update(eventId, request));
    }

    @DeleteMapping("/{eventId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's events")
    public void delete(@PathVariable UUID eventId) {
        eventService.delete(eventId);
    }

    @GetMapping("/by-date")
    @Operation(summary = "List the current user's events overlapping one calendar day",
            description = "Day window is resolved in the user timezone. Use for date navigation (one day only).")
    public ResponseEntity<List<EventResponse>> byDate(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(eventService.eventsForDate(date));
    }

    @GetMapping("/range")
    @Operation(summary = "List the current user's events overlapping an explicit range",
            description = "Half-open [from, to) window. Use for week views (max 31 days enforced client-side).")
    public ResponseEntity<List<EventResponse>> range(
            @RequestParam OffsetDateTime from,
            @RequestParam OffsetDateTime to) {
        return ResponseEntity.ok(eventService.eventsForRange(from, to));
    }

    @PostMapping("/{eventId}/complete")
    @Operation(summary = "Mark one of the current user's events complete")
    public ResponseEntity<EventResponse> complete(@PathVariable UUID eventId) {
        return ResponseEntity.ok(eventService.complete(eventId));
    }

    @PostMapping("/{eventId}/cancel")
    @Operation(summary = "Cancel one of the current user's events")
    public ResponseEntity<EventResponse> cancel(@PathVariable UUID eventId) {
        return ResponseEntity.ok(eventService.cancel(eventId));
    }

    @PostMapping("/{eventId}/reopen")
    @Operation(summary = "Reopen a completed or cancelled event")
    public ResponseEntity<EventResponse> reopen(@PathVariable UUID eventId) {
        return ResponseEntity.ok(eventService.reopen(eventId));
    }
}