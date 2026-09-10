package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * A summary section describing one currency.
 *
 * <p>Currencies are never converted; each currency is summarized separately so
 * the frontend can render them distinctly.</p>
 */
public record SummaryCurrencySection(
        @Schema(description = "ISO 4217 currency code") String currency,
        @Schema(description = "Total income in this currency for the period, as a decimal string") String income,
        @Schema(description = "Total expense in this currency for the period, as a decimal string") String expense,
        @Schema(description = "Net change (income minus expense) in this currency, as a decimal string") String net,
        @Schema(description = "Total transfer-in, as a decimal string") String transferIn,
        @Schema(description = "Total transfer-out, as a decimal string") String transferOut,
        @Schema(description = "Expense grouped by category, largest first")
        java.util.List<SummaryCategorySpend> spendingByCategory
) {
}