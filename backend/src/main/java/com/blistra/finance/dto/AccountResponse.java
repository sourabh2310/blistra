package com.blistra.finance.dto;

import com.blistra.finance.domain.AccountType;
import com.blistra.finance.domain.AccountStatus;
import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Materialized account view returned by the API.
 *
 * <p>The current balance is derived from the opening balance plus the full
 * transaction/transfer history at query time; it is never stored.</p>
 */
public record AccountResponse(
        @Schema(description = "Account id as lower-case UUID")
        java.util.UUID id,

        @Schema(description = "Account display name")
        String name,

        @Schema(description = "CASH, BANK, SAVINGS, CREDIT_CARD, WALLET or OTHER")
        AccountType type,

        @Schema(description = "ISO 4217 currency code")
        String currency,

        @Schema(description = "Opening balance as a decimal string", example = "1000.0000")
        String openingBalance,

        @Schema(description = "Derived current balance as a decimal string", example = "1250.0000")
        String balance,

        @Schema(description = "ACTIVE or ARCHIVED")
        AccountStatus status,

        String notes,

        @Schema(description = "Creation timestamp, ISO 8601 UTC")
        String createdAt,

        @Schema(description = "Last update timestamp, ISO 8601 UTC")
        String updatedAt
) {
}