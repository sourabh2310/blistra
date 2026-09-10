package com.blistra.medicines.domain;

/**
 * Outcome of a scheduled or ad-hoc dose as recorded by the user.
 *
 * <ul>
 *   <li>{@link #TAKEN} - the dose was taken (an actual event occurred).</li>
 *   <li>{@link #MISSED} - the dose was missed.</li>
 *   <li>{@link #SKIPPED} - the dose was intentionally skipped.</li>
 * </ul>
 *
 * <p>A dose is only recorded when the user records it. The application never
 * automatically marks a dose as MISSED simply because the user did not open
 * the app; that would create misleading health data.</p>
 */
public enum DoseStatus {
    TAKEN,
    MISSED,
    SKIPPED
}