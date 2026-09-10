package com.blistra.finance.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.List;

/**
 * Overall finance summary for a time window.
 *
 * <p>Currencies are never converted; results are grouped per currency in a
 * stable order sorted by currency code.</p>
 */
public record SummaryResponse(
        @Schema(description = "Inclusive start date, ISO 8601 (yyyy-MM-dd)")
        LocalDate from,

        @Schema(description = "Inclusive end date, ISO 8601 (yyyy-MM-dd)")
        LocalDate to,

        @Schema(description = "One section per currency, ordered by currency code")
        List<SummaryCurrencySection> currencies
) {
}