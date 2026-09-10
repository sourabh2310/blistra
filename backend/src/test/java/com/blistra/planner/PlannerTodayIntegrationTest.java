package com.blistra.planner;

import com.blistra.planner.dto.EventCreateRequest;
import com.blistra.planner.dto.TaskCreateRequest;
import com.blistra.planner.domain.EventStatus;
import com.blistra.planner.domain.TaskStatus;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import tools.jackson.databind.JsonNode;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlannerTodayIntegrationTest extends PlannerTestSupport {

    private static final ZoneId USER_ZONE = ZoneId.of("Asia/Kolkata");

    private LocalDate today() {
        return LocalDate.now(USER_ZONE);
    }

    private void createTask(String token, TaskCreateRequest request) throws Exception {
        mockMvc.perform(post(TASKS_URL).header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private void createEvent(String token, EventCreateRequest request) throws Exception {
        mockMvc.perform(post(EVENTS_URL).header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private EventCreateRequest eventRequest(String title, java.time.LocalDate on) {
        OffsetDateTime start = ZonedDateTime.of(on.atTime(10, 0), USER_ZONE).toOffsetDateTime();
        return EventCreateRequest.builder()
                .title(title)
                .startAt(start)
                .endAt(start.plusHours(1))
                .build();
    }

    @Test
    void todayReturnsEmptyForFreshUser() throws Exception {
        String token = registerAndLogin("today-empty@blistra.com", "password123");

        JsonNode today = body(mockMvc.perform(get(TODAY_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(today.path("overdueTasks").size()).isZero();
        assertThat(today.path("todayTasks").size()).isZero();
        assertThat(today.path("todayEvents").size()).isZero();
    }

    @Test
    void todayAggregatesOverdueDueTasksAndEvents() throws Exception {
        String token = registerAndLogin("today-full@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder().title("Overdue one").dueDate(today().minusDays(1)).build());
        createTask(token, TaskCreateRequest.builder().title("Due today").dueDate(today()).build());
        createTask(token, TaskCreateRequest.builder().title("Due tomorrow").dueDate(today().plusDays(1)).build());
        createEvent(token, eventRequest("Today meeting", today()));
        createEvent(token, eventRequest("Tomorrow meeting", today().plusDays(1)));

        JsonNode today = body(mockMvc.perform(get(TODAY_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(today.path("overdueTasks").size()).isEqualTo(1);
        assertThat(today.path("overdueTasks").get(0).path("title").asText()).isEqualTo("Overdue one");
        assertThat(today.path("overdueTasks").get(0).path("overdue").asBoolean()).isTrue();

        assertThat(today.path("todayTasks").size()).isEqualTo(1);
        assertThat(today.path("todayTasks").get(0).path("title").asText()).isEqualTo("Due today");

        assertThat(today.path("todayEvents").size()).isEqualTo(1);
        assertThat(today.path("todayEvents").get(0).path("title").asText()).isEqualTo("Today meeting");
    }

    @Test
    void todayExcludesDoneAndCancelled() throws Exception {
        String token = registerAndLogin("today-filtered@blistra.com", "password123");
        createTask(token, TaskCreateRequest.builder()
                .title("Completed today").dueDate(today()).status(TaskStatus.COMPLETED).build());
        createTask(token, TaskCreateRequest.builder()
                .title("Cancelled overdue").dueDate(today().minusDays(2)).status(TaskStatus.CANCELLED).build());

        EventCreateRequest cancelled = eventRequest("Cancelled today", today());
        cancelled.setStatus(EventStatus.CANCELLED);
        createEvent(token, cancelled);

        JsonNode today = body(mockMvc.perform(get(TODAY_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(today.path("overdueTasks").size()).isZero();
        assertThat(today.path("todayTasks").size()).isZero();
        assertThat(today.path("todayEvents").size()).isZero();
    }

    @Test
    void todayIsScopedToOwner() throws Exception {
        String token = registerAndLogin("today-owner@blistra.com", "password123");
        String otherToken = registerAndLogin("today-other@blistra.com", "password123");
        createTask(otherToken, TaskCreateRequest.builder().title("Other's overdue").dueDate(today().minusDays(1)).build());
        createEvent(otherToken, eventRequest("Other's meeting", today()));

        JsonNode today = body(mockMvc.perform(get(TODAY_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(today.path("overdueTasks").size()).isZero();
        assertThat(today.path("todayEvents").size()).isZero();
    }
}