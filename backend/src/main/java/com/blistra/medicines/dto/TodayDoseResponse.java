package com.blistra.medicines.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * One expected dose occurrence for a calendar day.
 *
 * <p>{@code status} is {@code PENDING} when the user has not recorded anything
 * for this slot; otherwise it mirrors the recorded {@code DoseRecord} status
 * ({@code TAKEN}, {@code MISSED}, {@code SKIPPED}). A dose is only ever marked
 * by an explicit user record — never inferred by the server.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TodayDoseResponse {

    private UUID medicineId;
    private String medicineName;
    private UUID scheduleId;
    private OffsetDateTime scheduledAt;
    private String status;
    private OffsetDateTime takenAt;
    private String doseAmount;
    private String doseUnit;
    private UUID doseRecordId;
}
