package com.blistra.health;

import com.blistra.health.domain.BloodType;
import com.blistra.health.dto.HealthProfileRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class HealthProfileIntegrationTest extends HealthTestSupport {

    private static final String PROFILE_URL = "/api/v1/health/profile";

    @Test
    void authenticatedUserCanCreateAndReadProfile() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        String body = jsonMapper.writeValueAsString(HealthProfileRequest.builder()
                .heightCm(new BigDecimal("172.5"))
                .bloodType(BloodType.O_POSITIVE)
                .dateOfBirth(LocalDate.of(1990, 5, 10))
                .build());

        mockMvc.perform(put(PROFILE_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.heightCm").value(172.5))
                .andExpect(jsonPath("$.bloodType").value("O_POSITIVE"))
                .andExpect(jsonPath("$.dateOfBirth").value("1990-05-10"));

        mockMvc.perform(get(PROFILE_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.heightCm").value(172.5));
    }

    @Test
    void getProfileBeforeCreationReturns404() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        mockMvc.perform(get(PROFILE_URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void profileSaveIsIdempotentUpsert() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        String first = jsonMapper.writeValueAsString(HealthProfileRequest.builder()
                .heightCm(new BigDecimal("170.0"))
                .build());
        MvcResult created = mockMvc.perform(put(PROFILE_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(first))
                .andExpect(status().isOk())
                .andReturn();

        String profileId = jsonMapper.readTree(created.getResponse().getContentAsString())
                .get("id")
                .asText();

        String updated = jsonMapper.writeValueAsString(HealthProfileRequest.builder()
                .heightCm(new BigDecimal("173.0"))
                .bloodType(BloodType.A_POSITIVE)
                .build());

        MvcResult result = mockMvc.perform(put(PROFILE_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(updated))
                .andExpect(status().isOk())
                .andReturn();

        String response = result.getResponse().getContentAsString();
        org.assertj.core.api.Assertions.assertThat(response).contains("\"heightCm\":173.0");
        org.assertj.core.api.Assertions.assertThat(
                jsonMapper.readTree(response).get("id").asText()).isEqualTo(profileId);
    }

    @Test
    void profileIsSeparatePerUser() throws Exception {
        String aliceToken = registerAndLogin("alice@example.com", "password123");
        String bobToken = registerAndLogin("bob@example.com", "password123");

        String body = jsonMapper.writeValueAsString(HealthProfileRequest.builder()
                .heightCm(new BigDecimal("170.0"))
                .build());

        mockMvc.perform(put(PROFILE_URL)
                .header("Authorization", "Bearer " + aliceToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andExpect(status().isOk());

        mockMvc.perform(get(PROFILE_URL)
                .header("Authorization", "Bearer " + bobToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void profileRequiresAuthentication() throws Exception {
        mockMvc.perform(get(PROFILE_URL))
                .andExpect(status().isUnauthorized());

        String body = jsonMapper.writeValueAsString(HealthProfileRequest.builder()
                .heightCm(new BigDecimal("170.0"))
                .build());
        mockMvc.perform(put(PROFILE_URL)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void profileRejectsImpossibleHeight() throws Exception {
        String token = registerAndLogin("alice@example.com", "password123");

        String body = jsonMapper.writeValueAsString(HealthProfileRequest.builder()
                .heightCm(new BigDecimal("999.00"))
                .build());

        mockMvc.perform(put(PROFILE_URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andExpect(status().isBadRequest());
    }
}