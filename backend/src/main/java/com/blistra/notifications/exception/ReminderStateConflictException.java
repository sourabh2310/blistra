package com.blistra.notifications.exception;

/**
 * Thrown when an operation conflicts with the current reminder lifecycle state
 * (for example updating a reminder that has already been cancelled).
 */
public class ReminderStateConflictException extends RuntimeException {

    public ReminderStateConflictException(String message) {
        super(message);
    }
}