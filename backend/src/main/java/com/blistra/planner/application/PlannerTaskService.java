package com.blistra.planner.application;

import com.blistra.common.exception.BadRequestException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.planner.domain.Task;
import com.blistra.planner.domain.TaskList;
import com.blistra.planner.domain.TaskReminderMode;
import com.blistra.planner.domain.TaskPriority;
import com.blistra.planner.domain.TaskStatus;
import com.blistra.planner.dto.PageResponse;
import com.blistra.planner.dto.TaskCreateRequest;
import com.blistra.planner.dto.TaskResponse;
import com.blistra.planner.dto.TaskUpdateRequest;
import com.blistra.planner.dto.TaskView;
import com.blistra.planner.repository.TaskListRepository;
import com.blistra.planner.repository.TaskRepository;
import com.blistra.notifications.application.ReminderService;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
@Transactional
public class PlannerTaskService {

    private static final Set<TaskStatus> ACTIVE_STATUSES = EnumSet.of(TaskStatus.TODO, TaskStatus.IN_PROGRESS);
    private static final Set<TaskStatus> LIVE_STATUSES = EnumSet.allOf(TaskStatus.class);
    private static final Set<TaskStatus> COMPLETED_STATUSES = EnumSet.of(TaskStatus.COMPLETED);
    private static final int MAX_PAGE_SIZE = 50;

    private final TaskRepository taskRepository;
    private final TaskListRepository taskListRepository;
    private final CurrentUserProvider currentUserProvider;
    private final PlannerTime time;
    private final ReminderService reminderService;

    public PlannerTaskService(TaskRepository taskRepository,
                              TaskListRepository taskListRepository,
                              CurrentUserProvider currentUserProvider,
                              PlannerTime time,
                              ReminderService reminderService) {
        this.taskRepository = taskRepository;
        this.taskListRepository = taskListRepository;
        this.currentUserProvider = currentUserProvider;
        this.time = time;
        this.reminderService = reminderService;
    }

    @Transactional(readOnly = true)
    public PageResponse<TaskResponse> list(TaskView view, UUID taskListId, TaskPriority priority, Pageable pageable) {
        User user = currentUserProvider.getCurrentUser();
        TaskView effectiveView = view == null ? TaskView.ALL : view;

        Set<TaskStatus> statuses = switch (effectiveView) {
            case COMPLETED -> COMPLETED_STATUSES;
            case TODAY, OVERDUE, UPCOMING, ACTIVE -> ACTIVE_STATUSES;
            default -> LIVE_STATUSES;
        };

        OffsetDateTime from = null;
        OffsetDateTime to = null;
        OffsetDateTime overdueCutoff = null;
        OffsetDateTime todayStart = time.todayStart();
        OffsetDateTime now = time.now();

        switch (effectiveView) {
            case TODAY -> {
                from = todayStart;
                to = time.tomorrowStart();
            }
            case UPCOMING -> from = time.tomorrowStart();
            case OVERDUE -> overdueCutoff = now;
            default -> {
            }
        }

        int size = Math.min(Math.max(pageable.getPageSize(), 1), MAX_PAGE_SIZE);
        Page<Task> page = taskRepository.search(
                user.getId(),
                statuses.stream().map(Enum::name).toList(),
                taskListId,
                priority != null ? priority.name() : null,
                from, to, overdueCutoff, todayStart,
                effectiveView == TaskView.COMPLETED,
                PageRequest.of(pageable.getPageNumber(), size));
        return PageResponse.of(page.map(this::toResponse));
    }

    public TaskResponse create(TaskCreateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        TaskList list = resolveList(user.getId(), request.getTaskListId());

        Task task = new Task();
        task.setUser(user);
        task.setList(list);
        applyUserFields(request.getTitle(), request.getDescription(), request.getPriority(), request.getDueDate(),
                request.getDueTime(), request.getStartAt(), request.getEndAt(), request.getReminderMode(), task);

        TaskStatus status = request.getStatus() != null ? request.getStatus() : TaskStatus.TODO;
        task.setStatus(status);
        if (status == TaskStatus.COMPLETED) {
            task.setCompletedAt(time.now());
        } else {
            task.setCompletedAt(null);
        }

        Task saved = taskRepository.save(task);
        reconcileTaskReminders(user, saved);
        return toResponse(saved);
    }

    public TaskResponse update(UUID taskId, TaskUpdateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Task task = getOwned(taskId, user.getId());
        TaskList list = resolveList(user.getId(), request.getTaskListId());

        task.setList(list);
        applyUserFields(request.getTitle(), request.getDescription(), request.getPriority(), request.getDueDate(),
                request.getDueTime(), request.getStartAt(), request.getEndAt(), request.getReminderMode(), task);
        if (request.getStatus() != null) {
            task.changeStatus(request.getStatus(), time.now());
        }
        Task saved = taskRepository.save(task);
        reconcileTaskReminders(user, saved);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public TaskResponse get(UUID taskId) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(taskId, user.getId()));
    }

    public void delete(UUID taskId) {
        User user = currentUserProvider.getCurrentUser();
        Task task = getOwned(taskId, user.getId());
        reminderService.cancelTaskReminders(user.getId(), taskId);
        taskRepository.delete(task);
    }

    public TaskResponse complete(UUID taskId) {
        return stateAction(taskId, TaskStatus.COMPLETED);
    }

    public TaskResponse reopen(UUID taskId) {
        return stateAction(taskId, TaskStatus.TODO);
    }

    public TaskResponse cancel(UUID taskId) {
        return stateAction(taskId, TaskStatus.CANCELLED);
    }

    /**
     * Planner-owned "today" aggregation used by the Today endpoint.
     */
    @Transactional(readOnly = true)
    public List<TaskResponse> overdueForToday(UUID userId) {
        return taskRepository.findOverdue(userId, ACTIVE_STATUSES, time.todayStart(), time.now())
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<TaskResponse> dueToday(UUID userId) {
        return taskRepository.findDueToday(userId, ACTIVE_STATUSES, time.todayStart(), time.tomorrowStart())
                .stream().map(this::toResponse).toList();
    }

    /**
     * Tasks due inside an explicit calendar window. Ownership is enforced by
     * the caller-supplied user id (always from the security context).
     */
    @Transactional(readOnly = true)
    public List<TaskResponse> dueInRange(UUID userId, OffsetDateTime startInclusive, OffsetDateTime endExclusive) {
        return taskRepository.findDueInRange(userId, ACTIVE_STATUSES, startInclusive, endExclusive)
                .stream().map(this::toResponse).toList();
    }

    private TaskResponse stateAction(UUID taskId, TaskStatus target) {
        User user = currentUserProvider.getCurrentUser();
        Task task = getOwned(taskId, user.getId());
        task.changeStatus(target, time.now());
        Task saved = taskRepository.save(task);
        reconcileTaskReminders(user, saved);
        return toResponse(saved);
    }

    private void applyUserFields(String title, String description, TaskPriority priority,
                                 java.time.LocalDate dueDate, java.time.LocalTime dueTime,
                                 OffsetDateTime startAt, OffsetDateTime endAt,
                                 TaskReminderMode reminderMode, Task task) {
        if (endAt != null && (startAt == null || !endAt.isAfter(startAt))) {
            throw new BadRequestException("End time must be after the start time");
        }
        TaskReminderMode mode = reminderMode == null ? TaskReminderMode.NONE : reminderMode;
        if (mode == TaskReminderMode.AT_START && startAt == null) {
            throw new BadRequestException("A start time is required for this reminder");
        }
        if ((mode == TaskReminderMode.AT_END || mode == TaskReminderMode.AT_START_AND_END)
                && endAt == null) {
            throw new BadRequestException("An end time is required for this reminder");
        }
        task.setTitle(title);
        task.setDescription(description);
        task.setPriority(priority != null ? priority : TaskPriority.MEDIUM);
        task.setDueDate(dueDate);
        task.setDueTime(dueTime);
        task.setDueAt(time.resolveDueAt(dueDate, dueTime));
        task.setStartAt(startAt);
        task.setEndAt(endAt);
        task.setReminderMode(mode);
    }

    private void reconcileTaskReminders(User user, Task task) {
        if (!task.isActive()) {
            reminderService.cancelTaskReminders(user.getId(), task.getId());
            return;
        }
        reminderService.reconcileTaskReminders(
                user,
                task.getId(),
                task.getTitle(),
                time.userZone().getId(),
                task.getStartAt(),
                task.getEndAt(),
                task.getReminderMode().name());
    }

    private Task getOwned(UUID id, UUID userId) {
        return taskRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Task not found"));
    }

    private TaskList resolveList(UUID userId, UUID listId) {
        if (listId == null) {
            return null;
        }
        return taskListRepository.findByIdAndUserId(listId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Task list not found"));
    }

    private TaskResponse toResponse(Task task) {
        TaskList list = task.getList();
        return TaskResponse.builder()
                .id(task.getId())
                .title(task.getTitle())
                .description(task.getDescription())
                .status(task.getStatus())
                .priority(task.getPriority())
                .dueDate(task.getDueDate())
                .dueTime(task.getDueTime())
                .dueAt(task.getDueAt())
                .startAt(task.getStartAt())
                .endAt(task.getEndAt())
                .reminderMode(task.getReminderMode())
                .completedAt(task.getCompletedAt())
                .taskListId(list != null ? list.getId() : null)
                .taskListName(list != null ? list.getName() : null)
                .overdue(isOverdue(task))
                .createdAt(task.getCreatedAt())
                .updatedAt(task.getUpdatedAt())
                .build();
    }

    private boolean isOverdue(Task task) {
        if (!task.isActive() || task.getDueAt() == null) {
            return false;
        }
        boolean beforeToday = task.getDueAt().isBefore(time.todayStart());
        boolean dueEarlierToday = task.getDueTime() != null && task.getDueAt().isBefore(time.now());
        return beforeToday || dueEarlierToday;
    }

}