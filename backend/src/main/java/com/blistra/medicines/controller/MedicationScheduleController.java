package com.blistra.medicines.controller;

import com.blistra.medicines.application.MedicationScheduleService;
import com.blistra.medicines.dto.ScheduleRequest;
import com.blistra.medicines.dto.ScheduleResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/medicines/{medicineId}/schedules")
@Tag(name = "Medicines - Schedules", description = "Scheduled dosing instructions for a medicine")
public class MedicationScheduleController {

    private final MedicationScheduleService scheduleService;

    public MedicationScheduleController(MedicationScheduleService scheduleService) {
        this.scheduleService = scheduleService;
    }

    @GetMapping
    @Operation(summary = "List schedules", description = "Returns the schedules of one of the authenticated user's medicines.")
    public List<ScheduleResponse> list(@PathVariable UUID medicineId) {
        return scheduleService.list(medicineId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a schedule", description = "Adds a scheduled dosing instruction to a medicine.")
    public ScheduleResponse create(@PathVariable UUID medicineId,
                                   @Valid @RequestBody ScheduleRequest request) {
        return scheduleService.create(medicineId, request);
    }

    @PutMapping("/{scheduleId}")
    @Operation(summary = "Update a schedule", description = "Updates a schedule. Existing dose records are never rewritten.")
    public ScheduleResponse update(@PathVariable UUID medicineId,
                                   @PathVariable UUID scheduleId,
                                   @Valid @RequestBody ScheduleRequest request) {
        return scheduleService.update(medicineId, scheduleId, request);
    }

    @DeleteMapping("/{scheduleId}")
    @Operation(summary = "Delete a schedule", description = "Deletes a schedule; existing dose records keep their timestamps.")
    public ResponseEntity<Void> delete(@PathVariable UUID medicineId, @PathVariable UUID scheduleId) {
        scheduleService.delete(medicineId, scheduleId);
        return ResponseEntity.noContent().build();
    }
}