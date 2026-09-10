package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record TransferResponse(
        @Schema(description = "Transfer id as lower-case UUID")
        java.util.UUID id,

        @Schema(description = "Source account id")
        java.util.UUID sourceAccountId,

        @Schema(description = "Source account display name")
        String sourceAccountName,

        @Schema(description = "Destination account id")
        java.util.UUID destinationAccountId,

        @Schema(description = "Destination account display name")
        String destinationAccountName,

        @Schema(description = "Amount as a decimal string", example = "150.0000")
        String amount,

        @Schema(description = "ISO 4217 currency code")
        String currency,

        @Schema(description = "Business date, ISO 8601 (yyyy-MM-dd)")
        String transferredAt,

        String note,

        @Schema(description = "Creation timestamp, ISO 8601 UTC")
        String createdAt,

        @Schema(description = "Last update timestamp, ISO 8601 UTC")
        String updatedAt
) {
}