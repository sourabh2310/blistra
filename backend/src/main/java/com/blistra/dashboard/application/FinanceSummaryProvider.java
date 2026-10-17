package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.finance.application.BalanceService;
import com.blistra.finance.application.FinanceOverviewService;
import com.blistra.finance.domain.ExpenseCategory;
import com.blistra.finance.domain.Money;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;

/**
 * Finance card for Home: the user's own share of spending this month and
 * today (from logged and split expenses), plus what friends owe them and
 * what they owe friends.
 */
@Component
public class FinanceSummaryProvider {

    private static final String ZERO = Money.toPlainString(BigDecimal.ZERO);
    private static final int TOP_CATEGORIES = 3;

    private final FinanceOverviewService overviewService;
    private final BalanceService balanceService;
    private final CurrentUserProvider currentUserProvider;

    public FinanceSummaryProvider(FinanceOverviewService overviewService,
                                  BalanceService balanceService,
                                  CurrentUserProvider currentUserProvider) {
        this.overviewService = overviewService;
        this.balanceService = balanceService;
        this.currentUserProvider = currentUserProvider;
    }

    public DashboardResponse.FinanceSection getFinanceSummary(LocalDate date) {
        try {
            UUID me = currentUserProvider.getCurrentUser().getId();
            LocalDate from = date.withDayOfMonth(1);
            LocalDate to = date.withDayOfMonth(date.lengthOfMonth());

            Map<String, BigDecimal> owedToYou = new TreeMap<>();
            Map<String, BigDecimal> youOwe = new TreeMap<>();
            balanceService.balances(me).values().forEach(perCurrency -> perCurrency.forEach((currency, amount) -> {
                if (amount.signum() > 0) {
                    owedToYou.merge(currency, amount, BigDecimal::add);
                } else {
                    youOwe.merge(currency, amount.negate(), BigDecimal::add);
                }
            }));

            return DashboardResponse.FinanceSection.builder()
                    .from(from)
                    .to(to)
                    .currencies(sections(overviewService.categorySpending(me, from, to)))
                    .today(DashboardResponse.FinancePeriodSummary.builder()
                            .from(date)
                            .to(date)
                            .currencies(sections(overviewService.categorySpending(me, date, date)))
                            .build())
                    .owedToYou(amounts(owedToYou))
                    .youOwe(amounts(youOwe))
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.FinanceSection.builder()
                    .unavailable(true)
                    .error("Finance summary unavailable")
                    .build();
        }
    }

    private static List<DashboardResponse.CurrencySection> sections(
            Map<String, Map<ExpenseCategory, BigDecimal>> spending) {
        List<DashboardResponse.CurrencySection> result = new ArrayList<>();
        spending.forEach((currency, categories) -> {
            BigDecimal spent = categories.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add);
            List<DashboardResponse.CategorySpend> top = categories.entrySet().stream()
                    .sorted(Map.Entry.<ExpenseCategory, BigDecimal>comparingByValue().reversed())
                    .limit(TOP_CATEGORIES)
                    .map(e -> DashboardResponse.CategorySpend.builder()
                            .categoryId(e.getKey().name())
                            .categoryName(label(e.getKey()))
                            .amount(Money.toPlainString(e.getValue()))
                            .build())
                    .toList();
            result.add(DashboardResponse.CurrencySection.builder()
                    .currency(currency)
                    .income(ZERO)
                    .expense(Money.toPlainString(spent))
                    .net(Money.toPlainString(spent.negate()))
                    .transferIn(ZERO)
                    .transferOut(ZERO)
                    .topCategories(top)
                    .build());
        });
        return result;
    }

    private static List<DashboardResponse.MoneyAmount> amounts(Map<String, BigDecimal> totals) {
        return totals.entrySet().stream()
                .map(e -> DashboardResponse.MoneyAmount.builder()
                        .currency(e.getKey())
                        .amount(Money.toPlainString(e.getValue()))
                        .build())
                .toList();
    }

    private static String label(ExpenseCategory category) {
        String text = category.name().replace('_', ' ').toLowerCase(Locale.ROOT);
        return Character.toUpperCase(text.charAt(0)) + text.substring(1);
    }
}
