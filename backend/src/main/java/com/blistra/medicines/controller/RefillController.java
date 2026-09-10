package com.blistra.medicines.controller;

import com.blistra.medicines.application.RefillService;
import com.blistra.medicines.dto.RefillRequest;
import com.blistra.medicines.dto.RefillResponse;
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
@RequestMapping("/api/v1/medicines/{medicineId}/refills")
@Tag(name = "Medicines - Refills", description = "Refill records for a medicine (informational only)")
public class RefillController {

    private final RefillService refillService;

    public RefillController(RefillService refillService) {
        this.refillService = refillService;
    }

    @GetMapping
    @Operation(summary = "List refills", description = "Returns the authenticated user's refill records for a medicine.")
    public List<RefillResponse> list(@PathVariable UUID medicineId) {
        return refillService.list(medicineId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Record a refill", description = "Adds a refill record to a medicine.")
    public RefillResponse create(@PathVariable UUID medicineId, @Valid @RequestBody RefillRequest request) {
        return refillService.create(medicineId, request);
    }

    @PutMapping("/{refillId}")
    @Operation(summary = "Update a refill", description = "Updates one of the authenticated user's refill records.")
    public RefillResponse update(@PathVariable UUID medicineId,
                                 @PathVariable UUID refillId,
                                 @Valid @RequestBody RefillRequest request) {
        return refillService.update(medicineId, refillId, request);
    }

    @DeleteMapping("/{refillId}")
    @Operation(summary = "Delete a refill", description = "Corrective action to remove a wrongly entered refill record.")
    public ResponseEntity<Void> delete(@PathVariable UUID medicineId, @PathVariable UUID refillId) {
        refillService.delete(medicineId, refillId);
        return ResponseEntity.noContent().build();
    }
}