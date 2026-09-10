package com.blistra.medicines.controller;

import com.blistra.health.dto.PageResponse;
import com.blistra.medicines.application.MedicineService;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.dto.MedicineRequest;
import com.blistra.medicines.dto.MedicineResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/medicines")
@Tag(name = "Medicines", description = "Personal medication tracking (user-recorded data, not medical advice)")
public class MedicineController {

    private final MedicineService medicineService;

    public MedicineController(MedicineService medicineService) {
        this.medicineService = medicineService;
    }

    @GetMapping
    @Operation(summary = "List medicines", description = "Returns the authenticated user's medicines, optionally filtered by status.")
    public PageResponse<MedicineResponse> list(
            @RequestParam(value = "status", required = false) MedicineStatus status,
            @SortDefault(sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return medicineService.list(status, pageable);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create a medicine", description = "Creates a medicine owned by the authenticated user.")
    public MedicineResponse create(@Valid @RequestBody MedicineRequest request) {
        return medicineService.create(request);
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a medicine", description = "Returns one of the authenticated user's medicines.")
    public MedicineResponse get(@PathVariable UUID id) {
        return medicineService.get(id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a medicine", description = "Updates one of the authenticated user's medicines.")
    public MedicineResponse update(@PathVariable UUID id, @Valid @RequestBody MedicineRequest request) {
        return medicineService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Archive a medicine", description = "Marks the medicine ARCHIVED so it leaves active lists while its history is preserved.")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        medicineService.archive(id);
        return ResponseEntity.noContent().build();
    }
}