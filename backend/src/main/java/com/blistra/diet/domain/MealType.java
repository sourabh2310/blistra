package com.blistra.diet.domain;

/**
 * Eating-event categories used to organise meals.
 *
 * <p>{@code OTHER} supports free-form meals while {@link Meal#getTitle()} provides
 * the user-chosen name whenever the fixed taxonomy is not a good fit.</p>
 */
public enum MealType {
    BREAKFAST,
    LUNCH,
    DINNER,
    SNACK,
    OTHER
}