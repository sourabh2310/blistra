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

    @PastOrPresent(message = "Taken time cannot be in the future")
    private OffsetDateTime takenAt;

    @Size(max = 500, message = "Note must be at most 500 characters")
    private String note;
}