package com.blistra.health;

import com.blistra.health.domain.*;
import com.blistra.health.dto.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class HealthOtherRecordsIntegrationTest extends HealthTestSupport {

    @Test
    void sleepCrudAndValidation() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String url = "/api/v1/health/sleep";

        MvcResult created = mockMvc.perform(post(url)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(sleepBody(OffsetDateTime.now().minusHours(8), OffsetDateTime.now().minusHours(1), 4)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.durationMinutes").isNumber())
                .andReturn();
        String id = jsonMapper.readTree(created.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(url + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rating").value(4));

        mockMvc.perform(get(url)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(delete(url + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
    }

    @Test
    void sleepEndingBeforeStartIsRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post("/api/v1/health/sleep")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(sleepBody(OffsetDateTime.now().minusHours(1), OffsetDateTime.now().minusHours(8), null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void sleepOverlyLongDurationIsRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post("/api/v1/health/sleep")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(sleepBody(OffsetDateTime.now().minusDays(3), OffsetDateTime.now(), null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void activityCrud() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String url = "/api/v1/health/activity";

        MvcResult created = mockMvc.perform(post(url)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(activityBody(ActivityType.RUNNING, 30, new BigDecimal("5.0"), 300)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.type").value("RUNNING"))
                .andReturn();
        String id = jsonMapper.readTree(created.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(url + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.durationMinutes").value(30));

        mockMvc.perform(put(url + "/" + id)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(activityBody(ActivityType.CYCLING, 45, null, null)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.type").value("CYCLING"));
    }

    @Test
    void activityRejectsInvalidDuration() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post("/api/v1/health/activity")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(activityBody(ActivityType.WALKING, 0, null, null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void logsCrud() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");
        String url = "/api/v1/health/logs";

        MvcResult created = mockMvc.perform(post(url)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(logBody("Headache", "Mild headache after a short night", Severity.MILD)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.title").value("Headache"))
                .andReturn();
        String id = jsonMapper.readTree(created.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(url + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.severity").value("MILD"));

        mockMvc.perform(get(url)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].title").value("Headache"));
    }

    @Test
    void logRequiresTitle() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post("/api/v1/health/logs")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(logBody("", null, null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void eventsCrud() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        MvcResult created = mockMvc.perform(post("/api/v1/health/events")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(eventBody(EventType.VACCINATION, "Flu vaccination", OffsetDateTime.now().minusMonths(2))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.type").value("VACCINATION"))
                .andReturn();
        String id = jsonMapper.readTree(created.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get("/api/v1/health/events/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Flu vaccination"));
    }

    @Test
    void appointmentsCrud() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        MvcResult created = mockMvc.perform(post("/api/v1/health/appointments")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(appointmentBody("Dental check-up", OffsetDateTime.now().plusDays(5))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("SCHEDULED"))
                .andReturn();
        String id = jsonMapper.readTree(created.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get("/api/v1/health/appointments/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Dental check-up"));

        mockMvc.perform(get("/api/v1/health/appointments")
                .header("Authorization", "Bearer " + token)
                .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void appointmentMissingFieldsAreRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post("/api/v1/health/appointments")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(appointmentBody("", OffsetDateTime.now().plusDays(1))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void appointmentCanBeDeleted() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        MvcResult created = mockMvc.perform(post("/api/v1/health/appointments")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(appointmentBody("Check-up", OffsetDateTime.now().plusDays(2))))
                .andExpect(status().isCreated())
                .andReturn();
        String id = jsonMapper.readTree(created.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(delete("/api/v1/health/appointments/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
    }

    private String sleepBody(OffsetDateTime start, OffsetDateTime end, Integer rating) throws Exception {
        return jsonMapper.writeValueAsString(SleepRecordRequest.builder()
                .startedAt(start)
                .endedAt(end)
                .rating(rating)
                .build());
    }

    private String activityBody(ActivityType type, int durationMinutes, BigDecimal distanceKm, Integer calories)
            throws Exception {
        return jsonMapper.writeValueAsString(ActivityRequest.builder()
                .type(type)
                .performedAt(OffsetDateTime.now().minusDays(1))
                .durationMinutes(durationMinutes)
                .distanceKm(distanceKm)
                .caloriesBurned(calories)
                .build());
    }

    private String logBody(String title, String description, Severity severity) throws Exception {
        return jsonMapper.writeValueAsString(HealthLogRequest.builder()
                .title(title)
                .description(description)
                .observedAt(OffsetDateTime.now().minusDays(1))
                .severity(severity)
                .build());
    }

    private String eventBody(EventType type, String title, OffsetDateTime occurredAt) throws Exception {
        return jsonMapper.writeValueAsString(HealthEventRequest.builder()
                .type(type)
                .title(title)
                .occurredAt(occurredAt)
                .build());
    }

    private String appointmentBody(String title, OffsetDateTime scheduledAt) throws Exception {
        return jsonMapper.writeValueAsString(AppointmentRequest.builder()
                .title(title)
                .scheduledAt(scheduledAt)
                .build());
    }
}