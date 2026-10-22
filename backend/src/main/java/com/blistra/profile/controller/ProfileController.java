package com.blistra.profile.controller;

import com.blistra.auth.dto.IdentityUpdateRequest;
import com.blistra.auth.dto.VerifyOtpRequest;
import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.profile.application.AccountDeactivationService;
import com.blistra.profile.application.ProfileAvatarService;
import com.blistra.profile.application.ProfileService;
import com.blistra.profile.dto.DeleteAccountRequest;
import com.blistra.profile.dto.GoogleRegistrationRequest;
import com.blistra.profile.dto.ProfileRequest;
import com.blistra.profile.dto.ProfileResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/profile")
@Tag(name = "Profile", description = "Authenticated user profile and identity management")
public class ProfileController {

    @Autowired
    private ProfileService profileService;

    @Autowired
    private ProfileAvatarService avatarService;

    @Autowired
    private AccountDeactivationService accountDeactivationService;

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

    @PostMapping("/google-registration")
    @Operation(summary = "Finish a new Google signup (name, username, optional phone)",
            description = "Only for Google-linked accounts that haven't finished onboarding. "
                    + "Email comes from Google and there is no password.")
    public ResponseEntity<ProfileResponse> completeGoogleRegistration(
            @Valid @RequestBody GoogleRegistrationRequest request) {
        return ResponseEntity.ok(profileService.completeGoogleRegistration(request));
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

    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload or replace the profile photo (JPEG, PNG or WebP, max 5 MB)")
    public ResponseEntity<ProfileResponse> uploadAvatar(@RequestParam("file") MultipartFile file) {
        return ResponseEntity.ok(avatarService.upload(file));
    }

    @GetMapping("/avatar")
    @Operation(summary = "Download the authenticated user's profile photo")
    public ResponseEntity<Resource> avatar() {
        ProfileAvatarService.Avatar avatar = avatarService.load();
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(avatar.contentType()))
                .cacheControl(CacheControl.noCache().cachePrivate())
                .header("X-Content-Type-Options", "nosniff")
                .body(avatar.resource());
    }

    @DeleteMapping("/avatar")
    @Operation(summary = "Remove the profile photo")
    public ResponseEntity<ProfileResponse> removeAvatar() {
        return ResponseEntity.ok(avatarService.remove());
    }

    @PostMapping("/delete-account")
    @Operation(summary = "Deactivate the account (current password or a fresh Google token required)",
            description = "The account becomes inactive and its email, phone, username and Google "
                    + "link are released so the person can register again. Data is retained.")
    public ResponseEntity<Void> deleteAccount(@RequestBody DeleteAccountRequest request) {
        accountDeactivationService.deactivateCurrentAccount(
                request.getCurrentPassword(), request.getGoogleIdToken());
        return ResponseEntity.noContent().build();
    }
}
