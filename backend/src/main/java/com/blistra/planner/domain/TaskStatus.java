package com.blistra.planner.domain;

/**
 * Lifecycle state of a planner task. Overdue is derived from due date/time and
 * the active state, never stored as a status.
 */
public enum TaskStatus {
    TODO,
    IN_PROGRESS,
    COMPLETED,
    CANCELLED
}