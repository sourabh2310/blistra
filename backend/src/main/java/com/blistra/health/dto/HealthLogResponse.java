package com.blistra.health.dto;

import com.blistra.health.domain.Severity;
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
public class HealthLogResponse {

    private UUID id;
    private String title;
    private String description;
    private OffsetDateTime observedAt;
    private Severity severity;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}