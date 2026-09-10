package com.blistra.planner.dto;

import com.blistra.planner.domain.EventStatus;
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
public class EventResponse {

    private UUID id;
    private String title;
    private String description;
    private String location;
    private OffsetDateTime startAt;
    private OffsetDateTime endAt;
    private EventStatus status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}