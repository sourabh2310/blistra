package com.blistra.finance.domain;

import com.blistra.users.domain.User;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * A place where the user tracks money (for example cash, a bank account, a
 * savings account, a credit card, or a wallet).
 *
 * <p>The current balance is deliberately NOT stored. It is derived from the
 * opening balance plus the transaction and transfer history, which keeps a
 * single source of truth and cannot drift from that history.</p>
 *
 * <p>V1 balance model (intentional restriction): {@code openingBalance} is
 * always non-negative (see {@code finance_accounts_opening_balance_not_negative}).
 * Balances are asset-side values; the financial direction is expressed by the
 * record type (INCOME / EXPENSE / transfer direction), never by an amount
 * sign. This holds for every account type <em>including</em> CREDIT_CARD: a
 * card is tracked by the money moved through it, not as a negative liability
 * balance. Modelling card debt (credit limit, amount due, minimum due) is a
 * future liability feature, not a correction — relaxing the sign would silently
 * change every balance invariant ({@code BalanceCalculator}, summaries,
 * {@code Money} scale guarantees).</p>
 *
 * <p>If liability balances are ever introduced, the safest migration is:
 * add a new nullable {@code opening_liability} / liability-aware columns (or a
 * separate card-liability table) with its own CHECK, backfill zeros, and keep
 * {@code opening_balance >= 0} untouched so existing history keeps its meaning.
 * Do not simply drop the CHECK.</p>
 */
@Entity
@Table(name = "finance_accounts")
public class Account {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, updatable = false)
    private User user;

    @Column(nullable = false, length = 100)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AccountType type;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(name = "opening_balance", nullable = false, precision = 19, scale = 4)
    private BigDecimal openingBalance;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AccountStatus status;

    @Column(length = 1000)
    private String notes;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    protected Account() {
    }

    public Account(User user, String name, AccountType type, String currency,
                   BigDecimal openingBalance, AccountStatus status, String notes) {
        this.user = user;
        this.name = name;
        this.type = type;
        this.currency = currency;
        this.openingBalance = openingBalance;
        this.status = status;
        this.notes = notes;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public UUID getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public AccountType getType() {
        return type;
    }

    public void setType(AccountType type) {
        this.type = type;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    public BigDecimal getOpeningBalance() {
        return openingBalance;
    }

    public void setOpeningBalance(BigDecimal openingBalance) {
        this.openingBalance = openingBalance;
    }

    public AccountStatus getStatus() {
        return status;
    }

    public void setStatus(AccountStatus status) {
        this.status = status;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }
}