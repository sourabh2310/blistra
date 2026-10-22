package com.blistra.profile.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Finishes a new Google signup: the details the registration form collects.
 * Email comes from Google and there is no password, so neither is accepted.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class GoogleRegistrationRequest {

    @NotBlank(message = "Name is required")
    @Size(max = 100, message = "Name must be at most 100 characters")
    private String displayName;

    @NotBlank(message = "Username is required")
    @Size(min = 3, max = 30, message = "Username must be 3-30 characters")
    private String username;

    @Size(max = 32, message = "Phone must be at most 32 characters")
    private String phone;
}
