package com.blistra.notifications.dto;

import com.blistra.notifications.domain.ReminderStatus;
import com.blistra.notifications.domain.ReminderType;
import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Reminder response. Never includes the owning user id; ownership is not a
 * client concern and is always derived from the authenticated context.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ReminderResponse {

    private UUID id;
    private ReminderType type;
    private String title;
    private String body;
    private OffsetDateTime scheduledAt;
    private String timezone;
    private ReminderStatus status;
    private UUID sourceId;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}