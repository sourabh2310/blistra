package com.blistra.health.controller;

import com.blistra.health.application.AppointmentService;
import com.blistra.health.dto.AppointmentRequest;
import com.blistra.health.dto.AppointmentResponse;
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
@RequestMapping("/api/v1/health/appointments")
@Tag(name = "Appointments", description = "Personal health appointments owned by the Health module")
public class AppointmentController {

    private final AppointmentService appointmentService;

    public AppointmentController(AppointmentService appointmentService) {
        this.appointmentService = appointmentService;
    }

    @GetMapping
    @Operation(summary = "List the current user's appointments")
    public ResponseEntity<PageResponse<AppointmentResponse>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(appointmentService.list(from, to, pageable));
    }

    @PostMapping
    @Operation(summary = "Create an appointment")
    public ResponseEntity<AppointmentResponse> create(@Valid @RequestBody AppointmentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(appointmentService.create(request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's appointments")
    public ResponseEntity<AppointmentResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(appointmentService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's appointments")
    public ResponseEntity<AppointmentResponse> update(@PathVariable UUID id,
                                                      @Valid @RequestBody AppointmentRequest request) {
        return ResponseEntity.ok(appointmentService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's appointments")
    public void delete(@PathVariable UUID id) {
        appointmentService.delete(id);
    }
}