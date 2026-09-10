package com.blistra.notifications.controller;

import com.blistra.notifications.application.ReminderService;
import com.blistra.notifications.dto.ReminderRequest;
import com.blistra.notifications.dto.ReminderResponse;
import com.blistra.notifications.dto.ReminderUpdateRequest;
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
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Reminder endpoints under /api/v1/notifications/reminders. Every reminder is
 * scoped to the authenticated user; ownership is enforced server-side and no
 * user id is accepted from the client.
 *
 * <p>Only GENERAL reminders can be created through this API. Domain-generated
 * reminders (MEDICINE/HABIT/PLANNER/HEALTH) are created by their owning module
 * so that the source domain remains authoritative.</p>
 */
@RestController
@RequestMapping("/api/v1/notifications/reminders")
@Tag(name = "Reminders", description = "Reminder configuration owned by the Notifications platform")
@SecurityRequirement(name = "bearerAuth")
public class ReminderController {

    private final ReminderService reminderService;

    public ReminderController(ReminderService reminderService) {
        this.reminderService = reminderService;
    }

    @GetMapping
    @Operation(summary = "List the current user's reminders",
            description = "Filter by status. Defaults to SCHEDULED; use status=ALL to include cancelled reminders. Sorted by scheduled time ascending.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Reminders for the authenticated user",
                    content = @Content(schema = @Schema(implementation = ReminderResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "400", description = "Invalid status filter")
    })
    public ResponseEntity<List<ReminderResponse>> list(
            @RequestParam(value = "status", required = false) String status) {
        return ResponseEntity.ok(reminderService.list(status));
    }

    @PostMapping
    @Operation(summary = "Create a reminder",
            description = "Only GENERAL reminders can be created by the client. Scheduled time must be in the future. The owner is the authenticated user.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Reminder created",
                    content = @Content(schema = @Schema(implementation = ReminderResponse.class))),
            @ApiResponse(responseCode = "400", description = "Validation error, invalid timezone, or non-GENERAL type",
                    content = @Content(schema = @Schema(implementation = com.blistra.common.error.ApiErrorResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public ResponseEntity<ReminderResponse> create(@Valid @RequestBody ReminderRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(reminderService.create(request));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get one of the current user's reminders")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Reminder found",
                    content = @Content(schema = @Schema(implementation = ReminderResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Reminder not found or owned by another user")
    })
    public ResponseEntity<ReminderResponse> get(@PathVariable UUID id) {
        return ResponseEntity.ok(reminderService.get(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update one of the current user's reminders",
            description = "Partial update of title, body, scheduledAt and/or timezone. Cancelled reminders cannot be updated.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Reminder updated",
                    content = @Content(schema = @Schema(implementation = ReminderResponse.class))),
            @ApiResponse(responseCode = "400", description = "Validation error or no update fields provided"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Reminder not found or owned by another user"),
            @ApiResponse(responseCode = "409", description = "Reminder already cancelled")
    })
    public ResponseEntity<ReminderResponse> update(@PathVariable UUID id,
                                                   @Valid @RequestBody ReminderUpdateRequest request) {
        return ResponseEntity.ok(reminderService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Cancel one of the current user's reminders",
            description = "Cancels the reminder (soft delete). Cancelled reminders are never treated as active. Idempotent.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "204", description = "Reminder cancelled"),
            @ApiResponse(responseCode = "401", description = "Authentication required"),
            @ApiResponse(responseCode = "404", description = "Reminder not found or owned by another user")
    })
    public void cancel(@PathVariable UUID id) {
        reminderService.cancel(id);
    }
}