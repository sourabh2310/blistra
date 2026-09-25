package com.blistra.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Live identity-availability result for the registration wizard. Each field
 * is {@code null} when it was not supplied (not checked), {@code true} when
 * the value is well-formed and not yet registered, {@code false} when it is
 * already taken or malformed. Registration itself still enforces uniqueness;
 * this endpoint is convenience only so the UI can warn while typing.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AvailabilityResponse {
    private Boolean usernameAvailable;
    private Boolean emailAvailable;
    private Boolean phoneAvailable;
}
