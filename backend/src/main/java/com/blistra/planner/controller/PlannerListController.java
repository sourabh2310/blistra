package com.blistra.planner.controller;

import com.blistra.planner.application.PlannerListService;
import com.blistra.planner.dto.TaskListCreateRequest;
import com.blistra.planner.dto.TaskListResponse;
import com.blistra.planner.dto.TaskListUpdateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/planner/lists")
@Tag(name = "Planner Task Lists", description = "User-owned task lists/categories used to organise tasks")
public class PlannerListController {

    private final PlannerListService listService;

    public PlannerListController(PlannerListService listService) {
        this.listService = listService;
    }

    @GetMapping
    @Operation(summary = "List the current user's task lists")
    public ResponseEntity<List<TaskListResponse>> list() {
        return ResponseEntity.ok(listService.list());
    }

    @PostMapping
    @Operation(summary = "Create a task list")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "201", description = "Task list created"),
            @ApiResponse(responseCode = "400", description = "Invalid request"),
            @ApiResponse(responseCode = "409", description = "A task list with this name already exists")
    })
    public ResponseEntity<TaskListResponse> create(@Valid @RequestBody TaskListCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(listService.create(request));
    }

    @GetMapping("/{listId}")
    @Operation(summary = "Get one of the current user's task lists")
    public ResponseEntity<TaskListResponse> get(@PathVariable UUID listId) {
        return ResponseEntity.ok(listService.get(listId));
    }

    @PutMapping("/{listId}")
    @Operation(summary = "Update one of the current user's task lists")
    public ResponseEntity<TaskListResponse> update(@PathVariable UUID listId,
                                                   @Valid @RequestBody TaskListUpdateRequest request) {
        return ResponseEntity.ok(listService.update(listId, request));
    }

    @DeleteMapping("/{listId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete one of the current user's task lists",
            description = "Tasks in the list are unassigned but not deleted")
    public void delete(@PathVariable UUID listId) {
        listService.delete(listId);
    }
}