package com.blistra.finance.dto;

import com.blistra.finance.domain.ExpenseCategory;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.util.List;

/** One month of the user's spending plus where they stand with friends. */
public record FinanceOverviewResponse(
        String month,
        LocalDate from,
        LocalDate to,
        List<CurrencyOverview> currencies,
        @Schema(description = "Totals others owe you, per currency") List<CurrencyAmount> owedToYou,
        @Schema(description = "Totals you owe others, per currency") List<CurrencyAmount> youOwe,
        int friendCount,
        int pendingRequests
) {

    public record CurrencyOverview(
            String currency,
            @Schema(description = "Your own share of everything this month") String spent,
            @Schema(description = "What you actually paid out this month") String paid,
            String previousMonthSpent,
            String todaySpent,
            List<CategoryAmount> byCategory,
            List<DayAmount> daily,
            List<BudgetResponse> budgets
    ) {
    }

    public record CategoryAmount(ExpenseCategory category, String amount) {
    }

    public record DayAmount(LocalDate date, String amount) {
    }
}
