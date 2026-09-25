package com.blistra.auth.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RegisterRequest {

    /**
     * Optional for legacy API clients: derived from the email local part when
     * absent. New clients must always send it.
     */
    @Size(min = 3, max = 30, message = "Username must be 3-30 characters")
    @Pattern(regexp = "^[A-Za-z0-9_.]*$", message = "Username may contain letters, digits, underscore and dot")
    private String username;

    @NotBlank(message = "Email is required")
    @Email(message = "Email must be a valid email address")
    private String email;

    /**
     * Optional for legacy API clients (stored NULL). New clients must send
     * canonical E.164 (e.g. +919876543210).
     */
    private String phone;

    @NotBlank(message = "Password is required")
    @Size(min = 8, max = 128, message = "Password must be at least 8 characters long")
    @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).*$",
            message = "Password must contain at least one letter and one digit")
    private String password;

    /** Optional display name for the profile; derived from email when absent. */
    @Size(max = 120, message = "Display name must be at most 120 characters")
    private String displayName;

    /**
     * Must be true when provided. Legacy clients omit it (no timestamp
     * recorded); new registration UI always sends true.
     */
    @AssertTrue(message = "Terms and privacy policy must be accepted")
    private Boolean termsAccepted;
}
