package com.blistra.notifications.dto;

import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

/**
 * Partial update request for a reminder. Delivery semantics (type, source
 * reference) are immutable; only content and schedule may change. Updates to
 * cancelled reminders are rejected with a conflict.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReminderUpdateRequest {

    @Size(max = 160, message = "Title must be at most 160 characters")
    private String title;

    @Size(max = 500, message = "Body must be at most 500 characters")
    private String body;

    private OffsetDateTime scheduledAt;

    @Size(max = 64, message = "Timezone must be at most 64 characters")
    private String timezone;
}