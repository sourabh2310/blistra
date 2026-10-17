package com.blistra.finance.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.util.UUID;

/** The part of an {@link Expense} that one participant owes. */
@Entity
@Table(name = "finance_expense_shares")
public class ExpenseShare {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "expense_id", nullable = false)
    private Expense expense;

    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    /** Percentage (PERCENT) or weight (SHARES) as entered; null otherwise. */
    @Column(name = "input_value", precision = 19, scale = 4)
    private BigDecimal inputValue;

    protected ExpenseShare() {
    }

    public ExpenseShare(UUID userId, BigDecimal amount, BigDecimal inputValue) {
        this.userId = userId;
        this.amount = amount;
        this.inputValue = inputValue;
    }

    void attachTo(Expense expense) {
        this.expense = expense;
    }

    public UUID getId() {
        return id;
    }

    public Expense getExpense() {
        return expense;
    }

    public UUID getUserId() {
        return userId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public BigDecimal getInputValue() {
        return inputValue;
    }
}
