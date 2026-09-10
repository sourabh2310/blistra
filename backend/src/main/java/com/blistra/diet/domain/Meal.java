package com.blistra.diet.domain;

import jakarta.persistence.CascadeType;
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
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * A single eating event recorded by a user.
 *
 * <p>{@code consumedAt} is an absolute instant carrying the offset the user was
 * in at the time of consumption, so the record is not interpreted using
 * server-local time.</p>
 */
@Entity
@Table(name = "meals")
public class Meal {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @Column(name = "user_id", nullable = false, columnDefinition = "UUID")
    private UUID userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "meal_type", nullable = false, length = 50)
    private MealType mealType;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(length = 2000)
    private String notes;

    @Column(name = "consumed_at", nullable = false, columnDefinition = "timestamptz")
    private OffsetDateTime consumedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "meal", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("createdAt ASC")
    private List<MealItem> items = new ArrayList<>();

    protected Meal() {
    }

    public Meal(UUID userId, MealType mealType, String title, String notes, OffsetDateTime consumedAt) {
        this.userId = userId;
        this.mealType = mealType;
        this.title = title;
        this.notes = notes;
        this.consumedAt = consumedAt;
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

    public UUID getUserId() {
        return userId;
    }

    public MealType getMealType() {
        return mealType;
    }

    public void setMealType(MealType mealType) {
        this.mealType = mealType;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public OffsetDateTime getConsumedAt() {
        return consumedAt;
    }

    public void setConsumedAt(OffsetDateTime consumedAt) {
        this.consumedAt = consumedAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public List<MealItem> getItems() {
        return Collections.unmodifiableList(items);
    }

    public void addItem(MealItem item) {
        items.add(item);
        item.setMeal(this);
    }
}