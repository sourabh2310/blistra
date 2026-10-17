package com.blistra.finance.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

public record SettlementResponse(
        UUID id,
        UserSummary payer,
        UserSummary payee,
        String amount,
        String currency,
        LocalDate settledOn,
        String note,
        boolean editable,
        LocalDateTime createdAt,
        String status,
        boolean confirmable,
        UUID groupId
) {
}
