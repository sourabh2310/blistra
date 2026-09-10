package com.blistra.dashboard.controller;

import com.blistra.dashboard.application.DashboardService;
import com.blistra.dashboard.dto.DashboardResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * Dashboard aggregation endpoint.
 *
 * <p>Returns a consolidated view across all domain modules for the
 * authenticated user. Each section is independently populated and may
 * be marked unavailable if that module's summary could not be computed.</p>
 */
@RestController
@RequestMapping("/api/v1/dashboard")
@Tag(name = "Dashboard", description = "Aggregated cross-module dashboard")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping
    @Operation(summary = "Get user dashboard",
            description = "Returns an aggregated dashboard across Planner, Medicines, Habits, Diet, Health, and Finance for the authenticated user.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Dashboard generated successfully",
                    content = @Content(schema = @Schema(implementation = DashboardResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required",
                    content = @Content(schema = @Schema(implementation = com.blistra.common.error.ApiErrorResponse.class)))
    })
    public ResponseEntity<DashboardResponse> getDashboard(
            @Parameter(description = "Local date for the dashboard (ISO-8601). Defaults to today in user's timezone.")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,

            @Parameter(description = "Client UTC offset in minutes (e.g., 330 for IST, -300 for EST). Used to compute the local calendar day boundaries. Defaults to 0 (UTC).")
            @RequestParam(required = false, defaultValue = "0") int offsetMinutes) {

        LocalDate targetDate = (date != null) ? date : OffsetDateTime.now(ZoneOffset.ofTotalSeconds(offsetMinutes * 60)).toLocalDate();

        DashboardResponse response = dashboardService.getDashboard(targetDate, offsetMinutes);
        return ResponseEntity.ok(response);
    }
}