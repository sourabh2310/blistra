package com.blistra.notifications.domain;

/**
 * What kind of event a reminder refers to.
 *
 * <p>The notification platform holds only the reminder/DeliveryMetadata. The
 * owning domain (Medicine, Habits, Planner, Health) remains authoritative for
 * the underlying business event. GENERAL reminders are standalone user-created
 * reminders owned directly by the Notifications module.</p>
 */
public enum ReminderType {
    MEDICINE,
    HABIT,
    PLANNER,
    HEALTH,
    GENERAL
}