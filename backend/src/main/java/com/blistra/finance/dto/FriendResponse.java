package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDateTime;
import java.util.List;

public record FriendResponse(
        UserSummary user,
        @Schema(description = "False for people you still share a balance with but are no longer friends with")
        boolean friend,
        LocalDateTime since,
        @Schema(description = "Net balance per currency: positive means they owe you, negative means you owe them")
        List<CurrencyAmount> balances
) {
}
