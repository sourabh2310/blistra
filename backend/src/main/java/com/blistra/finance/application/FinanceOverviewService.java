package com.blistra.finance.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.common.time.UserTime;
import com.blistra.finance.domain.Budget;
import com.blistra.finance.domain.ExpenseCategory;
import com.blistra.finance.domain.Money;
import com.blistra.finance.dto.BudgetRequest;
import com.blistra.finance.dto.BudgetResponse;
import com.blistra.finance.dto.FinanceOverviewResponse;
import com.blistra.finance.dto.FinanceOverviewResponse.CategoryAmount;
import com.blistra.finance.dto.FinanceOverviewResponse.CurrencyOverview;
import com.blistra.finance.dto.FinanceOverviewResponse.DayAmount;
import com.blistra.finance.repository.BudgetRepository;
import com.blistra.finance.repository.ExpenseRepository;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.UUID;

/**
 * Monthly spending tracker: the user's own share of costs (not what they
 * fronted for friends), by category and by day, against optional budgets,
 * plus totals owed in each direction.
 */
@Service
@Transactional(readOnly = true)
public class FinanceOverviewService {

    private final ExpenseRepository expenseRepository;
    private final BudgetRepository budgetRepository;
    private final BalanceService balanceService;
    private final FriendService friendService;
    private final CurrentUserProvider currentUserProvider;
    private final UserTime userTime;

    public FinanceOverviewService(ExpenseRepository expenseRepository,
                                  BudgetRepository budgetRepository,
                                  BalanceService balanceService,
                                  FriendService friendService,
                                  CurrentUserProvider currentUserProvider,
                                  UserTime userTime) {
        this.expenseRepository = expenseRepository;
        this.budgetRepository = budgetRepository;
        this.balanceService = balanceService;
        this.friendService = friendService;
        this.currentUserProvider = currentUserProvider;
        this.userTime = userTime;
    }

    public FinanceOverviewResponse overview(YearMonth month) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        YearMonth target = month != null ? month : YearMonth.from(userTime.today());
        LocalDate from = target.atDay(1);
        LocalDate to = target.atEndOfMonth();
        YearMonth previous = target.minusMonths(1);
        LocalDate today = userTime.today();

        Map<String, Map<ExpenseCategory, BigDecimal>> byCategory = new HashMap<>();
        for (Object[] row : expenseRepository.spendingByCategory(me, from, to)) {
            byCategory.computeIfAbsent((String) row[0], k -> new HashMap<>())
                    .put((ExpenseCategory) row[1], (BigDecimal) row[2]);
        }
        Map<String, Map<LocalDate, BigDecimal>> byDay = new HashMap<>();
        for (Object[] row : expenseRepository.spendingByDay(me, from, to)) {
            byDay.computeIfAbsent((String) row[0], k -> new TreeMap<>())
                    .put((LocalDate) row[1], (BigDecimal) row[2]);
        }
        Map<String, BigDecimal> paid = sumByCurrency(expenseRepository.paidByUser(me, from, to));
        Map<String, BigDecimal> previousSpent = new HashMap<>();
        for (Object[] row : expenseRepository.spendingByCategory(me, previous.atDay(1), previous.atEndOfMonth())) {
            previousSpent.merge((String) row[0], (BigDecimal) row[2], BigDecimal::add);
        }
        List<Budget> budgets = budgetRepository.findByUserIdOrderByCurrencyAsc(me);

        TreeSet<String> currencies = new TreeSet<>(byCategory.keySet());
        currencies.addAll(previousSpent.keySet());
        budgets.forEach(b -> currencies.add(b.getCurrency()));

        List<CurrencyOverview> sections = new ArrayList<>();
        for (String currency : currencies) {
            Map<ExpenseCategory, BigDecimal> categories = byCategory.getOrDefault(currency, Map.of());
            BigDecimal spent = categories.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add);
            Map<LocalDate, BigDecimal> days = byDay.getOrDefault(currency, Map.of());
            List<CategoryAmount> categoryList = categories.entrySet().stream()
                    .sorted(Map.Entry.<ExpenseCategory, BigDecimal>comparingByValue().reversed())
                    .map(e -> new CategoryAmount(e.getKey(), Money.toPlainString(e.getValue())))
                    .toList();
            List<DayAmount> dayList = days.entrySet().stream()
                    .map(e -> new DayAmount(e.getKey(), Money.toPlainString(e.getValue())))
                    .toList();
            List<BudgetResponse> budgetList = budgets.stream()
                    .filter(b -> b.getCurrency().equals(currency))
                    .sorted(Comparator.comparing(b -> b.getCategory() == null ? "" : b.getCategory().name()))
                    .map(b -> toBudgetResponse(b, b.getCategory() == null ? spent
                            : categories.getOrDefault(b.getCategory(), BigDecimal.ZERO)))
                    .toList();
            sections.add(new CurrencyOverview(currency, Money.toPlainString(spent),
                    Money.toPlainString(paid.getOrDefault(currency, BigDecimal.ZERO)),
                    Money.toPlainString(previousSpent.getOrDefault(currency, BigDecimal.ZERO)),
                    Money.toPlainString(days.getOrDefault(today, BigDecimal.ZERO)),
                    categoryList, dayList, budgetList));
        }

        Map<String, BigDecimal> owedToYou = new TreeMap<>();
        Map<String, BigDecimal> youOwe = new TreeMap<>();
        balanceService.balances(me).values().forEach(perCurrency -> perCurrency.forEach((currency, amount) -> {
            if (amount.signum() > 0) {
                owedToYou.merge(currency, amount, BigDecimal::add);
            } else {
                youOwe.merge(currency, amount.negate(), BigDecimal::add);
            }
        }));

        return new FinanceOverviewResponse(target.toString(), from, to, sections,
                BalanceService.toList(owedToYou), BalanceService.toList(youOwe),
                friendService.acceptedFriendIds(me).size(), friendService.pendingIncoming(me));
    }

    /** currency -> category -> own share of spending, for the Home dashboard. */
    public Map<String, Map<ExpenseCategory, BigDecimal>> categorySpending(UUID userId, LocalDate from, LocalDate to) {
        Map<String, Map<ExpenseCategory, BigDecimal>> result = new TreeMap<>();
        for (Object[] row : expenseRepository.spendingByCategory(userId, from, to)) {
            result.computeIfAbsent((String) row[0], k -> new HashMap<>())
                    .put((ExpenseCategory) row[1], (BigDecimal) row[2]);
        }
        return result;
    }

    public List<BudgetResponse> budgets() {
        UUID me = currentUserProvider.getCurrentUser().getId();
        YearMonth month = YearMonth.from(userTime.today());
        Map<String, Map<ExpenseCategory, BigDecimal>> byCategory = new HashMap<>();
        for (Object[] row : expenseRepository.spendingByCategory(me, month.atDay(1), month.atEndOfMonth())) {
            byCategory.computeIfAbsent((String) row[0], k -> new HashMap<>())
                    .put((ExpenseCategory) row[1], (BigDecimal) row[2]);
        }
        return budgetRepository.findByUserIdOrderByCurrencyAsc(me).stream()
                .map(b -> {
                    Map<ExpenseCategory, BigDecimal> spent = byCategory.getOrDefault(b.getCurrency(), Map.of());
                    BigDecimal value = b.getCategory() == null
                            ? spent.values().stream().reduce(BigDecimal.ZERO, BigDecimal::add)
                            : spent.getOrDefault(b.getCategory(), BigDecimal.ZERO);
                    return toBudgetResponse(b, value);
                })
                .toList();
    }

    /** Creates or replaces the budget for that category (or overall) and currency. */
    @Transactional
    public BudgetResponse saveBudget(BudgetRequest request) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        BigDecimal limit = Money.parse(request.monthlyLimit());
        if (limit.signum() <= 0) {
            throw new BadRequestException("Budget must be more than zero");
        }
        Budget budget = (request.category() == null
                ? budgetRepository.findByUserIdAndCategoryIsNullAndCurrency(me, request.currency())
                : budgetRepository.findByUserIdAndCategoryAndCurrency(me, request.category(), request.currency()))
                .orElseGet(() -> new Budget(me, request.category(), request.currency(), limit));
        budget.setMonthlyLimit(limit);
        Budget saved = budgetRepository.save(budget);
        return budgets().stream().filter(b -> b.id().equals(saved.getId())).findFirst()
                .orElse(toBudgetResponse(saved, BigDecimal.ZERO));
    }

    @Transactional
    public void deleteBudget(UUID id) {
        UUID me = currentUserProvider.getCurrentUser().getId();
        budgetRepository.delete(budgetRepository.findByIdAndUserId(id, me)
                .orElseThrow(() -> new ResourceNotFoundException("Budget not found")));
    }

    private static BudgetResponse toBudgetResponse(Budget budget, BigDecimal spent) {
        return new BudgetResponse(budget.getId(), budget.getCategory(), budget.getCurrency(),
                Money.toPlainString(budget.getMonthlyLimit()), Money.toPlainString(spent));
    }

    private static Map<String, BigDecimal> sumByCurrency(List<Object[]> rows) {
        Map<String, BigDecimal> totals = new HashMap<>();
        for (Object[] row : rows) {
            totals.merge((String) row[0], (BigDecimal) row[1], BigDecimal::add);
        }
        return totals;
    }
}
