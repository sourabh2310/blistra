package com.blistra.health.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SleepRecordResponse {

    private UUID id;
    private OffsetDateTime startedAt;
    private OffsetDateTime endedAt;
    private Long durationMinutes;
    private Integer rating;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}