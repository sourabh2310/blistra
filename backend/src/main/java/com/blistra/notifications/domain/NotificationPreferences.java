package com.blistra.notifications.domain;

import jakarta.persistence.*;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Per-user notification preferences, keyed by the owning user id.
 *
 * <p>Category toggles gate delivery for reminders of that {@link ReminderType}.
 * {@code hideSensitiveContent} keeps notification content generic for domain
 * categories so sensitive details are not revealed on lock screens.</p>
 */
@Entity
@Table(name = "notification_preferences")
public class NotificationPreferences {

    @Id
    @Column(name = "user_id", columnDefinition = "UUID")
    private UUID userId;

    @Column(nullable = false)
    private boolean enabled;

    @Column(name = "medicine_enabled", nullable = false)
    private boolean medicineEnabled;

    @Column(name = "habit_enabled", nullable = false)
    private boolean habitEnabled;

    @Column(name = "planner_enabled", nullable = false)
    private boolean plannerEnabled;

    @Column(name = "health_enabled", nullable = false)
    private boolean healthEnabled;

    @Column(name = "general_enabled", nullable = false)
    private boolean generalEnabled;

    @Column(name = "hide_sensitive_content", nullable = false)
    private boolean hideSensitiveContent;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    public NotificationPreferences() {
        this.enabled = true;
        this.medicineEnabled = true;
        this.habitEnabled = true;
        this.plannerEnabled = true;
        this.healthEnabled = true;
        this.generalEnabled = true;
        this.hideSensitiveContent = false;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    public NotificationPreferences(UUID userId) {
        this();
        this.userId = userId;
    }

    public UUID getUserId() {
        return userId;
    }

    public void setUserId(UUID userId) {
        this.userId = userId;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public boolean isMedicineEnabled() {
        return medicineEnabled;
    }

    public void setMedicineEnabled(boolean medicineEnabled) {
        this.medicineEnabled = medicineEnabled;
    }

    public boolean isHabitEnabled() {
        return habitEnabled;
    }

    public void setHabitEnabled(boolean habitEnabled) {
        this.habitEnabled = habitEnabled;
    }

    public boolean isPlannerEnabled() {
        return plannerEnabled;
    }

    public void setPlannerEnabled(boolean plannerEnabled) {
        this.plannerEnabled = plannerEnabled;
    }

    public boolean isHealthEnabled() {
        return healthEnabled;
    }

    public void setHealthEnabled(boolean healthEnabled) {
        this.healthEnabled = healthEnabled;
    }

    public boolean isGeneralEnabled() {
        return generalEnabled;
    }

    public void setGeneralEnabled(boolean generalEnabled) {
        this.generalEnabled = generalEnabled;
    }

    public boolean isHideSensitiveContent() {
        return hideSensitiveContent;
    }

    public void setHideSensitiveContent(boolean hideSensitiveContent) {
        this.hideSensitiveContent = hideSensitiveContent;
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

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}