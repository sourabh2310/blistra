package com.blistra.notifications.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Notification preferences for the current user.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationPreferencesResponse {

    private UUID userId;
    private boolean enabled;
    private boolean medicineEnabled;
    private boolean habitEnabled;
    private boolean plannerEnabled;
    private boolean healthEnabled;
    private boolean generalEnabled;
    private boolean hideSensitiveContent;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}