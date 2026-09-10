package com.blistra.medicines.controller;

import com.blistra.health.dto.PageResponse;
import com.blistra.medicines.application.DoseService;
import com.blistra.medicines.dto.DoseRequest;
import com.blistra.medicines.dto.DoseResponse;
import com.blistra.medicines.dto.DoseUpdateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.SortDefault;
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

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/medicines/{medicineId}/doses")
@Tag(name = "Medicines - Doses", description = "Recorded dose events for a medicine")
public class DoseController {

    private final DoseService doseService;

    public DoseController(DoseService doseService) {
        this.doseService = doseService;
    }

    @GetMapping
    @Operation(summary = "List dose records", description = "Returns the authenticated user's dose history for a medicine. "
            + "Unrecorded doses remain unrecorded; nothing is auto-marked.")
    public PageResponse<DoseResponse> list(
            @PathVariable UUID medicineId,
            @SortDefault(sort = "scheduledAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return doseService.list(medicineId, pageable);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Record a dose", description = "Records a TAKEN, MISSED, or SKIPPED dose. "
            + "For TAKEN the server records the current time when no takenAt is supplied.")
    public DoseResponse record(@PathVariable UUID medicineId, @Valid @RequestBody DoseRequest request) {
        return doseService.record(medicineId, request);
    }

    @PutMapping("/{doseId}")
    @Operation(summary = "Correct a dose record", description = "Changes the status/taken time/note of an existing dose record.")
    public DoseResponse update(@PathVariable UUID medicineId,
                               @PathVariable UUID doseId,
                               @Valid @RequestBody DoseUpdateRequest request) {
        return doseService.update(medicineId, doseId, request);
    }

    @DeleteMapping("/{doseId}")
    @Operation(summary = "Delete a dose record", description = "Corrective action to remove a wrongly entered dose record.")
    public ResponseEntity<Void> delete(@PathVariable UUID medicineId, @PathVariable UUID doseId) {
        doseService.delete(medicineId, doseId);
        return ResponseEntity.noContent().build();
    }
}