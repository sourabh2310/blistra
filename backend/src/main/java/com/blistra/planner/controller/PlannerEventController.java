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
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

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
}