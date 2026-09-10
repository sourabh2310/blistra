package com.blistra.health;

import com.blistra.health.domain.AppointmentStatus;
import com.blistra.health.dto.AppointmentRequest;
import com.blistra.health.dto.MeasurementRequest;
import com.blistra.health.domain.MeasurementType;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Cross-user access attempts must never succeed. Manipulated IDs return 404 so
 * an attacker cannot distinguish between missing and forbidden resources.
 */
class HealthOwnershipIntegrationTest extends HealthTestSupport {

    private static final String MEASUREMENTS_URL = "/api/v1/health/measurements";
    private static final String APPOINTMENTS_URL = "/api/v1/health/appointments";
    private static final String PROFILE_URL = "/api/v1/health/profile";

    @Test
    void userCannotReadAnotherUsersMeasurement() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceMeasurementId = createMeasurement(alice);

        mockMvc.perform(get(MEASUREMENTS_URL + "/" + aliceMeasurementId)
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotUpdateAnotherUsersMeasurement() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceMeasurementId = createMeasurement(alice);

        mockMvc.perform(put(MEASUREMENTS_URL + "/" + aliceMeasurementId)
                .header("Authorization", "Bearer " + bob)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurementBody(new BigDecimal("90.0"))))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotDeleteAnotherUsersMeasurement() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceMeasurementId = createMeasurement(alice);

        mockMvc.perform(delete(MEASUREMENTS_URL + "/" + aliceMeasurementId)
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(get(MEASUREMENTS_URL + "/" + aliceMeasurementId)
                .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk());
    }

    @Test
    void userCannotAccessAnotherUsersAppointment() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        String aliceAppointmentId = createAppointment(alice);

        mockMvc.perform(get(APPOINTMENTS_URL + "/" + aliceAppointmentId)
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(put(APPOINTMENTS_URL + "/" + aliceAppointmentId)
                .header("Authorization", "Bearer " + bob)
                .contentType(MediaType.APPLICATION_JSON)
                .content(appointmentBody()))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(APPOINTMENTS_URL + "/" + aliceAppointmentId)
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotAccessAnotherUsersProfile() throws Exception {
        String alice = registerAndLogin("alice@example.com", "password123");
        String bob = registerAndLogin("bob@example.com", "password123");

        createMeasurement(alice);

        String body = jsonMapper.writeValueAsString(com.blistra.health.dto.HealthProfileRequest.builder()
                .heightCm(new BigDecimal("170.0"))
                .build());

        mockMvc.perform(put(PROFILE_URL)
                .header("Authorization", "Bearer " + alice)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andExpect(status().isOk());

        mockMvc.perform(get(PROFILE_URL)
                .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }

    private String createMeasurement(String token) throws Exception {
        MvcResult result = mockMvc.perform(post(MEASUREMENTS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurementBody(new BigDecimal("80.0"))))
                .andExpect(status().isCreated())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText();
    }

    private String createAppointment(String token) throws Exception {
        MvcResult result = mockMvc.perform(post(APPOINTMENTS_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(appointmentBody()))
                .andExpect(status().isCreated())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText();
    }

    private String measurementBody(BigDecimal value) throws Exception {
        return jsonMapper.writeValueAsString(MeasurementRequest.builder()
                .type(MeasurementType.WEIGHT)
                .measuredAt(OffsetDateTime.now().minusDays(1))
                .value(value)
                .unit("KG")
                .build());
    }

    private String appointmentBody() throws Exception {
        return jsonMapper.writeValueAsString(AppointmentRequest.builder()
                .title("Dental check-up")
                .scheduledAt(OffsetDateTime.now().plusDays(5))
                .location("Main Street Clinic")
                .status(AppointmentStatus.SCHEDULED)
                .build());
    }
}