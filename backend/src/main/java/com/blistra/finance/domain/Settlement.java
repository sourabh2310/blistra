package com.blistra.finance.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

/** A repayment: {@code payerId} paid {@code payeeId} to settle a balance. */
@Entity
@Table(name = "finance_settlements")
public class Settlement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "created_by", nullable = false, updatable = false, columnDefinition = "UUID")
    private UUID createdBy;

    @Column(name = "payer_id", nullable = false, updatable = false, columnDefinition = "UUID")
    private UUID payerId;

    @Column(name = "payee_id", nullable = false, updatable = false, columnDefinition = "UUID")
    private UUID payeeId;

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    private String currency;

    @Column(name = "settled_on", nullable = false)
    private LocalDate settledOn;

    @Column(length = 255)
    private String note;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    protected Settlement() {
    }

    public Settlement(UUID createdBy, UUID payerId, UUID payeeId, BigDecimal amount,
                      String currency, LocalDate settledOn, String note) {
        this.createdBy = createdBy;
        this.payerId = payerId;
        this.payeeId = payeeId;
        this.amount = amount;
        this.currency = currency;
        this.settledOn = settledOn;
        this.note = note;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = this.createdAt;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    public boolean involves(UUID userId) {
        return payerId.equals(userId) || payeeId.equals(userId);
    }

    public UUID getId() {
        return id;
    }

    public UUID getCreatedBy() {
        return createdBy;
    }

    public UUID getPayerId() {
        return payerId;
    }

    public UUID getPayeeId() {
        return payeeId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public LocalDate getSettledOn() {
        return settledOn;
    }

    public String getNote() {
        return note;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
}
