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
 * Payload to correct an existing dose record (change status, taken time, or
 * note). Transitioning a record to MISSED/SKIPPED clears its taken time.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DoseUpdateRequest {

    @NotNull(message = "Dose status is required")
    private DoseStatus status;

    @PastOrPresent(message = "Taken time cannot be in the future")
    private OffsetDateTime takenAt;

    @Size(max = 500, message = "Note must be at most 500 characters")
    private String note;
}