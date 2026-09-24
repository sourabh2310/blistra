package com.blistra.auth.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LoginRequest {

    /**
     * One field for username, email or phone. Preferred key for new clients.
     */
    private String identifier;

    /**
     * Legacy key kept for backward compatibility (existing clients and tests
     * send the email here). Treated as an identifier: email, phone or
     * username.
     */
    private String email;

    @NotBlank(message = "Password is required")
    private String password;

    /** Resolves the effective identifier. */
    public String effectiveIdentifier() {
        if (identifier != null && !identifier.isBlank()) {
            return identifier.trim();
        }
        if (email != null && !email.isBlank()) {
            return email.trim();
        }
        return null;
    }
}
