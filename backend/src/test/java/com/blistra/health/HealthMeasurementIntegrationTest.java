package com.blistra.health;

import com.blistra.health.domain.MeasurementType;
import com.blistra.health.dto.MeasurementRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class HealthMeasurementIntegrationTest extends HealthTestSupport {

    private static final String URL = "/api/v1/health/measurements";

    @Test
    void authenticatedUserCanCreateMeasurement() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        MvcResult result = mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(weightRequest("80.5")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.type").value("WEIGHT"))
                .andExpect(jsonPath("$.unit").value("KG"))
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).doesNotContain("userId");
        assertThat(body).doesNotContain("password");
        assertThat(body).doesNotContain("\"user\"");
    }

    @Test
    void userCanReadUpdateDeleteOwnMeasurement() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        MvcResult created = mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(weightRequest("80.0")))
                .andExpect(status().isCreated())
                .andReturn();
        String id = jsonMapper.readTree(created.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(get(URL + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.value").value(80.0));

        mockMvc.perform(put(URL + "/" + id)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(weightRequest("81.5")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.value").value(81.5));

        mockMvc.perform(delete(URL + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(URL + "/" + id)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void unauthurizedRequestIsRejected() throws Exception {
        mockMvc.perform(get(URL))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post(URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(weightRequest("80.0")))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void invalidMeasurementValueIsRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurement(MeasurementType.HEART_RATE, "1000", "BPM", null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void negativeMeasurementValueIsRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurement(MeasurementType.WEIGHT, "-5", "KG", null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidUnitForTypeIsRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurement(MeasurementType.WEIGHT, "80", "BPM", null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void bloodPressureRequiresDiastolic() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurement(MeasurementType.BLOOD_PRESSURE, "120", "MMHG", null)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void bloodPressureDiastolicBelowSystolicIsRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurement(MeasurementType.BLOOD_PRESSURE, "110", "MMHG", "120")))
                .andExpect(status().isBadRequest());
    }

    @Test
    void futureMeasurementTimeIsRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(weightRequest("80.0", OffsetDateTime.now().plusDays(2))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void missingRequiredFieldsAreRejected() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        String missingType = write(MeasurementRequest.builder()
                .measuredAt(OffsetDateTime.now().minusHours(1))
                .value(new BigDecimal("80"))
                .unit("KG")
                .build());

        mockMvc.perform(post(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(missingType))
                .andExpect(status().isBadRequest());
    }

    @Test
    void collectionOnlyReturnsOwnRecordsWithPaginationAndFiltering() throws Exception {
        String aliceToken = registerAndLogin("alice@example.com", "password123");
        String bobToken = registerAndLogin("bob@example.com", "password123");

        mockMvc.perform(post(URL).header("Authorization", "Bearer " + aliceToken)
                .contentType(MediaType.APPLICATION_JSON).content(weightRequest("80.0")))
                .andExpect(status().isCreated());
        mockMvc.perform(post(URL).header("Authorization", "Bearer " + aliceToken)
                .contentType(MediaType.APPLICATION_JSON).content(weightRequest("81.0")))
                .andExpect(status().isCreated());
        mockMvc.perform(post(URL).header("Authorization", "Bearer " + aliceToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(measurement(MeasurementType.HEART_RATE, "72", "BPM", null)))
                .andExpect(status().isCreated());
        mockMvc.perform(post(URL).header("Authorization", "Bearer " + bobToken)
                .contentType(MediaType.APPLICATION_JSON).content(weightRequest("90.0")))
                .andExpect(status().isCreated());

        mockMvc.perform(get(URL).header("Authorization", "Bearer " + aliceToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(3))
                .andExpect(jsonPath("$.content.length()").value(3));

        mockMvc.perform(get(URL).header("Authorization", "Bearer " + bobToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(get(URL)
                .header("Authorization", "Bearer " + aliceToken)
                .param("type", "WEIGHT"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(2));

        MvcResult page = mockMvc.perform(get(URL)
                .header("Authorization", "Bearer " + aliceToken)
                .param("size", "2"))
                .andExpect(status().isOk())
                .andReturn();
        assertThat(jsonMapper.readTree(page.getResponse().getContentAsString()).get("totalPages").asInt())
                .isEqualTo(2);
    }

    private String weightRequest(String value) {
        return measurement(MeasurementType.WEIGHT, value, "KG", null);
    }

    private String weightRequest(String value, OffsetDateTime measuredAt) {
        return write(MeasurementRequest.builder()
                .type(MeasurementType.WEIGHT)
                .measuredAt(measuredAt)
                .value(new BigDecimal(value))
                .unit("KG")
                .build());
    }

    private String measurement(MeasurementType type, String value, String unit, String diastolic) {
        MeasurementRequest.MeasurementRequestBuilder builder = MeasurementRequest.builder()
                .type(type)
                .measuredAt(OffsetDateTime.now().minusDays(1))
                .value(new BigDecimal(value))
                .unit(unit);
        if (diastolic != null) {
            builder.valueDiastolic(new BigDecimal(diastolic));
        }
        return write(builder.build());
    }

    private String write(Object value) {
        try {
            return jsonMapper.writeValueAsString(value);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}