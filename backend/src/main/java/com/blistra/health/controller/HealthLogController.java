package com.blistra.health.controller;

import com.blistra.health.application.HealthLogService;
import com.blistra.health.dto.HealthLogRequest;
import com.blistra.health.dto.HealthLogResponse;
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
@RequestMapping("/api/v1/health/logs")
@Tag(name = "Health Logs", description = "Personal health observations recorded by the user")
public class HealthLogController {

    private final HealthLogService healthLogService;

    public HealthLogController(HealthLogService healthLogService) {
        this.healthLogService = healthLogService;
    }

    @GetMapping
    @Operation(summary = "List the current user's health logs")
    public ResponseEntity<PageResponse<HealthLogResponse>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @PageableDefault(size = 20, sort = "observedAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(healthLogService.list(from, to, pageable));
    }

    @PostMapping
    @Operation(summary = "Record a health observation")
    public ResponseEntity<HealthLogResponse> create(@Valid @RequestBody HealthLogRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(healthLogService.create(request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's health logs")
    public ResponseEntity<HealthLogResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(healthLogService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's health logs")
    public ResponseEntity<HealthLogResponse> update(@PathVariable UUID id,
                                                    @Valid @RequestBody HealthLogRequest request) {
        return ResponseEntity.ok(healthLogService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's health logs")
    public void delete(@PathVariable UUID id) {
        healthLogService.delete(id);
    }
}