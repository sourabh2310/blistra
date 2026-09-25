package com.blistra.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * identifier = username, email or phone. channel optionally selects EMAIL or
 * SMS; defaults to the verified channel (email first). The response is always
 * generic to prevent account enumeration.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ForgotPasswordRequest {
    private String identifier;
    private String channel;
}
