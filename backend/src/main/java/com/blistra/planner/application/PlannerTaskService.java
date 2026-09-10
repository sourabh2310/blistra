package com.blistra.planner.application;

import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.planner.domain.Task;
import com.blistra.planner.domain.TaskList;
import com.blistra.planner.domain.TaskPriority;
import com.blistra.planner.domain.TaskStatus;
import com.blistra.planner.dto.PageResponse;
import com.blistra.planner.dto.TaskCreateRequest;
import com.blistra.planner.dto.TaskResponse;
import com.blistra.planner.dto.TaskUpdateRequest;
import com.blistra.planner.dto.TaskView;
import com.blistra.planner.repository.TaskListRepository;
import com.blistra.planner.repository.TaskRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
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

    public PlannerTaskService(TaskRepository taskRepository,
                              TaskListRepository taskListRepository,
                              CurrentUserProvider currentUserProvider,
                              PlannerTime time) {
        this.taskRepository = taskRepository;
        this.taskListRepository = taskListRepository;
        this.currentUserProvider = currentUserProvider;
        this.time = time;
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

        Pageable safePageable = safePageable(pageable, effectiveView);
        Page<Task> page = taskRepository.search(
                user.getId(), statuses, taskListId, priority, from, to, overdueCutoff, todayStart, safePageable);
        return PageResponse.of(page.map(this::toResponse));
    }

    public TaskResponse create(TaskCreateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        TaskList list = resolveList(user.getId(), request.getTaskListId());

        Task task = new Task();
        task.setUser(user);
        task.setList(list);
        applyUserFields(request.getTitle(), request.getDescription(), request.getPriority(), request.getDueDate(),
                request.getDueTime(), task);

        TaskStatus status = request.getStatus() != null ? request.getStatus() : TaskStatus.TODO;
        task.setStatus(status);
        if (status == TaskStatus.COMPLETED) {
            task.setCompletedAt(time.now());
        } else {
            task.setCompletedAt(null);
        }

        return toResponse(taskRepository.save(task));
    }

    public TaskResponse update(UUID taskId, TaskUpdateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        Task task = getOwned(taskId, user.getId());
        TaskList list = resolveList(user.getId(), request.getTaskListId());

        task.setList(list);
        applyUserFields(request.getTitle(), request.getDescription(), request.getPriority(), request.getDueDate(),
                request.getDueTime(), task);
        if (request.getStatus() != null) {
            task.changeStatus(request.getStatus(), time.now());
        }
        return toResponse(taskRepository.save(task));
    }

    @Transactional(readOnly = true)
    public TaskResponse get(UUID taskId) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(taskId, user.getId()));
    }

    public void delete(UUID taskId) {
        User user = currentUserProvider.getCurrentUser();
        Task task = getOwned(taskId, user.getId());
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

    private TaskResponse stateAction(UUID taskId, TaskStatus target) {
        User user = currentUserProvider.getCurrentUser();
        Task task = getOwned(taskId, user.getId());
        task.changeStatus(target, time.now());
        return toResponse(taskRepository.save(task));
    }

    private void applyUserFields(String title, String description, TaskPriority priority,
                                 java.time.LocalDate dueDate, java.time.LocalTime dueTime, Task task) {
        task.setTitle(title);
        task.setDescription(description);
        task.setPriority(priority != null ? priority : TaskPriority.MEDIUM);
        task.setDueDate(dueDate);
        task.setDueTime(dueTime);
        task.setDueAt(time.resolveDueAt(dueDate, dueTime));
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

    private Pageable safePageable(Pageable pageable, TaskView view) {
        int size = Math.min(Math.max(pageable.getPageSize(), 1), MAX_PAGE_SIZE);
        Sort sort = pageable.getSort().isSorted()
                ? pageable.getSort()
                : defaultSort(view);
        return PageRequest.of(pageable.getPageNumber(), size, sort);
    }

    private Sort defaultSort(TaskView view) {
        if (view == TaskView.COMPLETED) {
            return Sort.by(Sort.Order.desc("completedAt").nullsLast());
        }
        return Sort.by(Sort.Order.asc("dueAt").nullsLast(), Sort.Order.desc("createdAt"));
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