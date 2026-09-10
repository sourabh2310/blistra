package com.blistra.diet.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * A food item within a meal.
 *
 * <p>Nutrition values ({@code calories}, {@code protein}, ...) are optional and
 * only ever store what the user explicitly entered. Missing values are treated
 * as "not recorded" rather than zero.</p>
 *
 * <p>Ownership is enforced indirectly through the owning {@link Meal}.</p>
 */
@Entity
@Table(name = "meal_items")
public class MealItem {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "meal_id", nullable = false, columnDefinition = "UUID")
    private Meal meal;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(precision = 12, scale = 3)
    private BigDecimal quantity;

    @Column(length = 50)
    private String unit;

    @Column(name = "calories_kcal", precision = 10, scale = 2)
    private BigDecimal caloriesKcal;

    @Column(name = "protein_g", precision = 10, scale = 2)
    private BigDecimal proteinG;

    @Column(name = "carbohydrates_g", precision = 10, scale = 2)
    private BigDecimal carbohydratesG;

    @Column(name = "fat_g", precision = 10, scale = 2)
    private BigDecimal fatG;

    @Column(name = "fiber_g", precision = 10, scale = 2)
    private BigDecimal fiberG;

    @Column(length = 1000)
    private String notes;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    protected MealItem() {
    }

    public MealItem(Meal meal, String name, BigDecimal quantity, String unit,
                    BigDecimal caloriesKcal, BigDecimal proteinG, BigDecimal carbohydratesG,
                    BigDecimal fatG, BigDecimal fiberG, String notes) {
        this.meal = meal;
        this.name = name;
        this.quantity = quantity;
        this.unit = unit;
        this.caloriesKcal = caloriesKcal;
        this.proteinG = proteinG;
        this.carbohydratesG = carbohydratesG;
        this.fatG = fatG;
        this.fiberG = fiberG;
        this.notes = notes;
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

    public Meal getMeal() {
        return meal;
    }

    public void setMeal(Meal meal) {
        this.meal = meal;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public BigDecimal getQuantity() {
        return quantity;
    }

    public void setQuantity(BigDecimal quantity) {
        this.quantity = quantity;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }

    public BigDecimal getCaloriesKcal() {
        return caloriesKcal;
    }

    public void setCaloriesKcal(BigDecimal caloriesKcal) {
        this.caloriesKcal = caloriesKcal;
    }

    public BigDecimal getProteinG() {
        return proteinG;
    }

    public void setProteinG(BigDecimal proteinG) {
        this.proteinG = proteinG;
    }

    public BigDecimal getCarbohydratesG() {
        return carbohydratesG;
    }

    public void setCarbohydratesG(BigDecimal carbohydratesG) {
        this.carbohydratesG = carbohydratesG;
    }

    public BigDecimal getFatG() {
        return fatG;
    }

    public void setFatG(BigDecimal fatG) {
        this.fatG = fatG;
    }

    public BigDecimal getFiberG() {
        return fiberG;
    }

    public void setFiberG(BigDecimal fiberG) {
        this.fiberG = fiberG;
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