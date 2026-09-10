package com.blistra.planner.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaskListResponse {

    private UUID id;
    private String name;
    private String description;
    private long taskCount;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}