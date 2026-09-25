package com.blistra.health.controller;

import com.blistra.health.application.SleepRecordService;
import com.blistra.health.dto.PageResponse;
import com.blistra.health.dto.SleepRecordRequest;
import com.blistra.health.dto.SleepRecordResponse;
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
@RequestMapping("/api/v1/health/sleep")
@Tag(name = "Sleep", description = "User-entered sleep records")
public class SleepRecordController {

    private final SleepRecordService sleepRecordService;

    public SleepRecordController(SleepRecordService sleepRecordService) {
        this.sleepRecordService = sleepRecordService;
    }

    @GetMapping
    @Operation(summary = "List the current user's sleep records")
    public ResponseEntity<PageResponse<SleepRecordResponse>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(sleepRecordService.list(from, to, pageable));
    }

    @PostMapping
    @Operation(summary = "Record a sleep period")
    public ResponseEntity<SleepRecordResponse> create(@Valid @RequestBody SleepRecordRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(sleepRecordService.create(request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's sleep records")
    public ResponseEntity<SleepRecordResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(sleepRecordService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's sleep records")
    public ResponseEntity<SleepRecordResponse> update(@PathVariable UUID id,
                                                      @Valid @RequestBody SleepRecordRequest request) {
        return ResponseEntity.ok(sleepRecordService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's sleep records")
    public void delete(@PathVariable UUID id) {
        sleepRecordService.delete(id);
    }
}