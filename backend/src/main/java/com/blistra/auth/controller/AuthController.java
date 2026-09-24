package com.blistra.auth.controller;

import com.blistra.auth.application.AuthService;
import com.blistra.auth.dto.AuthResponse;
import com.blistra.auth.dto.AvailabilityResponse;
import com.blistra.auth.dto.ChangePasswordRequest;
import com.blistra.auth.dto.ForgotPasswordRequest;
import com.blistra.auth.dto.RecoveryChannelsResponse;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.auth.dto.ResetPasswordRequest;
import com.blistra.auth.dto.UserResponse;
import com.blistra.auth.dto.VerifyOtpRequest;
import com.blistra.auth.otp.VerificationService;
import com.blistra.auth.security.BlistraUserPrincipal;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/auth")
@Tag(name = "Authentication", description = "Registration, verification, login and password recovery")
public class AuthController {

    @Autowired
    private AuthService authService;

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Register a new account",
            description = "Create a username/email/phone account (PENDING_VERIFICATION) with an "
                    + "atomic profile row, then issue email/phone OTPs. Returns the session "
                    + "token so verification can proceed without a second login.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Account created",
                    content = @Content(schema = @Schema(implementation = UserResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request (validation error)"),
            @ApiResponse(responseCode = "409", description = "Username, email or phone already registered")
    })
    public ResponseEntity<UserResponse> register(@Valid @RequestBody RegisterRequest request) {
        log.info("Received registration request");
        UserResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/login")
    @Operation(summary = "Login with username, email or phone",
            description = "A single identifier field resolves to the same account. "
                    + "PENDING_VERIFICATION accounts may sign in; the client routes "
                    + "on the verification/onboarding flags.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Login successful",
                    content = @Content(schema = @Schema(implementation = AuthResponse.class))),
            @ApiResponse(responseCode = "400", description = "Invalid request"),
            @ApiResponse(responseCode = "401", description = "Invalid credentials")
    })
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("Received login request");
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/verify/email")
    @Operation(summary = "Verify the account email with the 6-digit OTP")
    public ResponseEntity<UserResponse> verifyEmail(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @Valid @RequestBody VerifyOtpRequest request) {
        return ResponseEntity.ok(authService.verifyEmail(principal.getId(), request.getCode()));
    }

    @PostMapping("/verify/phone")
    @Operation(summary = "Verify the account phone with the 6-digit OTP")
    public ResponseEntity<UserResponse> verifyPhone(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @Valid @RequestBody VerifyOtpRequest request) {
        return ResponseEntity.ok(authService.verifyPhone(principal.getId(), request.getCode()));
    }

    @PostMapping("/resend/email")
    @Operation(summary = "Re-send the email OTP (cooldown + hourly cap enforced)")
    public ResponseEntity<Map<String, Object>> resendEmail(
            @AuthenticationPrincipal BlistraUserPrincipal principal) {
        VerificationService.Issuance issuance = authService.resendEmail(principal.getId());
        return ResponseEntity.ok(Map.of(
                "expiresAt", issuance.expiresAt().toString(),
                "resendCooldownSeconds", issuance.cooldownSeconds()));
    }

    @PostMapping("/resend/phone")
    @Operation(summary = "Re-send the phone OTP (cooldown + hourly cap enforced)")
    public ResponseEntity<Map<String, Object>> resendPhone(
            @AuthenticationPrincipal BlistraUserPrincipal principal) {
        VerificationService.Issuance issuance = authService.resendPhone(principal.getId());
        return ResponseEntity.ok(Map.of(
                "expiresAt", issuance.expiresAt().toString(),
                "resendCooldownSeconds", issuance.cooldownSeconds()));
    }

    @PostMapping("/recovery/channels")
    @Operation(summary = "Resolve recovery channels for an identifier",
            description = "Returns only the verified recovery channels (EMAIL/SMS) "
                    + "with masked destinations. Unknown identifiers yield 404 so "
                    + "the client stops before any OTP is generated or sent. The "
                    + "issuance endpoint itself stays generic.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Verified channels resolved"),
            @ApiResponse(responseCode = "404", description = "No account for this identifier")
    })
    public ResponseEntity<RecoveryChannelsResponse> recoveryChannels(
            @RequestBody ForgotPasswordRequest request) {
        return ResponseEntity.ok(authService.recoveryChannels(
                request.getIdentifier() == null ? "" : request.getIdentifier()));
    }

    @PostMapping("/forgot-password")
    @Operation(summary = "Start password recovery",
            description = "Always returns the same generic message whether or not the "
                    + "account exists (anti-enumeration).")
    public ResponseEntity<Map<String, String>> forgotPassword(
            @RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(
                request.getIdentifier() == null ? "" : request.getIdentifier(),
                request.getChannel());
        return ResponseEntity.ok(Map.of(
                "message", "If the account exists, a verification code will be sent.",
                "timestamp", LocalDateTime.now().toString()));
    }

    @PostMapping("/reset-password")
    @Operation(summary = "Reset the password with a recovery OTP")
    public ResponseEntity<Map<String, String>> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request.getIdentifier(), request.getCode(),
                request.getNewPassword(), request.getConfirmPassword());
        return ResponseEntity.ok(Map.of("message", "Password has been reset. You can now sign in."));
    }

    @GetMapping("/availability")
    @Operation(summary = "Check username/email/phone availability",
            description = "Live check for the registration wizard so taken values "
                    + "can be flagged while typing. Each supplied field returns true "
                    + "when well-formed and not yet registered, false when taken or "
                    + "malformed, and is omitted when not supplied. Registration "
                    + "itself still enforces uniqueness.")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Availability result")
    })
    public ResponseEntity<AvailabilityResponse> availability(
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String email,
            @RequestParam(required = false) String phone) {
        return ResponseEntity.ok(
                authService.checkAvailability(username, email, phone));
    }

    @PostMapping("/change-password")
    @Operation(summary = "Change the password (authenticated, current password required)")
    public ResponseEntity<UserResponse> changePassword(
            @AuthenticationPrincipal BlistraUserPrincipal principal,
            @Valid @RequestBody ChangePasswordRequest request) {
        return ResponseEntity.ok(authService.changePassword(
                principal.getId(), request.getCurrentPassword(), request.getNewPassword()));
    }
}
