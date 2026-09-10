package com.blistra.diet.controller;

import com.blistra.diet.application.DietProfileService;
import com.blistra.diet.dto.DietProfileRequest;
import com.blistra.diet.dto.DietProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.blistra.auth.security.BlistraUserPrincipal;

@RestController
@RequestMapping("/api/v1/diet/profile")
@Tag(name = "Diet Profile", description = "Personal dietary preferences (non-medical)")
public class DietProfileController {

    private final DietProfileService dietProfileService;

    public DietProfileController(DietProfileService dietProfileService) {
        this.dietProfileService = dietProfileService;
    }

    @GetMapping
    @Operation(summary = "Get diet profile",
            description = "Returns the authenticated user's diet preferences. Fields are null "
                    + "(or absent) when no preferences have been saved yet.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Diet profile",
                    content = @Content(schema = @Schema(implementation = DietProfileResponse.class))),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public DietProfileResponse getProfile(@AuthenticationPrincipal BlistraUserPrincipal principal) {
        return dietProfileService.getProfile(principal.getId());
    }

    @PutMapping
    @Operation(summary = "Create or update diet profile",
            description = "Upserts the authenticated user's diet preferences. When "
                    + "dietaryPreference is OTHER, customPreference is required. "
                    + "customPreference is ignored for any other preference.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Diet profile saved",
                    content = @Content(schema = @Schema(implementation = DietProfileResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "401", description = "Authentication required")
    })
    public DietProfileResponse upsertProfile(@AuthenticationPrincipal BlistraUserPrincipal principal,
                                             @Valid @RequestBody DietProfileRequest request) {
        return dietProfileService.upsertProfile(principal.getId(), request);
    }
}