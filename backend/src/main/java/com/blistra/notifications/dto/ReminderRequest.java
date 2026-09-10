package com.blistra.notifications.dto;

import com.blistra.notifications.domain.ReminderType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Create-reminder request. The owning user is always derived from the
 * authenticated security context; owner fields are deliberately absent here.
 *
 * <p>Domain-generated reminders (MEDICINE/HABIT/PLANNER/HEALTH) are created by
 * their owning module via a read-only interface, never through this endpoint.
 * Only GENERAL reminders may be created directly by the client.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReminderRequest {

    @NotNull(message = "Type is required")
    private ReminderType type;

    @NotBlank(message = "Title is required")
    @Size(max = 160, message = "Title must be at most 160 characters")
    private String title;

    @Size(max = 500, message = "Body must be at most 500 characters")
    private String body;

    @NotNull(message = "Scheduled time is required")
    private OffsetDateTime scheduledAt;

    @NotBlank(message = "Timezone is required")
    @Size(max = 64, message = "Timezone must be at most 64 characters")
    private String timezone;

    private UUID sourceId;
}