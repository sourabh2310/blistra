package com.blistra.diet.domain;

/**
 * Dietary preference categories.
 *
 * <p>The taxonomy is intentionally small. {@code OTHER} allows a user-supplied
 * label (validated, length-limited) instead of a huge closed taxonomy.</p>
 */
public enum DietaryPreference {
    VEGETARIAN,
    VEGAN,
    NON_VEGETARIAN,
    PESCATARIAN,
    OTHER
}