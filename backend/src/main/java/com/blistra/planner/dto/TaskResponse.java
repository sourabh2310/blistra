package com.blistra.planner.dto;

import com.blistra.planner.domain.TaskReminderMode;
import com.blistra.planner.domain.TaskPriority;
import com.blistra.planner.domain.TaskStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaskResponse {

    private UUID id;
    private String title;
    private String description;
    private TaskStatus status;
    private TaskPriority priority;
    private LocalDate dueDate;
    private LocalTime dueTime;
    private OffsetDateTime dueAt;
    private OffsetDateTime startAt;
    private OffsetDateTime endAt;
    private TaskReminderMode reminderMode;
    private OffsetDateTime completedAt;
    private UUID taskListId;
    private String taskListName;
    private boolean overdue;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}