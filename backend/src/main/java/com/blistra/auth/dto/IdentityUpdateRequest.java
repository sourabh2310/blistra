package com.blistra.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Sensitive identity change. currentPassword is always required (prevents
 * session-hijack takeover). Username applies immediately when unique;
 * email/phone changes are staged as pending_* and take effect only after OTP
 * confirmation, preserving the old verified value until then.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class IdentityUpdateRequest {

    @NotBlank(message = "Current password is required")
    private String currentPassword;

    @Size(min = 3, max = 30, message = "Username must be 3-30 characters")
    private String username;

    @Size(max = 255, message = "Email must be at most 255 characters")
    private String email;

    @Size(max = 32, message = "Phone must be at most 32 characters")
    private String phone;
}
