package com.blistra.planner;

import com.blistra.planner.dto.TaskCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlannerListIntegrationTest extends PlannerTestSupport {

    @Test
    void createListAndGetIt() throws Exception {
        String token = registerAndLogin("planner-list-1@blistra.com", "password123");
        JsonNode created = createList(token, "Work", "Work-related tasks");

        assertThat(created.path("id").asText()).isNotEmpty();
        assertThat(created.path("name").asText()).isEqualTo("Work");
        assertThat(created.path("description").asText()).isEqualTo("Work-related tasks");
        assertThat(created.path("taskCount").asLong()).isZero();

        mockMvc.perform(get(LISTS_URL + "/" + created.path("id").asText())
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Work"));
    }

    @Test
    void createDuplicateNameIsConflict() throws Exception {
        String token = registerAndLogin("planner-list-2@blistra.com", "password123");
        createList(token, "Work", null);

        mockMvc.perform(post(LISTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Work\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("RESOURCE_ALREADY_EXISTS"));
    }

    @Test
    void listListsOnlyOwnLists() throws Exception {
        String token = registerAndLogin("planner-list-3@blistra.com", "password123");
        String otherToken = registerAndLogin("planner-list-3-other@blistra.com", "password123");
        createList(token, "Mine", null);
        createList(otherToken, "Not mine", null);

        JsonNode lists = body(mockMvc.perform(get(LISTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(lists.size()).isEqualTo(1);
        assertThat(lists.get(0).path("name").asText()).isEqualTo("Mine");
    }

    @Test
    void updateList() throws Exception {
        String token = registerAndLogin("planner-list-4@blistra.com", "password123");
        String id = createList(token, "Old", null).path("id").asText();

        JsonNode updated = body(mockMvc.perform(put(LISTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"New\",\"description\":\"Renamed\"}"))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(updated.path("name").asText()).isEqualTo("New");
        assertThat(updated.path("description").asText()).isEqualTo("Renamed");
    }

    @Test
    void updateOntoAnotherOwnedNameIsConflict() throws Exception {
        String token = registerAndLogin("planner-list-5@blistra.com", "password123");
        createList(token, "A", null);
        String id = createList(token, "B", null).path("id").asText();

        mockMvc.perform(put(LISTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"A\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void getOtherUsersListIsNotFound() throws Exception {
        String token = registerAndLogin("planner-list-6@blistra.com", "password123");
        String otherToken = registerAndLogin("planner-list-6-other@blistra.com", "password123");
        String id = createList(otherToken, "Private", null).path("id").asText();

        mockMvc.perform(get(LISTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNotFound());
    }

    @Test
    void deleteListUnassignsItsTasksButKeepsThem() throws Exception {
        String token = registerAndLogin("planner-list-7@blistra.com", "password123");
        JsonNode list = createList(token, "Doomed", null);
        createList(token, "Survivor", null);
        String taskId = createTask(token, TaskCreateRequest.builder()
                .title("Moves out")
                .taskListId(UUID.fromString(list.path("id").asText()))
                .build()).path("id").asText();

        mockMvc.perform(delete(LISTS_URL + "/" + list.path("id").asText())
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNoContent());

        JsonNode task = body(mockMvc.perform(get(TASKS_URL + "/" + taskId)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(task.path("taskListId").isNull()).isTrue();
        assertThat(task.path("title").asText()).isEqualTo("Moves out");

        JsonNode lists = body(mockMvc.perform(get(LISTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(lists.size()).isEqualTo(1);
        assertThat(lists.get(0).path("name").asText()).isEqualTo("Survivor");
    }

    @Test
    void taskCountReflectsAssignments() throws Exception {
        String token = registerAndLogin("planner-list-8@blistra.com", "password123");
        JsonNode list = createList(token, "Counted", null);
        createTask(token, TaskCreateRequest.builder()
                .title("One").taskListId(UUID.fromString(list.path("id").asText())).build());
        createTask(token, TaskCreateRequest.builder()
                .title("Two").taskListId(UUID.fromString(list.path("id").asText())).build());

        JsonNode lists = body(mockMvc.perform(get(LISTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(lists.get(0).path("taskCount").asLong()).isEqualTo(2);
    }

    @Test
    void createListWithBlankNameIsBadRequest() throws Exception {
        String token = registerAndLogin("planner-list-9@blistra.com", "password123");

        mockMvc.perform(post(LISTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest());
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

    private JsonNode createList(String token, String name, String description) throws Exception {
        String payload = "{\"name\":\"" + name + "\""
                + (description == null ? "" : ",\"description\":\"" + description + "\"")
                + "}";
        MvcResult result = mockMvc.perform(post(LISTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andReturn();
        return body(result);
    }
}