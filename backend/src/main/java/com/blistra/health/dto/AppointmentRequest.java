package com.blistra.health.dto;

import com.blistra.health.domain.AppointmentStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AppointmentRequest {

    @NotBlank(message = "Title is required")
    @Size(max = 200, message = "Title must be at most 200 characters")
    private String title;

    @NotNull(message = "Scheduled at is required")
    private OffsetDateTime scheduledAt;

    @Size(max = 200, message = "Location must be at most 200 characters")
    private String location;

    @Size(max = 1000, message = "Notes must be at most 1000 characters")
    private String notes;

    private AppointmentStatus status;
}