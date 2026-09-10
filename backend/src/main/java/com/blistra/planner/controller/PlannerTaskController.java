package com.blistra.planner.controller;

import com.blistra.planner.application.PlannerTaskService;
import com.blistra.planner.domain.TaskPriority;
import com.blistra.planner.dto.PageResponse;
import com.blistra.planner.dto.TaskCreateRequest;
import com.blistra.planner.dto.TaskResponse;
import com.blistra.planner.dto.TaskUpdateRequest;
import com.blistra.planner.dto.TaskView;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/planner/tasks")
@Tag(name = "Planner Tasks", description = "Personal tasks owned by the Planner module")
public class PlannerTaskController {

    private final PlannerTaskService taskService;

    public PlannerTaskController(PlannerTaskService taskService) {
        this.taskService = taskService;
    }

    @GetMapping
    @Operation(summary = "List the current user's tasks with filtering and pagination",
            description = "Supported views: ALL, ACTIVE, COMPLETED, TODAY, OVERDUE, UPCOMING. Optionally filter by list and priority.")
    public ResponseEntity<PageResponse<TaskResponse>> list(
            @RequestParam(defaultValue = "ALL") TaskView view,
            @RequestParam(required = false) UUID taskListId,
            @RequestParam(required = false) TaskPriority priority,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(taskService.list(view, taskListId, priority, pageable));
    }

    @PostMapping
    @Operation(summary = "Create a task for the current user")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Task created"),
            @ApiResponse(responseCode = "400", description = "Invalid request"),
            @ApiResponse(responseCode = "404", description = "Referenced task list not found")
    })
    public ResponseEntity<TaskResponse> create(@Valid @RequestBody TaskCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(taskService.create(request));
    }

    @GetMapping("/{taskId}")
    @Operation(summary = "Get one of the current user's tasks")
    public ResponseEntity<TaskResponse> get(@PathVariable UUID taskId) {
        return ResponseEntity.ok(taskService.get(taskId));
    }

    @PutMapping("/{taskId}")
    @Operation(summary = "Update one of the current user's tasks")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "Task updated"),
            @ApiResponse(responseCode = "400", description = "Invalid request"),
            @ApiResponse(responseCode = "404", description = "Task or referenced list not found"),
            @ApiResponse(responseCode = "409", description = "Status transition not allowed")
    })
    public ResponseEntity<TaskResponse> update(@PathVariable UUID taskId,
                                               @Valid @RequestBody TaskUpdateRequest request) {
        return ResponseEntity.ok(taskService.update(taskId, request));
    }

    @DeleteMapping("/{taskId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's tasks")
    public void delete(@PathVariable UUID taskId) {
        taskService.delete(taskId);
    }

    @PostMapping("/{taskId}/complete")
    @Operation(summary = "Complete one of the current user's tasks")
    public ResponseEntity<TaskResponse> complete(@PathVariable UUID taskId) {
        return ResponseEntity.ok(taskService.complete(taskId));
    }

    @PostMapping("/{taskId}/reopen")
    @Operation(summary = "Reopen a completed or cancelled task")
    public ResponseEntity<TaskResponse> reopen(@PathVariable UUID taskId) {
        return ResponseEntity.ok(taskService.reopen(taskId));
    }

    @PostMapping("/{taskId}/cancel")
    @Operation(summary = "Cancel one of the current user's tasks")
    public ResponseEntity<TaskResponse> cancel(@PathVariable UUID taskId) {
        return ResponseEntity.ok(taskService.cancel(taskId));
    }
}