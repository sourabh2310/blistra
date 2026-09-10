package com.blistra.health.controller;

import com.blistra.health.application.HealthEventService;
import com.blistra.health.dto.HealthEventRequest;
import com.blistra.health.dto.HealthEventResponse;
import com.blistra.health.dto.PageResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/health/events")
@Tag(name = "Health Events", description = "Generic user-recorded health events (check-ups, vaccinations, visits)")
public class HealthEventController {

    private final HealthEventService healthEventService;

    public HealthEventController(HealthEventService healthEventService) {
        this.healthEventService = healthEventService;
    }

    @GetMapping
    @Operation(summary = "List the current user's health events")
    public ResponseEntity<PageResponse<HealthEventResponse>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @PageableDefault(size = 20, sort = "occurredAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(healthEventService.list(from, to, pageable));
    }

    @PostMapping
    @Operation(summary = "Record a health event")
    public ResponseEntity<HealthEventResponse> create(@Valid @RequestBody HealthEventRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(healthEventService.create(request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's health events")
    public ResponseEntity<HealthEventResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(healthEventService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's health events")
    public ResponseEntity<HealthEventResponse> update(@PathVariable UUID id,
                                                      @Valid @RequestBody HealthEventRequest request) {
        return ResponseEntity.ok(healthEventService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's health events")
    public void delete(@PathVariable UUID id) {
        healthEventService.delete(id);
    }
}