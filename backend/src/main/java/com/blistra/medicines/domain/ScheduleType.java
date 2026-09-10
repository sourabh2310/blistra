package com.blistra.medicines.domain;

/**
 * Recurrence style of a medication schedule.
 *
 * <ul>
 *   <li>{@link #DAILY} - once or several times every day.</li>
 *   <li>{@link #WEEKLY} - on one or more selected days of the week.</li>
 *   <li>{@link #CUSTOM_DAYS} - on an explicit set of selected days (kept for
 *       structuring data; functionally equivalent to {@link #WEEKLY}).</li>
 *   <li>{@link #AS_NEEDED} - taken as needed; no fixed times.</li>
 * </ul>
 *
 * <p>Schedules reflect the user's configured intent, never auto-generated
 * medical behavior.</p>
 */
public enum ScheduleType {
    DAILY,
    WEEKLY,
    CUSTOM_DAYS,
    AS_NEEDED
}