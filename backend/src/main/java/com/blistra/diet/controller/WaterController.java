package com.blistra.diet.controller;

import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.diet.application.WaterService;
import com.blistra.diet.dto.PageResponse;
import com.blistra.diet.dto.WaterRequest;
import com.blistra.diet.dto.WaterResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
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

import java.time.LocalDate;
import java.util.UUID;

@Validated
@RestController
@RequestMapping("/api/v1/diet/water")
@Tag(name = "Diet Water", description = "Water intake tracking")
public class WaterController {

    private final WaterService waterService;

    public WaterController(WaterService waterService) {
        this.waterService = waterService;
    }

    @GetMapping
    @Operation(summary = "List water records",
            description = "Returns the authenticated user's water records. Provide date to see one "
                    + "local calendar day (offsetMinutes defines the UTC offset of that day). "
                    + "Without date, recent records are returned, newest first.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Paged water records",
                    content = @Content(schema = @Schema(implementation = WaterResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid query parameters"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public PageResponse<WaterResponse> list(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(defaultValue = "0") @Min(-1080) @Max(1080) int offsetMinutes,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return waterService.list(principal.getId(), date, offsetMinutes, page, size);
    }

    @PostMapping
    @Operation(summary = "Create a water record", description = "Adds a water-intake entry.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Water record created",
                    content = @Content(schema = @Schema(implementation = WaterResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<WaterResponse> create(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @Valid @RequestBody WaterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(waterService.create(principal.getId(), request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get a water record", description = "Returns one water record if owned by the user.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Water record",
                    content = @Content(schema = @Schema(implementation = WaterResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Water record not found")
    })
    public WaterResponse get(@AuthenticationPrincipal BlistraUserPrincipal principal,
                             @PathVariable UUID id) {
        return waterService.get(principal.getId(), id);
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a water record", description = "Updates amount, unit, and/or time.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Water record updated",
                    content = @Content(schema = @Schema(implementation = WaterResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Water record not found")
    })
    public WaterResponse update(@AuthenticationPrincipal BlistraUserPrincipal principal,
                                @PathVariable UUID id,
                                @Valid @RequestBody WaterRequest request) {
        return waterService.update(principal.getId(), id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete a water record", description = "Deletes the water record.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "204", description = "Water record deleted"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Water record not found")
    })
    public void delete(@AuthenticationPrincipal BlistraUserPrincipal principal,
                       @PathVariable UUID id) {
        waterService.delete(principal.getId(), id);
    }
}