package com.blistra.profile.controller;

import com.blistra.auth.dto.IdentityUpdateRequest;
import com.blistra.auth.dto.VerifyOtpRequest;
import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.profile.application.ProfileService;
import com.blistra.profile.dto.ProfileRequest;
import com.blistra.profile.dto.ProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/profile")
@Tag(name = "Profile", description = "Authenticated user profile and identity management")
public class ProfileController {

    @Autowired
    private ProfileService profileService;

    @GetMapping
    @Operation(summary = "Get the authenticated user's profile")
    public ResponseEntity<ProfileResponse> get() {
        return ResponseEntity.ok(profileService.get());
    }

    @PutMapping
    @Operation(summary = "Update display/locale profile fields")
    public ResponseEntity<ProfileResponse> update(@Valid @RequestBody ProfileRequest request) {
        return ResponseEntity.ok(profileService.update(request));
    }

    @PostMapping("/complete-onboarding")
    @Operation(summary = "Mark onboarding complete once verification + required profile exist")
    public ResponseEntity<ProfileResponse> completeOnboarding() {
        return ResponseEntity.ok(profileService.completeOnboarding());
    }

    @PostMapping("/identity")
    @Operation(summary = "Change username/email/phone (current password required; "
            + "email/phone take effect after OTP confirmation)")
    public ResponseEntity<ProfileResponse> updateIdentity(
            @Valid @RequestBody IdentityUpdateRequest request) {
        return ResponseEntity.ok(profileService.updateIdentity(
                request.getCurrentPassword(), request.getUsername(),
                request.getEmail(), request.getPhone()));
    }

    @PostMapping("/identity/confirm")
    @Operation(summary = "Confirm a staged email/phone change with the OTP")
    public ResponseEntity<ProfileResponse> confirmIdentity(
            @Valid @RequestBody VerifyOtpRequest request,
            @RequestParam(defaultValue = "EMAIL") String channel) {
        return ResponseEntity.ok(profileService.confirmIdentity(request.getCode(), channel));
    }
}
