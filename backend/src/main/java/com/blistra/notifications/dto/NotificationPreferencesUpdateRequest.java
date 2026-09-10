package com.blistra.notifications.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Partial update body for notification preferences. Absent fields keep their
 * current value. The preferences always belong to the authenticated user.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class NotificationPreferencesUpdateRequest {

    private Boolean enabled;
    private Boolean medicineEnabled;
    private Boolean habitEnabled;
    private Boolean plannerEnabled;
    private Boolean healthEnabled;
    private Boolean generalEnabled;
    private Boolean hideSensitiveContent;
}