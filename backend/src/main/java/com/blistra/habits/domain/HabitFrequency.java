package com.blistra.habits.domain;

/**
 * How often a habit recurs.
 *
 * <ul>
 *   <li>{@link #DAILY} - due every calendar day.</li>
 *   <li>{@link #WEEKLY} - due only on the selected days of the week.</li>
 * </ul>
 */
public enum HabitFrequency {
    DAILY,
    WEEKLY
}