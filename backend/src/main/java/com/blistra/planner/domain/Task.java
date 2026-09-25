package com.blistra.planner.domain;

import com.blistra.common.exception.InvalidStateException;
import com.blistra.users.domain.User;
import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.EnumSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * A planner task owned by a single user.
 *
 * <p>Due-date semantics: {@code dueDate}/{@code dueTime} are the user-facing
 * calendar fields. {@code dueAt} is a derived instant resolved in the configured
 * user timezone at write time so that today/upcoming/overdue queries stay simple
 * and timezone-correct.</p>
 */
@Entity
@Table(name = "planner_task",
        indexes = {
                @Index(name = "idx_planner_task_user", columnList = "user_id"),
                @Index(name = "idx_planner_task_user_status", columnList = "user_id, status"),
                @Index(name = "idx_planner_task_user_due_at", columnList = "user_id, due_at"),
                @Index(name = "idx_planner_task_list", columnList = "list_id")
        })
public class Task {

    private static final Map<TaskStatus, Set<TaskStatus>> ALLOWED_TRANSITIONS = Map.of(
            TaskStatus.TODO, EnumSet.of(TaskStatus.IN_PROGRESS, TaskStatus.COMPLETED, TaskStatus.CANCELLED),
            TaskStatus.IN_PROGRESS, EnumSet.of(TaskStatus.TODO, TaskStatus.COMPLETED, TaskStatus.CANCELLED),
            TaskStatus.COMPLETED, EnumSet.of(TaskStatus.TODO),
            TaskStatus.CANCELLED, EnumSet.of(TaskStatus.TODO)
    );

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID")
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, updatable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "list_id")
    private TaskList list;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(length = 2000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TaskStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private TaskPriority priority;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "due_time")
    private LocalTime dueTime;

    @Column(name = "due_at")
    private OffsetDateTime dueAt;

    @Column(name = "start_at")
    private OffsetDateTime startAt;

    @Column(name = "end_at")
    private OffsetDateTime endAt;

    @Enumerated(EnumType.STRING)
    @Column(name = "reminder_mode", nullable = false, length = 24)
    private TaskReminderMode reminderMode;

    @Column(name = "completed_at")
    private OffsetDateTime completedAt;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    public Task() {
        this.status = TaskStatus.TODO;
        this.priority = TaskPriority.MEDIUM;
        this.reminderMode = TaskReminderMode.NONE;
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    /**
     * Transitions to {@code target} following the state machine. Completing a
     * task records {@code completedAt}; leaving the COMPLETED state clears it.
     */
    public void changeStatus(TaskStatus target, OffsetDateTime now) {
        if (target == null || target == this.status) {
            return;
        }
        Set<TaskStatus> allowed = ALLOWED_TRANSITIONS.get(this.status);
        if (allowed == null || !allowed.contains(target)) {
            throw new InvalidStateException("Task cannot transition from " + this.status + " to " + target);
        }
        this.status = target;
        if (target == TaskStatus.COMPLETED) {
            this.completedAt = now != null ? now : OffsetDateTime.now();
        } else {
            this.completedAt = null;
        }
    }

    public boolean isActive() {
        return status == TaskStatus.TODO || status == TaskStatus.IN_PROGRESS;
    }

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public TaskList getList() {
        return list;
    }

    public void setList(TaskList list) {
        this.list = list;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public TaskStatus getStatus() {
        return status;
    }

    public void setStatus(TaskStatus status) {
        this.status = status;
    }

    public TaskPriority getPriority() {
        return priority;
    }

    public void setPriority(TaskPriority priority) {
        this.priority = priority;
    }

    public LocalDate getDueDate() {
        return dueDate;
    }

    public void setDueDate(LocalDate dueDate) {
        this.dueDate = dueDate;
    }

    public LocalTime getDueTime() {
        return dueTime;
    }

    public void setDueTime(LocalTime dueTime) {
        this.dueTime = dueTime;
    }

    public OffsetDateTime getDueAt() {
        return dueAt;
    }

    public void setDueAt(OffsetDateTime dueAt) {
        this.dueAt = dueAt;
    }

    public OffsetDateTime getStartAt() {
        return startAt;
    }

    public void setStartAt(OffsetDateTime startAt) {
        this.startAt = startAt;
    }

    public OffsetDateTime getEndAt() {
        return endAt;
    }

    public void setEndAt(OffsetDateTime endAt) {
        this.endAt = endAt;
    }

    public TaskReminderMode getReminderMode() {
        return reminderMode;
    }

    public void setReminderMode(TaskReminderMode reminderMode) {
        this.reminderMode = reminderMode == null ? TaskReminderMode.NONE : reminderMode;
    }

    public OffsetDateTime getCompletedAt() {
        return completedAt;
    }

    public void setCompletedAt(OffsetDateTime completedAt) {
        this.completedAt = completedAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}