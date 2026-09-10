package com.blistra.planner;

import com.blistra.planner.dto.EventCreateRequest;
import com.blistra.planner.dto.EventUpdateRequest;
import com.blistra.planner.domain.EventStatus;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlannerEventIntegrationTest extends PlannerTestSupport {

    private static final ZoneId USER_ZONE = ZoneId.of("Asia/Kolkata");

    private JsonNode createEvent(String token, EventCreateRequest request) throws Exception {
        MvcResult result = mockMvc.perform(post(EVENTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return body(result);
    }

    private EventCreateRequest defaultEventRequest(String title) {
        OffsetDateTime start = ZonedDateTime.of(
                java.time.LocalDate.now(USER_ZONE).atTime(10, 0), USER_ZONE).toOffsetDateTime();
        return EventCreateRequest.builder()
                .title(title)
                .startAt(start)
                .endAt(start.plusHours(1))
                .build();
    }

    @Test
    void createEventDefaultsToScheduled() throws Exception {
        String token = registerAndLogin("event-1@blistra.com", "password123");
        JsonNode created = createEvent(token, defaultEventRequest("Standup"));

        assertThat(created.path("id").asText()).isNotEmpty();
        assertThat(created.path("title").asText()).isEqualTo("Standup");
        assertThat(created.path("status").asText()).isEqualTo("SCHEDULED");
        assertThat(created.path("startAt").asText()).isNotEmpty();
        assertThat(created.path("endAt").asText()).isNotEmpty();
    }

    @Test
    void createEventWithEndBeforeStartIsBadRequest() throws Exception {
        String token = registerAndLogin("event-2@blistra.com", "password123");
        EventCreateRequest request = defaultEventRequest("Backwards");
        request.setEndAt(request.getStartAt().minusMinutes(5));

        mockMvc.perform(post(EVENTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("BAD_REQUEST"));
    }

    @Test
    void createEventWithEqualEndIsBadRequest() throws Exception {
        String token = registerAndLogin("event-3@blistra.com", "password123");
        EventCreateRequest request = defaultEventRequest("Zero-length");
        request.setEndAt(request.getStartAt());

        mockMvc.perform(post(EVENTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void getOwnEvent() throws Exception {
        String token = registerAndLogin("event-4@blistra.com", "password123");
        String id = createEvent(token, defaultEventRequest("Fetch me")).path("id").asText();

        mockMvc.perform(get(EVENTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Fetch me"));
    }

    @Test
    void getOtherUsersEventIsNotFound() throws Exception {
        String token = registerAndLogin("event-5@blistra.com", "password123");
        String otherToken = registerAndLogin("event-5-other@blistra.com", "password123");
        String id = createEvent(otherToken, defaultEventRequest("Private")).path("id").asText();

        mockMvc.perform(get(EVENTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNotFound());
    }

    @Test
    void updateEventReplacesFields() throws Exception {
        String token = registerAndLogin("event-6@blistra.com", "password123");
        EventCreateRequest created = defaultEventRequest("Old");
        String id = createEvent(token, created).path("id").asText();

        EventUpdateRequest update = EventUpdateRequest.builder()
                .title("New")
                .description("Shifted")
                .location("Room 1")
                .startAt(created.getStartAt().plusDays(1))
                .endAt(created.getEndAt().plusDays(1))
                .status(EventStatus.CANCELLED)
                .build();

        JsonNode updated = body(mockMvc.perform(put(EVENTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(updated.path("title").asText()).isEqualTo("New");
        assertThat(updated.path("description").asText()).isEqualTo("Shifted");
        assertThat(updated.path("location").asText()).isEqualTo("Room 1");
        assertThat(updated.path("status").asText()).isEqualTo("CANCELLED");
        assertThat(updated.path("startAt").asText()).isEqualTo(update.getStartAt().toString());
    }

    @Test
    void updateEventWithInvalidRangeIsBadRequest() throws Exception {
        String token = registerAndLogin("event-7@blistra.com", "password123");
        EventCreateRequest created = defaultEventRequest("Range test");
        String id = createEvent(token, created).path("id").asText();

        EventUpdateRequest update = EventUpdateRequest.builder()
                .title("Range test")
                .startAt(created.getStartAt().plusHours(3))
                .endAt(created.getEndAt())
                .build();

        mockMvc.perform(put(EVENTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(update)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void listIsScopedToOwnerAndSortedByStartAt() throws Exception {
        String token = registerAndLogin("event-8@blistra.com", "password123");
        String otherToken = registerAndLogin("event-8-other@blistra.com", "password123");
        EventCreateRequest early = defaultEventRequest("Early");
        EventCreateRequest late = defaultEventRequest("Late");
        late.setStartAt(early.getStartAt().plusHours(2));
        late.setEndAt(early.getEndAt().plusHours(2));
        createEvent(token, late);
        createEvent(token, early);
        createEvent(otherToken, defaultEventRequest("Other user's event"));

        JsonNode list = body(mockMvc.perform(get(EVENTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(list.path("totalElements").asLong()).isEqualTo(2);
        assertThat(list.path("content").get(0).path("title").asText()).isEqualTo("Early");
        assertThat(list.path("content").get(1).path("title").asText()).isEqualTo("Late");
    }

    @Test
    void deleteEventRemovesIt() throws Exception {
        String token = registerAndLogin("event-9@blistra.com", "password123");
        String id = createEvent(token, defaultEventRequest("Disappear")).path("id").asText();

        mockMvc.perform(delete(EVENTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(EVENTS_URL + "/" + id)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token)))
                .andExpect(status().isNotFound());
    }

    @Test
    void createEventWithBlankTitleIsBadRequest() throws Exception {
        String token = registerAndLogin("event-10@blistra.com", "password123");
        EventCreateRequest request = defaultEventRequest("  ");
        request.setTitle("  ");

        mockMvc.perform(post(EVENTS_URL)
                        .header(HttpHeaders.AUTHORIZATION, authHeader(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }
}