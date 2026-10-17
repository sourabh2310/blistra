package com.blistra.finance.application;

import com.blistra.finance.domain.Money;
import com.blistra.finance.dto.CurrencyAmount;
import com.blistra.finance.repository.ExpenseRepository;
import com.blistra.finance.repository.SettlementRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;

/**
 * Net balances between a user and everyone they share expenses with,
 * computed in four aggregate queries.
 *
 * <p>For another user X and one currency:
 * {@code balance = (X's shares of what I paid) - (my shares of what X paid)
 * - (what X paid me back) + (what I paid X back)}. Positive means X owes me.</p>
 */
@Service
@Transactional(readOnly = true)
public class BalanceService {

    private final ExpenseRepository expenseRepository;
    private final SettlementRepository settlementRepository;

    public BalanceService(ExpenseRepository expenseRepository, SettlementRepository settlementRepository) {
        this.expenseRepository = expenseRepository;
        this.settlementRepository = settlementRepository;
    }

    /** otherUserId -> currency -> signed balance (zero balances omitted). */
    public Map<UUID, Map<String, BigDecimal>> balances(UUID userId) {
        Map<UUID, Map<String, BigDecimal>> result = new HashMap<>();
        add(result, expenseRepository.owedToUser(userId), BigDecimal.ONE);
        add(result, expenseRepository.owedByUser(userId), BigDecimal.ONE.negate());
        add(result, settlementRepository.receivedByUser(userId), BigDecimal.ONE.negate());
        add(result, settlementRepository.paidByUser(userId), BigDecimal.ONE);
        result.values().forEach(perCurrency -> perCurrency.values().removeIf(v -> v.signum() == 0));
        result.values().removeIf(Map::isEmpty);
        return result;
    }

    public static List<CurrencyAmount> toList(Map<String, BigDecimal> perCurrency) {
        List<CurrencyAmount> list = new ArrayList<>();
        if (perCurrency == null) {
            return list;
        }
        new TreeMap<>(perCurrency).forEach((currency, amount) ->
                list.add(new CurrencyAmount(currency, Money.toPlainString(amount))));
        return list;
    }

    private static void add(Map<UUID, Map<String, BigDecimal>> result, List<Object[]> rows, BigDecimal sign) {
        for (Object[] row : rows) {
            UUID other = (UUID) row[0];
            String currency = (String) row[1];
            BigDecimal amount = ((BigDecimal) row[2]).multiply(sign);
            result.computeIfAbsent(other, k -> new HashMap<>()).merge(currency, amount, BigDecimal::add);
        }
    }
}
