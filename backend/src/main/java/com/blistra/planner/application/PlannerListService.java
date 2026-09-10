package com.blistra.planner.application;

import com.blistra.common.exception.ResourceAlreadyExistsException;
import com.blistra.common.exception.ResourceNotFoundException;
import com.blistra.planner.domain.TaskList;
import com.blistra.planner.dto.TaskListCreateRequest;
import com.blistra.planner.dto.TaskListResponse;
import com.blistra.planner.dto.TaskListUpdateRequest;
import com.blistra.planner.repository.TaskListRepository;
import com.blistra.planner.repository.TaskRepository;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.domain.User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@Transactional
public class PlannerListService {

    private final TaskListRepository taskListRepository;
    private final TaskRepository taskRepository;
    private final CurrentUserProvider currentUserProvider;

    public PlannerListService(TaskListRepository taskListRepository,
                              TaskRepository taskRepository,
                              CurrentUserProvider currentUserProvider) {
        this.taskListRepository = taskListRepository;
        this.taskRepository = taskRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Transactional(readOnly = true)
    public List<TaskListResponse> list() {
        User user = currentUserProvider.getCurrentUser();
        return taskListRepository.findByUserIdOrderByCreatedAtAsc(user.getId())
                .stream().map(this::toResponse).toList();
    }

    public TaskListResponse create(TaskListCreateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        String name = request.getName().trim();
        if (taskListRepository.existsByUserIdAndName(user.getId(), name)) {
            throw new ResourceAlreadyExistsException("A task list with this name already exists");
        }

        TaskList list = new TaskList();
        list.setUser(user);
        list.setName(name);
        list.setDescription(request.getDescription());
        return toResponse(taskListRepository.save(list));
    }

    public TaskListResponse update(UUID listId, TaskListUpdateRequest request) {
        User user = currentUserProvider.getCurrentUser();
        TaskList list = getOwned(listId, user.getId());
        String name = request.getName().trim();
        if (!name.equals(list.getName()) && taskListRepository.existsByUserIdAndName(user.getId(), name)) {
            throw new ResourceAlreadyExistsException("A task list with this name already exists");
        }
        list.setName(name);
        list.setDescription(request.getDescription());
        return toResponse(taskListRepository.save(list));
    }

    @Transactional(readOnly = true)
    public TaskListResponse get(UUID listId) {
        User user = currentUserProvider.getCurrentUser();
        return toResponse(getOwned(listId, user.getId()));
    }

    public void delete(UUID listId) {
        User user = currentUserProvider.getCurrentUser();
        TaskList list = getOwned(listId, user.getId());
        taskRepository.detachList(user.getId(), list.getId());
        taskListRepository.delete(list);
    }

    private TaskList getOwned(UUID id, UUID userId) {
        return taskListRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Task list not found"));
    }

    private TaskListResponse toResponse(TaskList list) {
        return TaskListResponse.builder()
                .id(list.getId())
                .name(list.getName())
                .description(list.getDescription())
                .taskCount(taskRepository.countByUserIdAndListId(list.getUser().getId(), list.getId()))
                .createdAt(list.getCreatedAt())
                .updatedAt(list.getUpdatedAt())
                .build();
    }
}