package com.blistra.planner;

import com.blistra.planner.dto.TaskCreateRequest;
import com.blistra.planner.dto.TaskUpdateRequest;
import com.blistra.planner.domain.TaskPriority;
import com.blistra.planner.domain.TaskReminderMode;
import com.blistra.planner.domain.TaskStatus;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlannerTaskIntegrationTest extends PlannerTestSupport {

    private static final ZoneId USER_ZONE = ZoneId.of("Asia/Kolkata");

    private LocalDate today() {
        return LocalDate.now(USER_ZONE);
    }

    private JsonNode createTask(String token, TaskCreateRequest request) throws Exception {
        MvcResult result = mockMvc.perform(post(TASKS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return body(result);
    }

    @Test
    void createTaskAppliesDefaults() throws Exception {
        String token = registerAndLogin("planner-one@blistra.com", "password123");
        JsonNode created = createTask(token, TaskCreateRequest.builder().title("Write report").build());

        assertThat(created.path("id").asText()).isNotEmpty();
        assertThat(created.path("title").asText()).isEqualTo("Write report");
        assertThat(created.path("status").asText()).isEqualTo("TODO");
        assertThat(created.path("priority").asText()).isEqualTo("MEDIUM");
        assertThat(created.path("taskListId").isNull()).isTrue();
        assertThat(created.path("taskListName").isNull()).isTrue();
        assertThat(created.path("overdue").asBoolean()).isFalse();
        assertThat(created.path("createdAt").asText()).isNotEmpty();
    }

    @Test
    void taskSupportsScheduledBlockAndReminders() throws Exception {
        String token = registerAndLogin("planner-scheduled@blistra.com", "password123");
        OffsetDateTime start = OffsetDateTime.now(USER_ZONE).plusDays(1).withHour(10).withMinute(0).withSecond(0).withNano(0);
        OffsetDateTime end = start.plusHours(1);
        JsonNode created = createTask(token, TaskCreateRequest.builder()
                .title("Finish report")
                .startAt(start)
                .endAt(end)
                .reminderMode(TaskReminderMode.AT_START_AND_END)
                .build());
        assertThat(created.path("startAt").asText()).isNotEmpty();
        assertThat(created.path("endAt").asText()).isNotEmpty();
        assertThat(created.path("reminderMode").asText()).isEqualTo("AT_START_AND_END");
        assertThat(reminderRepository.findByUserIdOrderByScheduledAtAsc(
                userRepository.findByEmail("planner-scheduled@blistra.com").orElseThrow().getId())).hasSize(2);
    }

    @Test
    void taskRejectsEndBeforeStartAndInvalidReminder() throws Exception {
        String token = registerAndLogin("planner-invalid@blistra.com", "password123");
        OffsetDateTime now = OffsetDateTime.now(USER_ZONE).plusDays(1);
        mockMvc.perform(post(TASKS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(TaskCreateRequest.builder()
                                .title("Bad block")
                                .startAt(now.plusHours(1))
                                .endAt(now)
                                .reminderMode(TaskReminderMode.AT_END)
                                .build())))
                .andExpect(status().isBadRequest());
    }

    @Test
    void createTaskWithListAssignsList() throws Exception {
        String token = registerAndLogin("planner-two@blistra.com", "password123");
        JsonNode list = createList(token, "Work");

        JsonNode created = createTask(token, TaskCreateRequest.builder()
                .title("Sync with team")
                .taskListId(UUID(list.path("id").asText()))
                .build());

        assertThat(created.path("taskListId").asText()).isEqualTo(list.path("id").asText());
        assertThat(created.path("taskListName").asText()).isEqualTo("Work");
    }

    @Test
    void createCompletedTaskRecordsCompletedAt() throws Exception {
        String token = registerAndLogin("planner-three@blistra.com", "password123");
        JsonNode created = createTask(token, TaskCreateRequest.builder()
                .title("Already done")
                .status(TaskStatus.COMPLETED)
                .build());

        assertThat(created.path("status").asText()).isEqualTo("COMPLETED");
        assertThat(created.path("completedAt").asText()).isNotEmpty();
    }

    @Test
    void getOwnTaskReturnsIt() throws Exception {
        String token = registerAndLogin("planner-four@blistra.com", "password123");
        String id = createTask(token, TaskCreateRequest.builder().title("Read chapter").build())
                .path("id").asText();

        mockMvc.perform(get(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Read chapter"));
    }

    @Test
    void getOtherUsersTaskIsNotFound() throws Exception {
        String ownerToken = registerAndLogin("planner-owner@blistra.com", "password123");
        String otherToken = registerAndLogin("planner-eavesdrop@blistra.com", "password123");
        String id = createTask(ownerToken, TaskCreateRequest.builder().title("Private").build())
                .path("id").asText();

        mockMvc.perform(get(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(otherToken)))
                .andExpect(status().isNotFound());
    }

    @Test
    void updateReplacesFieldsAndAssignment() throws Exception {
        String token = registerAndLogin("planner-five@blistra.com", "password123");
        JsonNode list = createList(token, "Study");
        String id = createTask(token, TaskCreateRequest.builder().title("Old").build())
                .path("id").asText();

        TaskUpdateRequest update = TaskUpdateRequest.builder()
                .title("New")
                .description("Changed description")
                .priority(TaskPriority.HIGH)
                .dueDate(today())
                .dueTime(LocalTime.of(9, 0))
                .taskListId(UUID(list.path("id").asText()))
                .build();

        JsonNode updated = body(mockMvc.perform(put(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(updated.path("title").asText()).isEqualTo("New");
        assertThat(updated.path("description").asText()).isEqualTo("Changed description");
        assertThat(updated.path("priority").asText()).isEqualTo("HIGH");
        assertThat(updated.path("dueDate").asText()).isEqualTo(today().toString());
        assertThat(updated.path("taskListId").asText()).isEqualTo(list.path("id").asText());
    }

    @Test
    void updateUnassignsTaskFromList() throws Exception {
        String token = registerAndLogin("planner-six@blistra.com", "password123");
        JsonNode list = createList(token, "Someday");
        String id = createTask(token, TaskCreateRequest.builder()
                .title("In list")
                .taskListId(UUID(list.path("id").asText()))
                .build()).path("id").asText();

        TaskUpdateRequest update = TaskUpdateRequest.builder().title("In list").build();

        JsonNode updated = body(mockMvc.perform(put(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(updated.path("taskListId").isNull()).isTrue();
    }

    @Test
    void updateWithOtherUsersListIsNotFound() throws Exception {
        String token = registerAndLogin("planner-seven@blistra.com", "password123");
        String otherToken = registerAndLogin("planner-eavesdrop-2@blistra.com", "password123");
        JsonNode othersList = createList(otherToken, "Not mine");
        String id = createTask(token, TaskCreateRequest.builder().title("Mine").build())
                .path("id").asText();

        TaskUpdateRequest update = TaskUpdateRequest.builder()
                .title("Mine")
                .taskListId(UUID(othersList.path("id").asText()))
                .build();

        mockMvc.perform(put(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isNotFound());
    }

    @Test
    void completeTodoTaskSetsCompletedAt() throws Exception {
        String token = registerAndLogin("planner-eight@blistra.com", "password123");
        String id = createTask(token, TaskCreateRequest.builder().title("Finish").build())
                .path("id").asText();

        JsonNode updated = body(mockMvc.perform(post(TASKS_URL + "/" + id + "/complete")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(updated.path("status").asText()).isEqualTo("COMPLETED");
        assertThat(updated.path("completedAt").asText()).isNotEmpty();
    }

    @Test
    void completeCompletedTaskIsNoOp() throws Exception {
        String token = registerAndLogin("planner-nine@blistra.com", "password123");
        String id = createTask(token, TaskCreateRequest.builder()
                .title("Done twice").status(TaskStatus.COMPLETED).build())
                .path("id").asText();

        mockMvc.perform(post(TASKS_URL + "/" + id + "/complete")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    @Test
    void completeCancelledTaskIsConflict() throws Exception {
        String token = registerAndLogin("planner-ten@blistra.com", "password123");
        String id = createTask(token, TaskCreateRequest.builder().title("Cancelled").build())
                .path("id").asText();
        mockMvc.perform(post(TASKS_URL + "/" + id + "/cancel")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk());

        mockMvc.perform(post(TASKS_URL + "/" + id + "/complete")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_STATE"));
    }

    @Test
    void reopenClearsCompletedAt() throws Exception {
        String token = registerAndLogin("planner-eleven@blistra.com", "password123");
        String id = createTask(token, TaskCreateRequest.builder()
                .title("Reopen me").status(TaskStatus.COMPLETED).build())
                .path("id").asText();

        JsonNode reopened = body(mockMvc.perform(post(TASKS_URL + "/" + id + "/reopen")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(reopened.path("status").asText()).isEqualTo("TODO");
        assertThat(reopened.path("completedAt").isNull()).isTrue();
    }

    @Test
    void updateWithInvalidTransitionIsConflict() throws Exception {
        String token = registerAndLogin("planner-twelve@blistra.com", "password123");
        String id = createTask(token, TaskCreateRequest.builder()
                .title("Cancel not allowed from COMPLETED").status(TaskStatus.COMPLETED).build())
                .path("id").asText();

        TaskUpdateRequest update = TaskUpdateRequest.builder()
                .title("Cancel not allowed from COMPLETED")
                .status(TaskStatus.CANCELLED)
                .build();

        mockMvc.perform(put(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isConflict());
    }

    @Test
    void listIsScopedToOwner() throws Exception {
        String token = registerAndLogin("planner-thirteen@blistra.com", "password123");
        String otherToken = registerAndLogin("planner-eavesdrop-3@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("Visible only to owner").build());
        createTask(otherToken, TaskCreateRequest.builder().title("Other user task").build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(1);
        assertThat(list.path("content").get(0).path("title").asText())
                .isEqualTo("Visible only to owner");
    }

    @Test
    void completedViewOrdersByCompletedAtDesc() throws Exception {
        String token = registerAndLogin("planner-fourteen@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("Older done").status(TaskStatus.COMPLETED).build());
        createTask(token, TaskCreateRequest.builder().title("Newer done").status(TaskStatus.COMPLETED).build());
        createTask(token, TaskCreateRequest.builder().title("Still active").build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL).param("view", "COMPLETED")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(2);
        assertThat(list.path("content").get(0).path("title").asText()).isEqualTo("Newer done");
        assertThat(list.path("content").get(0).path("completedAt").asText()).isNotEmpty();
    }

    @Test
    void activeViewExcludesDoneTasks() throws Exception {
        String token = registerAndLogin("planner-fifteen@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("Todo").build());
        createTask(token, TaskCreateRequest.builder().title("Doing").status(TaskStatus.IN_PROGRESS).build());
        createTask(token, TaskCreateRequest.builder().title("Done").status(TaskStatus.COMPLETED).build());
        createTask(token, TaskCreateRequest.builder().title("Skipped").status(TaskStatus.CANCELLED).build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL).param("view", "ACTIVE")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(2);
    }

    @Test
    void todayViewReturnsTasksDueToday() throws Exception {
        String token = registerAndLogin("planner-sixteen@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("Due today").dueDate(today()).build());
        createTask(token, TaskCreateRequest.builder().title("Due tomorrow").dueDate(today().plusDays(1)).build());
        createTask(token, TaskCreateRequest.builder().title("Due today but done").dueDate(today()).status(TaskStatus.COMPLETED).build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL).param("view", "TODAY")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(1);
        assertThat(list.path("content").get(0).path("title").asText()).isEqualTo("Due today");
    }

    @Test
    void overdueViewIncludesPassedDays() throws Exception {
        String token = registerAndLogin("planner-seventeen@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("All-day yesterday").dueDate(today().minusDays(1)).build());
        createTask(token, TaskCreateRequest.builder().title("Timed yesterday").dueDate(today().minusDays(1)).dueTime(LocalTime.of(9, 0)).build());
        createTask(token, TaskCreateRequest.builder().title("All-day today").dueDate(today()).build());
        createTask(token, TaskCreateRequest.builder().title("Cancelled overdue").dueDate(today().minusDays(2)).status(TaskStatus.CANCELLED).build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL).param("view", "OVERDUE")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(2);
    }

    @Test
    void upcomingViewExcludesToday() throws Exception {
        String token = registerAndLogin("planner-eighteen@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("Due today").dueDate(today()).build());
        createTask(token, TaskCreateRequest.builder().title("Due tomorrow").dueDate(today().plusDays(1)).build());
        createTask(token, TaskCreateRequest.builder().title("Due later").dueDate(today().plusDays(3)).build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL).param("view", "UPCOMING")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(2);
    }

    @Test
    void listFilteredByPriority() throws Exception {
        String token = registerAndLogin("planner-nineteen@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("Urgent").priority(TaskPriority.HIGH).build());
        createTask(token, TaskCreateRequest.builder().title("Not urgent").build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL).param("priority", "HIGH")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(1);
        assertThat(list.path("content").get(0).path("title").asText()).isEqualTo("Urgent");
    }

    @Test
    void listFilteredByTaskListId() throws Exception {
        String token = registerAndLogin("planner-twenty@blistra.com", "password123");
        JsonNode listA = createList(token, "A");
        JsonNode listB = createList(token, "B");
        createTask(token, TaskCreateRequest.builder().title("In A").taskListId(UUID(listA.path("id").asText())).build());
        createTask(token, TaskCreateRequest.builder().title("In B").taskListId(UUID(listB.path("id").asText())).build());
        createTask(token, TaskCreateRequest.builder().title("Unassigned").build());

        JsonNode list = body(mockMvc.perform(get(TASKS_URL).param("taskListId", listA.path("id").asText())
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(1);
        assertThat(list.path("content").get(0).path("title").asText()).isEqualTo("In A");
    }

    @Test
    void listIsPaginated() throws Exception {
        String token = registerAndLogin("planner-twenty-one@blistra.com", "password123");
        for (int i = 1; i <= 5; i++) {
            createTask(token, TaskCreateRequest.builder().title("Task " + i).build());
        }

        JsonNode page = body(mockMvc.perform(get(TASKS_URL).param("page", "0").param("size", "2")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(page.path("content").size()).isEqualTo(2);
        assertThat(page.path("totalElements").asLong()).isEqualTo(5);
        assertThat(page.path("page").asInt()).isZero();
        assertThat(page.path("size").asInt()).isEqualTo(2);
        assertThat(page.path("totalPages").asInt()).isEqualTo(3);
        assertThat(page.path("last").asBoolean()).isFalse();
    }

    @Test
    void deleteTaskRemovesIt() throws Exception {
        String token = registerAndLogin("planner-twenty-two@blistra.com", "password123");
        String id = createTask(token, TaskCreateRequest.builder().title("Disappear").build())
                .path("id").asText();

        mockMvc.perform(delete(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(TASKS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNotFound());
    }

    @Test
    void createTaskWithBlankTitleIsBadRequest() throws Exception {
        String token = registerAndLogin("planner-twenty-three@blistra.com", "password123");

        mockMvc.perform(post(TASKS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void invalidViewValueIsBadRequest() throws Exception {
        String token = registerAndLogin("planner-twenty-four@blistra.com", "password123");

        mockMvc.perform(get(TASKS_URL).param("view", "NOT_A_VIEW")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void createTaskWithOtherUsersListIsNotFound() throws Exception {
        String token = registerAndLogin("planner-twenty-five@blistra.com", "password123");
        String otherToken = registerAndLogin("planner-eavesdrop-4@blistra.com", "password123");
        JsonNode othersList = createList(otherToken, "Their list");

        mockMvc.perform(post(TASKS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(TaskCreateRequest.builder()
                                .title("Hijacked")
                                .taskListId(UUID(othersList.path("id").asText()))
                                .build())))
                .andExpect(status().isNotFound());
    }

    private JsonNode createList(String token, String name) throws Exception {
        MvcResult result = mockMvc.perform(post(LISTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"" + name + "\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return body(result);
    }

    private java.util.UUID UUID(String value) {
        return java.util.UUID.fromString(value);
    }
}