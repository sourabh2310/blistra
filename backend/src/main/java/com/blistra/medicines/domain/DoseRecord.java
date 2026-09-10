package com.blistra.medicines.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * A recorded dose event for a medicine.
 *
 * <p>Represents what actually happened (or the user's intentionally recorded
 * miss/skip). A dose is only recorded when the user records it; the
 * application never invents MISSED statuses on its own.</p>
 *
 * <p>Event timestamps are stored as offset date-times (UTC-normalized by the
 * database column type) so that the instant a dose was taken is preserved
 * regardless of the client's timezone.</p>
 */
@Entity
@Table(name = "dose_records")
public class DoseRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "medicine_id", nullable = false)
    private Medicine medicine;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "schedule_id")
    private MedicationSchedule schedule;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 25)
    private DoseStatus status;

    @Column(name = "scheduled_at", columnDefinition = "TIMESTAMPTZ")
    private OffsetDateTime scheduledAt;

    @Column(name = "taken_at", columnDefinition = "TIMESTAMPTZ")
    private OffsetDateTime takenAt;

    @Column(length = 500)
    private String note;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public DoseRecord() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    public DoseRecord(Medicine medicine, DoseStatus status) {
        this();
        this.medicine = medicine;
        this.status = status;
    }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public Medicine getMedicine() {
        return medicine;
    }

    public void setMedicine(Medicine medicine) {
        this.medicine = medicine;
    }

    public MedicationSchedule getSchedule() {
        return schedule;
    }

    public void setSchedule(MedicationSchedule schedule) {
        this.schedule = schedule;
    }

    public DoseStatus getStatus() {
        return status;
    }

    public void setStatus(DoseStatus status) {
        this.status = status;
    }

    public OffsetDateTime getScheduledAt() {
        return scheduledAt;
    }

    public void setScheduledAt(OffsetDateTime scheduledAt) {
        this.scheduledAt = scheduledAt;
    }

    public OffsetDateTime getTakenAt() {
        return takenAt;
    }

    public void setTakenAt(OffsetDateTime takenAt) {
        this.takenAt = takenAt;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}