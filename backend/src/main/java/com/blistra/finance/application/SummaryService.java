package com.blistra.finance.application;

import com.blistra.finance.domain.Money;
import com.blistra.finance.domain.TransactionType;
import com.blistra.finance.dto.SummaryCategorySpend;
import com.blistra.finance.dto.SummaryCurrencySection;
import com.blistra.finance.dto.SummaryResponse;
import com.blistra.finance.repository.FinanceTransferRepository;
import com.blistra.finance.repository.FinanceTransactionRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import java.util.UUID;

/**
 * Builds a currency-aware summary for a time window.
 *
 * <p>Currencies are never converted and never summed together: each currency is
 * aggregated separately and reported as its own section. This keeps arithmetic
 * exact and honest for a multi-currency user.</p>
 */
@Service
@Transactional(readOnly = true)
public class SummaryService {

    private final FinanceTransactionRepository transactionRepository;
    private final FinanceTransferRepository transferRepository;
    private final CurrentUserProvider currentUserProvider;

    public SummaryService(FinanceTransactionRepository transactionRepository,
                          FinanceTransferRepository transferRepository,
                          CurrentUserProvider currentUserProvider) {
        this.transactionRepository = transactionRepository;
        this.transferRepository = transferRepository;
        this.currentUserProvider = currentUserProvider;
    }

    public SummaryResponse summary(LocalDate from, LocalDate to) {
        User user = currentUserProvider.getCurrentUser();

        List<Object[]> txnRows = transactionRepository.sumByCurrencyAndType(user.getId(), from, to);
        Map<String, BigDecimal> income = new LinkedHashMap<>();
        Map<String, BigDecimal> expense = new LinkedHashMap<>();
        for (Object[] row : txnRows) {
            String currency = (String) row[0];
            TransactionType type = (TransactionType) row[1];
            BigDecimal amount = (BigDecimal) row[2];
            (type == TransactionType.INCOME ? income : expense)
                    .merge(currency, amount, BigDecimal::add);
        }

        List<Object[]> categoryRows = transactionRepository.sumByCurrencyAndCategory(
                user.getId(), TransactionType.EXPENSE, from, to);
        Map<String, Map<UUID, SummaryCategorySpend>> spending = new LinkedHashMap<>();
        for (Object[] row : categoryRows) {
            String currency = (String) row[0];
            UUID categoryId = (UUID) row[1];
            String categoryName = (String) row[2];
            BigDecimal amount = (BigDecimal) row[3];
            spending.computeIfAbsent(currency, k -> new LinkedHashMap<>())
                    .put(categoryId, new SummaryCategorySpend(categoryId, categoryName, Money.toPlainString(amount)));
        }

        Map<String, BigDecimal> transferOut = new LinkedHashMap<>();
        for (Object[] row : transferRepository.transferOutByCurrency(user.getId(), from, to)) {
            transferOut.merge((String) row[0], (BigDecimal) row[1], BigDecimal::add);
        }
        Map<String, BigDecimal> transferIn = new LinkedHashMap<>();
        for (Object[] row : transferRepository.transferInByCurrency(user.getId(), from, to)) {
            transferIn.merge((String) row[0], (BigDecimal) row[1], BigDecimal::add);
        }

        TreeSet<String> currencies = new TreeSet<>();
        currencies.addAll(income.keySet());
        currencies.addAll(expense.keySet());
        currencies.addAll(spending.keySet());
        currencies.addAll(transferIn.keySet());
        currencies.addAll(transferOut.keySet());

        List<SummaryCurrencySection> sections = new ArrayList<>();
        for (String currency : currencies) {
            BigDecimal inc = income.getOrDefault(currency, BigDecimal.ZERO);
            BigDecimal exp = expense.getOrDefault(currency, BigDecimal.ZERO);
            BigDecimal in = transferIn.getOrDefault(currency, BigDecimal.ZERO);
            BigDecimal out = transferOut.getOrDefault(currency, BigDecimal.ZERO);
            List<SummaryCategorySpend> spends = spending.getOrDefault(currency, Map.of()).values().stream()
                    .sorted(Comparator.comparing(SummaryCategorySpend::amount).reversed())
                    .toList();
            sections.add(new SummaryCurrencySection(
                    currency,
                    Money.toPlainString(inc),
                    Money.toPlainString(exp),
                    Money.toPlainString(inc.subtract(exp)),
                    Money.toPlainString(in),
                    Money.toPlainString(out),
                    spends));
        }

        return new SummaryResponse(from, to, sections);
    }
}