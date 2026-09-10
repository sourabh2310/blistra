package com.blistra.finance.application;

import com.blistra.finance.domain.Account;
import com.blistra.finance.domain.Money;
import com.blistra.finance.domain.TransactionType;
import com.blistra.finance.repository.FinanceTransactionRepository;
import com.blistra.finance.repository.FinanceTransferRepository;
import com.blistra.users.domain.User;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BalanceCalculatorTest {

    @Mock
    FinanceTransactionRepository transactions;
    @Mock
    FinanceTransferRepository transfers;
    @InjectMocks
    BalanceCalculator calculator;

    private Account account(UUID userId, UUID accountId, String opening) {
        User user = org.mockito.Mockito.mock(User.class);
        when(user.getId()).thenReturn(userId);
        Account a = org.mockito.Mockito.mock(Account.class);
        when(a.getUser()).thenReturn(user);
        when(a.getId()).thenReturn(accountId);
        when(a.getOpeningBalance()).thenReturn(Money.parse(opening));
        return a;
    }

    @Test
    void openingBalanceOnly() {
        UUID user = UUID.randomUUID(), acc = UUID.randomUUID();
        when(transactions.sumByTypeForAccount(user, acc)).thenReturn(List.of());
        when(transfers.sumInForAccount(user, acc)).thenReturn(new BigDecimal("0"));
        when(transfers.sumOutForAccount(user, acc)).thenReturn(new BigDecimal("0"));

        assertThat(calculator.balanceFor(account(user, acc, "1000.0000")))
                .isEqualByComparingTo("1000.0000");
    }

    @Test
    void incomeExpenseAndTransfers() {
        UUID user = UUID.randomUUID(), acc = UUID.randomUUID();
        when(transactions.sumByTypeForAccount(user, acc)).thenReturn(List.of(
                new Object[]{TransactionType.INCOME, new BigDecimal("500.0000")},
                new Object[]{TransactionType.EXPENSE, new BigDecimal("120.5000")}));
        when(transfers.sumInForAccount(user, acc)).thenReturn(new BigDecimal("50.0000"));
        when(transfers.sumOutForAccount(user, acc)).thenReturn(new BigDecimal("30.0000"));

        // 1000 + 500 - 120.5 + 50 - 30 = 1399.5
        assertThat(calculator.balanceFor(account(user, acc, "1000.0000")))
                .isEqualByComparingTo("1399.5000");
    }

    @Test
    void differentCurrenciesStaySeparate() {
        UUID user = UUID.randomUUID(), inr = UUID.randomUUID(), usd = UUID.randomUUID();
        when(transactions.sumByAccountAndType(user)).thenReturn(List.of(
                new Object[]{inr, TransactionType.INCOME, new BigDecimal("100.0000")},
                new Object[]{usd, TransactionType.INCOME, new BigDecimal("200.0000")}));

        Map<UUID, BigDecimal> balances = calculator.balancesFor(user);
        assertThat(balances.get(inr)).isEqualByComparingTo("100.0000");
        assertThat(balances.get(usd)).isEqualByComparingTo("200.0000");
        assertThat(balances).doesNotContainKey(UUID.randomUUID());
    }

    @Test
    void zeroTransactionsYieldZeroDelta() {
        UUID user = UUID.randomUUID();
        when(transactions.sumByAccountAndType(user)).thenReturn(List.of());
        when(transfers.sumByDestinationAccount(user)).thenReturn(List.of());
        when(transfers.sumBySourceAccount(user)).thenReturn(List.of());

        assertThat(calculator.balancesFor(user)).isEmpty();
    }
}
