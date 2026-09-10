package com.blistra.habits.domain;

/**
 * Lifecycle status of a habit.
 *
 * <ul>
 *   <li>{@link #ACTIVE} - currently tracked and due per its schedule.</li>
 *   <li>{@link #PAUSED} - set aside temporarily; no longer due.</li>
 *   <li>{@link #ARCHIVED} - retained for history but no longer active.</li>
 * </ul>
 */
public enum HabitStatus {
    ACTIVE,
    PAUSED,
    ARCHIVED
}