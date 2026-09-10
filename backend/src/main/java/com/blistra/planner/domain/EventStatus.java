package com.blistra.planner.domain;

/**
 * Lifecycle state of a planner event. Kept intentionally simple; Planner events
 * have no completion timestamp in V1.
 */
public enum EventStatus {
    SCHEDULED,
    COMPLETED,
    CANCELLED
}