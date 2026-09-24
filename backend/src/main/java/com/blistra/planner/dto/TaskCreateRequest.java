package com.blistra.planner.dto;

import com.blistra.planner.domain.TaskReminderMode;
import com.blistra.planner.domain.TaskPriority;
import com.blistra.planner.domain.TaskStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Create-task payload. Owned user, timestamps, and derived due instant are never
 * accepted from the client.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaskCreateRequest {

    @NotBlank(message = "Title is required")
    @Size(max = 200, message = "Title must be at most 200 characters")
    private String title;

    @Size(max = 2000, message = "Description must be at most 2000 characters")
    private String description;

    private TaskStatus status;

    private TaskPriority priority;

    private LocalDate dueDate;

    private LocalTime dueTime;

    private OffsetDateTime startAt;

    private OffsetDateTime endAt;

    private TaskReminderMode reminderMode;

    private UUID taskListId;
}