package com.blistra.health.controller;

import com.blistra.health.application.HealthMeasurementService;
import com.blistra.health.domain.MeasurementType;
import com.blistra.health.dto.MeasurementRequest;
import com.blistra.health.dto.MeasurementResponse;
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

import java.time.OffsetDateTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/health/measurements")
@Tag(name = "Health Measurements", description = "Historical health measurements (weight, height, heart rate, temperature, blood pressure)")
public class HealthMeasurementController {

    private final HealthMeasurementService measurementService;

    public HealthMeasurementController(HealthMeasurementService measurementService) {
        this.measurementService = measurementService;
    }

    @GetMapping
    @Operation(summary = "List the current user's measurements",
            description = "Returns the current user's measurements only. Supports type and time-range filtering plus pagination.")
    public ResponseEntity<PageResponse<MeasurementResponse>> list(
            @RequestParam(required = false) MeasurementType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(measurementService.list(type, from, to, pageable));
    }

    @PostMapping
    @Operation(summary = "Record a measurement")
    public ResponseEntity<MeasurementResponse> create(@Valid @RequestBody MeasurementRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(measurementService.create(request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's measurements")
    public ResponseEntity<MeasurementResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(measurementService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's measurements")
    public ResponseEntity<MeasurementResponse> update(@PathVariable UUID id,
                                                      @Valid @RequestBody MeasurementRequest request) {
        return ResponseEntity.ok(measurementService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's measurements")
    public void delete(@PathVariable UUID id) {
        measurementService.delete(id);
    }
}