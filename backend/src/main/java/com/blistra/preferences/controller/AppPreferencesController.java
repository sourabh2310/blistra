package com.blistra.preferences.controller;

import com.blistra.preferences.application.AppPreferencesService;
import com.blistra.preferences.dto.AppPreferencesResponse;
import com.blistra.preferences.dto.UpdateAppPreferencesRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Home/navigation preference endpoints under /api/v1/preferences. Every
 * preference set is scoped to the authenticated user; ownership is enforced
 * server-side and no user id is accepted from the client.
 */
@RestController
@RequestMapping("/api/v1/preferences")
@Tag(name = "Preferences", description = "Authenticated user's Home and navigation preferences")
@SecurityRequirement(name = "bearerAuth")
public class AppPreferencesController {

    private final AppPreferencesService service;

    public AppPreferencesController(AppPreferencesService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Get the current user's Home/navigation preferences",
            description = "Returns stored preferences, or deterministic Blistra defaults when none are saved yet.")
    public ResponseEntity<AppPreferencesResponse> get() {
        return ResponseEntity.ok(service.get());
    }

    @PutMapping
    @Operation(summary = "Replace the current user's Home/navigation preferences",
            description = "Unknown destination/widget identifiers are rejected. HOME and ADD are mandatory in bottomNav (max 5); DAY_AT_A_GLANCE is always kept first in homeWidgets.")
    public ResponseEntity<AppPreferencesResponse> update(
            @RequestBody UpdateAppPreferencesRequest request) {
        return ResponseEntity.ok(service.update(request == null ? new UpdateAppPreferencesRequest() : request));
    }
}
