package com.blistra.finance.domain;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import org.hibernate.annotations.BatchSize;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * One spend. {@code paidBy} paid the full {@link #amount}; each
 * {@link ExpenseShare} records how much of it a participant owes. Shares
 * always sum to the amount. A personal expense has a single share owned by
 * the payer.
 */
@Entity
@Table(name = "finance_expenses")
public class Expense {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "created_by", nullable = false, updatable = false, columnDefinition = "UUID")
    private UUID createdBy;

    @Column(name = "paid_by", nullable = false, columnDefinition = "UUID")
    private UUID paidBy;
    @Column(name = "group_id", columnDefinition = "UUID")
    private UUID groupId;
    public UUID getGroupId() { return groupId; }
    public void setGroupId(UUID value) { groupId = value; }

    @Column(nullable = false, length = 255)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private ExpenseCategory category;

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(name = "spent_on", nullable = false)
    private LocalDate spentOn;

    @Enumerated(EnumType.STRING)
    @Column(name = "split_type", nullable = false, length = 20)
    private SplitType splitType;

    @Column(length = 1000)
    private String notes;

    // Batch-loaded so a page of expenses fetches all shares in one query.
    @BatchSize(size = 100)
    @OneToMany(mappedBy = "expense", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<ExpenseShare> shares = new ArrayList<>();

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    protected Expense() {
    }

    public Expense(UUID createdBy) {
        this.createdBy = createdBy;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = this.createdAt;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    /** Replaces all shares (orphans are deleted on flush). */
    public void replaceShares(List<ExpenseShare> newShares) {
        shares.clear();
        for (ExpenseShare share : newShares) {
            share.attachTo(this);
            shares.add(share);
        }
    }

    public boolean involves(UUID userId) {
        if (paidBy.equals(userId) || createdBy.equals(userId)) {
            return true;
        }
        return shares.stream().anyMatch(s -> s.getUserId().equals(userId));
    }

    /** The amount {@code userId} owes for this expense (zero if not a participant). */
    public BigDecimal shareOf(UUID userId) {
        return shares.stream()
                .filter(s -> s.getUserId().equals(userId))
                .map(ExpenseShare::getAmount)
                .findFirst()
                .orElse(BigDecimal.ZERO);
    }

    public UUID getId() {
        return id;
    }

    public UUID getCreatedBy() {
        return createdBy;
    }

    public UUID getPaidBy() {
        return paidBy;
    }

    public void setPaidBy(UUID paidBy) {
        this.paidBy = paidBy;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public ExpenseCategory getCategory() {
        return category;
    }

    public void setCategory(ExpenseCategory category) {
        this.category = category;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    public LocalDate getSpentOn() {
        return spentOn;
    }

    public void setSpentOn(LocalDate spentOn) {
        this.spentOn = spentOn;
    }

    public SplitType getSplitType() {
        return splitType;
    }

    public void setSplitType(SplitType splitType) {
        this.splitType = splitType;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public List<ExpenseShare> getShares() {
        return shares;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }
}
