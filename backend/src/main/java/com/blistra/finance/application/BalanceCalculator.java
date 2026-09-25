package com.blistra.finance.application;

import com.blistra.finance.domain.Account;
import com.blistra.finance.domain.AccountStatus;
import com.blistra.finance.domain.Money;
import com.blistra.finance.domain.TransactionType;
import com.blistra.finance.repository.FinanceTransactionRepository;
import com.blistra.finance.repository.FinanceTransferRepository;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Derives current account balances from the persisted transaction and transfer
 * history.
 *
 * <p>Balances are intentionally not stored: they are recomputed from the events
 * in a single source of truth, so they can never drift from that history and
 * concurrent writers never contend on a balance column.</p>
 */
@Component
public class BalanceCalculator {

    private final FinanceTransactionRepository transactionRepository;
    private final FinanceTransferRepository transferRepository;

    public BalanceCalculator(FinanceTransactionRepository transactionRepository,
                             FinanceTransferRepository transferRepository) {
        this.transactionRepository = transactionRepository;
        this.transferRepository = transferRepository;
    }

    /**
     * Computes the derived balance for every account of a user.
     *
     * <p>Balance = openingBalance + income - expense + transfersIn - transfersOut.
     * Transfers are never additionally reported as transactions, so there is no
     * double counting.</p>
     */
    public Map<UUID, BigDecimal> balancesFor(UUID userId) {
        Map<UUID, BigDecimal> balances = new HashMap<>();

        Map<UUID, BigDecimal> income = sumByType(transactionRepository.sumByAccountAndType(userId), TransactionType.INCOME);
        Map<UUID, BigDecimal> expense = sumByType(transactionRepository.sumByAccountAndType(userId), TransactionType.EXPENSE);
        Map<UUID, BigDecimal> transfersIn = transferRepository.sumByDestinationAccount(userId)
                .stream().collect(java.util.stream.Collectors.toMap(
                        row -> (UUID) row[0], row -> (BigDecimal) row[1]));
        Map<UUID, BigDecimal> transfersOut = transferRepository.sumBySourceAccount(userId)
                .stream().collect(java.util.stream.Collectors.toMap(
                        row -> (UUID) row[0], row -> (BigDecimal) row[1]));

        java.util.Set<UUID> accountIds = new java.util.HashSet<>();
        accountIds.addAll(income.keySet());
        accountIds.addAll(expense.keySet());
        accountIds.addAll(transfersIn.keySet());
        accountIds.addAll(transfersOut.keySet());

        for (UUID accountId : accountIds) {
            BigDecimal balance = BigDecimal.ZERO
                    .add(income.getOrDefault(accountId, BigDecimal.ZERO))
                    .subtract(expense.getOrDefault(accountId, BigDecimal.ZERO))
                    .add(transfersIn.getOrDefault(accountId, BigDecimal.ZERO))
                    .subtract(transfersOut.getOrDefault(accountId, BigDecimal.ZERO));
            balances.put(accountId, balance.setScale(Money.SCALE, java.math.RoundingMode.UNNECESSARY));
        }
        return balances;
    }

    /**
     * Derives the balance for a single account, taking the opening balance into
     * account when the current balance needs to be absolute (monthly net, for
     * example, must NOT include the opening balance).
     *
     * <p>Uses single-account aggregate queries so callers that need one balance
     * do not fan out over every account of the user.</p>
     */
    public BigDecimal balanceFor(Account account) {
        UUID userId = account.getUser().getId();
        UUID accountId = account.getId();
        BigDecimal income = BigDecimal.ZERO;
        BigDecimal expense = BigDecimal.ZERO;
        for (Object[] row : transactionRepository.sumByTypeForAccount(userId, accountId)) {
            TransactionType type = (TransactionType) row[0];
            BigDecimal sum = (BigDecimal) row[1];
            if (type == TransactionType.INCOME) {
                income = sum;
            } else if (type == TransactionType.EXPENSE) {
                expense = sum;
            }
        }
        BigDecimal in = transferRepository.sumInForAccount(userId, accountId);
        BigDecimal out = transferRepository.sumOutForAccount(userId, accountId);
        return account.getOpeningBalance()
                .add(income == null ? BigDecimal.ZERO : income)
                .subtract(expense == null ? BigDecimal.ZERO : expense)
                .add(in == null ? BigDecimal.ZERO : in)
                .subtract(out == null ? BigDecimal.ZERO : out)
                .setScale(Money.SCALE, java.math.RoundingMode.UNNECESSARY);
    }

    private Map<UUID, BigDecimal> sumByType(List<Object[]> rows, TransactionType type) {
        Map<UUID, BigDecimal> result = new HashMap<>();
        for (Object[] row : rows) {
            TransactionType rowType = (TransactionType) row[1];
            if (rowType == type) {
                result.put((UUID) row[0], (BigDecimal) row[2]);
            }
        }
        return result;
    }
}