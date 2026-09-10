package com.blistra.health.dto;

import com.blistra.health.domain.EventType;
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
public class HealthEventResponse {

    private UUID id;
    private EventType type;
    private String title;
    private OffsetDateTime occurredAt;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}