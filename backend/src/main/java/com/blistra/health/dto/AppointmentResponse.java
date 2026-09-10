package com.blistra.health.dto;

import com.blistra.health.domain.AppointmentStatus;
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
public class AppointmentResponse {

    private UUID id;
    private String title;
    private OffsetDateTime scheduledAt;
    private String location;
    private String notes;
    private AppointmentStatus status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}