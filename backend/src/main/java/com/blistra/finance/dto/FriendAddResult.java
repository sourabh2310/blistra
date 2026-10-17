package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record FriendAddResult(
        @Schema(description = "ACCEPTED when they had already sent you a request, otherwise PENDING")
        String status,
        UserSummary user
) {
}
