package com.blistra.health.dto;

import com.blistra.health.domain.Severity;
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
public class HealthLogRequest {

    @NotBlank(message = "Title is required")
    @Size(max = 120, message = "Title must be at most 120 characters")
    private String title;

    @Size(max = 1000, message = "Description must be at most 1000 characters")
    private String description;

    @NotNull(message = "Observed at is required")
    @PastOrPresent(message = "Observation time cannot be in the future")
    private OffsetDateTime observedAt;

    private Severity severity;

    @Size(max = 1000, message = "Notes must be at most 1000 characters")
    private String notes;
}