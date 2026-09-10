package com.blistra.diet.controller;

import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.diet.application.DietSummaryService;
import com.blistra.diet.dto.DietSummaryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@Validated
@RestController
@RequestMapping("/api/v1/diet/summary")
@Tag(name = "Diet Summary", description = "Per-day food and nutrition summary for the authenticated user")
public class DietSummaryController {

    private final DietSummaryService dietSummaryService;

    public DietSummaryController(DietSummaryService dietSummaryService) {
        this.dietSummaryService = dietSummaryService;
    }

    @GetMapping
    @Operation(summary = "Daily summary",
            description = "Returns meals, water records, and nutrition totals for one local "
                    + "calendar day. offsetMinutes (default 0 / UTC) defines the UTC offset of "
                    + "that day. Nutrition totals are sums of explicitly recorded values only.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Daily summary",
                    content = @Content(schema = @Schema(implementation = DietSummaryResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid query parameters"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public DietSummaryResponse dailySummary(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(defaultValue = "0") @Min(-1080) @Max(1080) int offsetMinutes) {
        return dietSummaryService.dailySummary(principal.getId(), date, offsetMinutes);
    }
}