package com.blistra.notifications.exception;

/**
 * Thrown when a reminder is scheduled with a timestamp that cannot be honored
 * (for example a time strictly in the past). Past reminders are rejected rather
 * than fired unexpectedly, avoiding notification storms.
 */
public class InvalidReminderTimeException extends RuntimeException {

    public InvalidReminderTimeException(String message) {
        super(message);
    }
}