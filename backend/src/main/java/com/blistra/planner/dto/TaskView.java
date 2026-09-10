package com.blistra.planner.dto;

/**
 * Available collection "lenses" for the task list endpoint.
 */
public enum TaskView {
    ALL,
    ACTIVE,
    COMPLETED,
    TODAY,
    OVERDUE,
    UPCOMING
}