package com.blistra.notifications.controller;

import com.blistra.notifications.application.DeviceRegistrationService;
import com.blistra.notifications.dto.DeviceRegistrationRequest;
import com.blistra.notifications.dto.DeviceRegistrationResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Device registration endpoints. Push tokens are sensitive credentials: they
 * are accepted for storage, never returned by any API, and never logged.
 * Registrations are strictly scoped to the authenticated user.
 */
@RestController
@RequestMapping("/api/v1/notifications/devices")
@Tag(name = "Device Registration", description = "Notification device registration for future push delivery")
@SecurityRequirement(name = "bearerAuth")
public class DeviceRegistrationController {

    private final DeviceRegistrationService deviceRegistrationService;

    public DeviceRegistrationController(DeviceRegistrationService deviceRegistrationService) {
        this.deviceRegistrationService = deviceRegistrationService;
    }

    @PostMapping
    @Operation(summary = "Register or refresh a device for push notifications",
            description = "Upserts on the user+device natural key. The push token is stored but never returned in any response.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Device registered (without push token)",
                    content = @Content(schema = @Schema(implementation = DeviceRegistrationResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<DeviceRegistrationResponse> register(
            @Valid @RequestBody DeviceRegistrationRequest request) {
        return ResponseEntity.ok(deviceRegistrationService.register(request));
    }

    @GetMapping
    @Operation(summary = "List the current user's registered devices",
            description = "Never includes push tokens.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Devices for the authenticated user (without push tokens)"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<List<DeviceRegistrationResponse>> list() {
        return ResponseEntity.ok(deviceRegistrationService.list());
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Remove one of the current user's device registrations")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "204", description = "Device registration removed"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Device registration not found or owned by another user")
    })
    public void remove(@PathVariable UUID id) {
        deviceRegistrationService.remove(id);
    }
}