package com.blistra.notifications.domain;

/**
 * Lifecycle state of a reminder.
 *
 * <p>Only states that can be meaningfully tracked in V1 are modelled. Because
 * delivery happens through client-side local scheduling, DELIVERED/FAILED
 * transitions are intentionally omitted; they will be introduced when
 * server-side delivery exists rather than pretending to track them now.</p>
 */
public enum ReminderStatus {
    SCHEDULED,
    CANCELLED
}