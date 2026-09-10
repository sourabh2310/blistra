package com.blistra.health.dto;

import com.blistra.health.domain.EventType;
import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HealthEventRequest {

    @NotNull(message = "Event type is required")
    private EventType type;

    @NotBlank(message = "Title is required")
    @Size(max = 200, message = "Title must be at most 200 characters")
    private String title;

    @NotNull(message = "Occurred at is required")
    @PastOrPresent(message = "Event time cannot be in the future")
    private OffsetDateTime occurredAt;

    @Size(max = 1000, message = "Notes must be at most 1000 characters")
    private String notes;
}