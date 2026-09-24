package com.blistra.auth.controller;

import com.blistra.auth.otp.OtpPurpose;
import com.blistra.auth.otp.VerificationOtp;
import com.blistra.auth.application.AuthService;
import com.blistra.auth.security.BlistraUserPrincipal;
import com.blistra.common.exception.ResourceNotFoundException;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Development-only OTP retrieval for local testing without email/SMS
 * providers. Every handler 404s unless {@code blistra.otp.dev-mode=true};
 * production never exposes codes through logs or APIs.
 */
@RestController
@RequestMapping("/api/v1/auth/dev")
@Tag(name = "Auth (development only)", description = "Local OTP retrieval; disabled in production")
public class DevOtpController {

    @Autowired
    private AuthService authService;

    @GetMapping("/otp")
    @Operation(summary = "[DEV ONLY] Latest usable OTP for the authenticated account")
    public ResponseEntity<Map<String, String>> latest(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @RequestParam(defaultValue = "EMAIL_VERIFY") OtpPurpose purpose) {
        if (!authService.isDevMode()) {
            throw new ResourceNotFoundException("Not found");
        }
        VerificationOtp otp = authService.devLatestCode(principal.getId(), purpose)
                .orElseThrow(() -> new ResourceNotFoundException("No active code for " + purpose));
        return ResponseEntity.ok(Map.of(
                "purpose", otp.getPurpose().name(),
                "channel", otp.getChannel().name(),
                "code", otp.getDevCode() == null ? "" : otp.getDevCode(),
                "expiresAt", otp.getExpiresAt().toString()));
    }
}
