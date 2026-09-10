package com.blistra.medicines.domain;

/**
 * Lifecycle status of a medicine as tracked by the user.
 *
 * <ul>
 *   <li>{@link #ACTIVE} - currently in use / being tracked.</li>
 *   <li>{@link #PAUSED} - temporarily set aside by the user.</li>
 *   <li>{@link #COMPLETED} - course finished; historical data is preserved.</li>
 *   <li>{@link #ARCHIVED} - no longer shown as active; historical data is preserved.</li>
 * </ul>
 *
 * <p>This status is a user-recorded state, not medical advice.</p>
 */
public enum MedicineStatus {
    ACTIVE,
    PAUSED,
    COMPLETED,
    ARCHIVED
}