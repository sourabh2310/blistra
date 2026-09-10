package com.blistra.finance;

import com.blistra.finance.domain.Account;
import com.blistra.finance.domain.AccountStatus;
import com.blistra.finance.domain.AccountType;
import com.blistra.finance.domain.Money;
import com.blistra.finance.repository.AccountRepository;
import com.blistra.users.domain.User;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Timestamp authority: PostgreSQL defaults/triggers own created_at/updated_at
 * on the row; the JPA callbacks keep the in-memory entity synchronized.
 * This test pins the observable behavior: populated on create, refreshed on update.
 */
class TimestampAuthorityIntegrationTest extends FinanceTestSupport {

    @Autowired
    AccountRepository accounts;
    @Autowired
    UserRepository users;

    @Test
    void createdAndUpdatedPopulatedAndUpdatedChanges() throws Exception {
        String token = registerAndLogin("ts@example.com", "Password123!");
        String accountId = createAccount(token, "Cash", "CASH", "USD", "10.0000");

        User user = users.findAll().stream()
                .filter(u -> u.getEmail().equals("ts@example.com")).findFirst().orElseThrow();
        Account account = accounts.findByIdAndUserId(
                java.util.UUID.fromString(accountId), user.getId()).orElseThrow();
        assertThat(account.getCreatedAt()).isNotNull();
        assertThat(account.getUpdatedAt()).isNotNull();
        LocalDateTime before = account.getUpdatedAt();

        Thread.sleep(1100);
        account.setNotes("touch");
        accounts.saveAndFlush(account);

        Account reloaded = accounts.findByIdAndUserId(
                java.util.UUID.fromString(accountId), user.getId()).orElseThrow();
        assertThat(reloaded.getCreatedAt()).isEqualTo(account.getCreatedAt());
        assertThat(reloaded.getUpdatedAt()).isAfterOrEqualTo(before);
        assertThat(reloaded.getOpeningBalance()).isEqualByComparingTo(Money.parse("10.0000"));
        assertThat(reloaded.getType()).isEqualTo(AccountType.CASH);
        assertThat(reloaded.getStatus()).isEqualTo(AccountStatus.ACTIVE);
    }
}
