package com.blistra.finance.dto;

import java.util.UUID;

/** Public identity of a user inside Finance: never email or phone. */
public record UserSummary(UUID id, String username, String displayName) {
}
