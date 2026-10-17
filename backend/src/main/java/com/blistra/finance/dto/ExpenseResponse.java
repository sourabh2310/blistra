package com.blistra.finance.dto;

import com.blistra.finance.domain.ExpenseCategory;
import com.blistra.finance.domain.SplitType;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

public record ExpenseResponse(
        UUID id,
        String description,
        ExpenseCategory category,
        String amount,
        String currency,
        LocalDate spentOn,
        String notes,
        SplitType splitType,
        UserSummary paidBy,
        UserSummary createdBy,
        List<ShareResponse> shares,
        @Schema(description = "Your share of the cost")
        String myShare,
        @Schema(description = "Positive: you lent this much; negative: you borrowed it")
        String myBalance,
        @Schema(description = "Whether you may edit or delete it (the creator only)")
        boolean editable,
        LocalDateTime createdAt
) {
}
