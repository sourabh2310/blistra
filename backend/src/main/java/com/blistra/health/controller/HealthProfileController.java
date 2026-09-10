package com.blistra.health.controller;

import com.blistra.health.application.HealthProfileService;
import com.blistra.health.dto.HealthProfileRequest;
import com.blistra.health.dto.HealthProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/health/profile")
@Tag(name = "Health Profile", description = "A user's basic health profile")
public class HealthProfileController {

    private final HealthProfileService healthProfileService;

    public HealthProfileController(HealthProfileService healthProfileService) {
        this.healthProfileService = healthProfileService;
    }

    @GetMapping
    @Operation(summary = "Get the current user's health profile",
            description = "Returns 404 when no profile has been created yet")
    public ResponseEntity<HealthProfileResponse> getProfile() {
        return ResponseEntity.ok(healthProfileService.get());
    }

    @PutMapping
    @Operation(summary = "Create or update the current user's health profile",
            description = "Idempotent: updates the profile if one already exists")
    public ResponseEntity<HealthProfileResponse> saveProfile(@Valid @RequestBody HealthProfileRequest request) {
        return ResponseEntity.ok(healthProfileService.saveOrUpdate(request));
    }
}