package com.blistra.medicines.dto;

import com.blistra.medicines.domain.DoseStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Dose record representation returned to clients.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DoseResponse {

    private UUID id;
    private UUID medicineId;
    private UUID scheduleId;
    private DoseStatus status;
    private OffsetDateTime scheduledAt;
    private OffsetDateTime takenAt;
    private String note;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}