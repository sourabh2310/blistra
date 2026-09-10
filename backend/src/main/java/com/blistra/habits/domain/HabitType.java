package com.blistra.habits.domain;

/**
 * The kind of tracking a habit represents.
 *
 * <p>Represents how a habit is recorded and what (if any) progress target it
 * carries:</p>
 *
 * <ul>
 *   <li>{@link #BOOLEAN} - a simple done/not-done habit (e.g. "meditate").</li>
 *   <li>{@link #COUNT} - a quantified habit with a unit and optionally a target
 *       value (e.g. "drink 8 glasses of water").</li>
 *   <li>{@link #DURATION} - a time-based habit with an optional target in
 *       minutes (e.g. "exercise for 30 minutes").</li>
 * </ul>
 */
public enum HabitType {
    BOOLEAN,
    COUNT,
    DURATION
}