package com.blistra.health.controller;

import com.blistra.health.application.ActivityService;
import com.blistra.health.dto.ActivityRequest;
import com.blistra.health.dto.ActivityResponse;
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
@RequestMapping("/api/v1/health/activity")
@Tag(name = "Activity", description = "Basic user-entered activity tracking")
public class ActivityController {

    private final ActivityService activityService;

    public ActivityController(ActivityService activityService) {
        this.activityService = activityService;
    }

    @GetMapping
    @Operation(summary = "List the current user's activities")
    public ResponseEntity<PageResponse<ActivityResponse>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @PageableDefault(size = 20, sort = "performedAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(activityService.list(from, to, pageable));
    }

    @PostMapping
    @Operation(summary = "Record an activity")
    public ResponseEntity<ActivityResponse> create(@Valid @RequestBody ActivityRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(activityService.create(request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's activities")
    public ResponseEntity<ActivityResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(activityService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's activities")
    public ResponseEntity<ActivityResponse> update(@PathVariable UUID id,
                                                   @Valid @RequestBody ActivityRequest request) {
        return ResponseEntity.ok(activityService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's activities")
    public void delete(@PathVariable UUID id) {
        activityService.delete(id);
    }
}