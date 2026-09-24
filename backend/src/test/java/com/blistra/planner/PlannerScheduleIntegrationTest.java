package com.blistra.planner;

import com.blistra.planner.dto.EventCreateRequest;
import com.blistra.planner.dto.TaskCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlannerScheduleIntegrationTest extends PlannerTestSupport {

    private static final ZoneId USER_ZONE = ZoneId.of("Asia/Kolkata");
    private static final String SCHEDULE_URL = "/api/v1/planner/schedule";

    private LocalDate today() {
        return LocalDate.now(USER_ZONE);
    }

    private void createTask(String token, TaskCreateRequest request) throws Exception {
        mockMvc.perform(post(TASKS_URL).header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private String createEvent(String token, EventCreateRequest request) throws Exception {
        MvcResult result = mockMvc.perform(post(EVENTS_URL).header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return body(result).path("id").asText();
    }

    private EventCreateRequest eventRequest(String title, LocalDate on) {
        OffsetDateTime start = ZonedDateTime.of(on.atTime(10, 0), USER_ZONE).toOffsetDateTime();
        return EventCreateRequest.builder()
                .title(title)
                .startAt(start)
                .endAt(start.plusHours(1))
                .build();
    }

    @Test
    void scheduleDefaultsToToday() throws Exception {
        String token = registerAndLogin("sched-1@blistra.com", "password123");
        createEvent(token, eventRequest("Today sync", today()));
        createEvent(token, eventRequest("Tomorrow sync", today().plusDays(1)));

        JsonNode schedule = body(mockMvc.perform(get(SCHEDULE_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(schedule.path("date").asText()).isEqualTo(today().toString());
        assertThat(schedule.path("days").asInt()).isEqualTo(1);
        assertThat(schedule.path("events").size()).isEqualTo(1);
        assertThat(schedule.path("events").get(0).path("title").asText()).isEqualTo("Today sync");
    }

    @Test
    void scheduleDateNavigationLoadsOtherDay() throws Exception {
        String token = registerAndLogin("sched-2@blistra.com", "password123");
        createEvent(token, eventRequest("Today sync", today()));
        createEvent(token, eventRequest("Tomorrow sync", today().plusDays(1)));

        JsonNode schedule = body(mockMvc.perform(get(SCHEDULE_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .param("date", today().plusDays(1).toString()))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(schedule.path("events").size()).isEqualTo(1);
        assertThat(schedule.path("events").get(0).path("title").asText()).isEqualTo("Tomorrow sync");
    }

    @Test
    void scheduleWeekViewSpansSevenDays() throws Exception {
        String token = registerAndLogin("sched-3@blistra.com", "password123");
        createEvent(token, eventRequest("Day 0", today()));
        createEvent(token, eventRequest("Day 6", today().plusDays(6)));
        createEvent(token, eventRequest("Day 8", today().plusDays(8)));

        JsonNode schedule = body(mockMvc.perform(get(SCHEDULE_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .param("date", today().toString())
                        .param("days", "7"))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(schedule.path("days").asInt()).isEqualTo(7);
        assertThat(schedule.path("events").size()).isEqualTo(2);
    }

    @Test
    void scheduleEmptyDayReturnsEmptyLists() throws Exception {
        String token = registerAndLogin("sched-4@blistra.com", "password123");

        JsonNode schedule = body(mockMvc.perform(get(SCHEDULE_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .param("date", today().plusDays(30).toString()))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(schedule.path("events").size()).isZero();
        assertThat(schedule.path("tasks").size()).isZero();
    }

    @Test
    void scheduleIsScopedToOwner() throws Exception {
        String token = registerAndLogin("sched-5@blistra.com", "password123");
        String otherToken = registerAndLogin("sched-5-other@blistra.com", "password123");
        createEvent(otherToken, eventRequest("Other's meeting", today()));

        JsonNode schedule = body(mockMvc.perform(get(SCHEDULE_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(schedule.path("events").size()).isZero();
    }

    @Test
    void completeEventPersistsThroughBackend() throws Exception {
        String token = registerAndLogin("sched-6@blistra.com", "password123");
        String id = createEvent(token, eventRequest("Gym", today()));

        mockMvc.perform(post(EVENTS_URL + "/" + id + "/complete")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        mockMvc.perform(get(EVENTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    @Test
    void completeOtherUsersEventIsNotFound() throws Exception {
        String token = registerAndLogin("sched-7@blistra.com", "password123");
        String otherToken = registerAndLogin("sched-7-other@blistra.com", "password123");
        String id = createEvent(otherToken, eventRequest("Private", today()));

        mockMvc.perform(post(EVENTS_URL + "/" + id + "/complete")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNotFound());
    }

    @Test
    void byDateRequiresOnlyOneDay() throws Exception {
        String token = registerAndLogin("sched-8@blistra.com", "password123");
        createEvent(token, eventRequest("Today sync", today()));
        createEvent(token, eventRequest("Tomorrow sync", today().plusDays(1)));

        JsonNode events = body(mockMvc.perform(get(EVENTS_URL + "/by-date")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .param("date", today().toString()))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(events.size()).isEqualTo(1);
        assertThat(events.get(0).path("title").asText()).isEqualTo("Today sync");
    }

    @Test
    void rangeWithInvalidWindowIsBadRequest() throws Exception {
        String token = registerAndLogin("sched-9@blistra.com", "password123");
        OffsetDateTime from = ZonedDateTime.of(today().atTime(10, 0), USER_ZONE).toOffsetDateTime();

        mockMvc.perform(get(EVENTS_URL + "/range")
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .param("from", from.plusHours(1).toString())
                        .param("to", from.toString()))
                .andExpect(status().isBadRequest());
    }
}
