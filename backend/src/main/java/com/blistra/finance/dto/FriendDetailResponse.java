package com.blistra.finance.dto;

import java.util.List;

/** Everything shared with one person: balance, expenses and repayments. */
public record FriendDetailResponse(
        FriendResponse friend,
        List<ExpenseResponse> expenses,
        List<SettlementResponse> settlements
) {
}
