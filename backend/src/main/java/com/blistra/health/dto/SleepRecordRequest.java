package com.blistra.health.dto;

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
public class SleepRecordRequest {

    @NotNull(message = "Start time is required")
    private OffsetDateTime startedAt;

    @NotNull(message = "End time is required")
    private OffsetDateTime endedAt;

    @Min(value = 1, message = "Rating must be between 1 and 5")
    @Max(value = 5, message = "Rating must be between 1 and 5")
    private Integer rating;

    @Size(max = 1000, message = "Notes must be at most 1000 characters")
    private String notes;
}