package com.blistra.finance.dto;

import com.blistra.finance.domain.TransactionType;
import io.swagger.v3.oas.annotations.media.Schema;

public record TransactionResponse(
        @Schema(description = "Transaction id as lower-case UUID")
        java.util.UUID id,

        @Schema(description = "Owning account id")
        java.util.UUID accountId,

        @Schema(description = "Owning account display name")
        String accountName,

        @Schema(description = "Owning account currency")
        String accountCurrency,

        @Schema(description = "Category id")
        java.util.UUID categoryId,

        @Schema(description = "Category display name")
        String categoryName,

        @Schema(description = "INCOME or EXPENSE")
        TransactionType type,

        @Schema(description = "Amount as a decimal string", example = "42.5000")
        String amount,

        @Schema(description = "ISO 4217 currency code (always the owning account currency)")
        String currency,

        @Schema(description = "Business date, ISO 8601 (yyyy-MM-dd)")
        String occurredAt,

        String description,

        String notes,

        @Schema(description = "Creation timestamp, ISO 8601 UTC")
        String createdAt,

        @Schema(description = "Last update timestamp, ISO 8601 UTC")
        String updatedAt
) {
}