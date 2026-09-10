package com.blistra.notifications.controller;

import com.blistra.notifications.application.NotificationPreferencesService;
import com.blistra.notifications.dto.NotificationPreferencesResponse;
import com.blistra.notifications.dto.NotificationPreferencesUpdateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/notifications/preferences")
@Tag(name = "Notification Preferences", description = "User-scoped notification delivery preferences")
@SecurityRequirement(name = "bearerAuth")
public class NotificationPreferencesController {

    private final NotificationPreferencesService preferencesService;

    public NotificationPreferencesController(NotificationPreferencesService preferencesService) {
        this.preferencesService = preferencesService;
    }

    @GetMapping
    @Operation(summary = "Get the current user's notification preferences")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Preferences for the authenticated user",
                    content = @Content(schema = @Schema(implementation = NotificationPreferencesResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<NotificationPreferencesResponse> getPreferences() {
        return ResponseEntity.ok(preferencesService.getPreferences());
    }

    @PutMapping
    @Operation(summary = "Update the current user's notification preferences",
            description = "Absent fields keep their current value. Preferences always belong to the authenticated user; no user id is accepted from the client.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Updated preferences",
                    content = @Content(schema = @Schema(implementation = NotificationPreferencesResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<NotificationPreferencesResponse> updatePreferences(
            @Valid @RequestBody NotificationPreferencesUpdateRequest request) {
        return ResponseEntity.ok(preferencesService.update(request));
    }
}