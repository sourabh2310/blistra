package com.blistra.medicines.dto;

import com.blistra.medicines.domain.DoseStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Payload to record a new dose event.
 *
 * <p>{@link #getStatus()} must be TAKEN, MISSED, or SKIPPED. For TAKEN, if
 * {@link #getTakenAt()} is omitted the server records the current time. For
 * MISSED/SKIPPED a taken time is not allowed.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DoseRequest {

    @NotNull(message = "Dose status is required")
    private DoseStatus status;

    private OffsetDateTime scheduledAt;

    /**
     * Optional schedule this dose fulfils. When present it must belong to the
     * medicine; it lets "today" views match a record to its exact slot and
     * prevents double-recording the same scheduled occurrence.
     */
    private UUID scheduleId;

    @PastOrPresent(message = "Taken time cannot be in the future")
    private OffsetDateTime takenAt;

    @Size(max = 500, message = "Note must be at most 500 characters")
    private String note;
}