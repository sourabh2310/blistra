package com.blistra.profile.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Re-authentication: the current password, or a fresh Google ID token. */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class DeleteAccountRequest {

    private String currentPassword;

    private String googleIdToken;
}
