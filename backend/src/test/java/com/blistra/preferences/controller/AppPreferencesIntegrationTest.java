package com.blistra.preferences.controller;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end regression tests for per-user Home/navigation preferences:
 * defaults, save/reload, validation, and user isolation. Ownership is derived
 * from the JWT; the client never supplies a user id.
 */
class AppPreferencesIntegrationTest extends AbstractIntegrationTest {

    private static final String URL = "/api/v1/preferences";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @BeforeEach
    void cleanDatabase() {
        deleteAllUsers();
    }

    private String registerAndLogin(String email) throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(RegisterRequest.builder()
                        .email(email).password("password123").build())))
                .andExpect(status().isCreated());
        MvcResult login = mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(LoginRequest.builder()
                        .email(email).password("password123").build())))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(login.getResponse().getContentAsString()).get("token").asText();
    }

    private JsonNode getPrefs(String token) throws Exception {
        MvcResult result = mockMvc.perform(get(URL)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString());
    }

    private MvcResult putPrefs(String token, String body) throws Exception {
        return mockMvc.perform(put(URL)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
                .andReturn();
    }

    @Test
    void defaultsReturnedWhenNothingSaved() throws Exception {
        String token = registerAndLogin("prefs-a@example.com");
        JsonNode prefs = getPrefs(token);
        assertThat(prefs.get("bottomNav").toString()).contains("HOME", "ADD");
        assertThat(prefs.get("homeWidgets").toString()).contains("DAY_AT_A_GLANCE");
    }

    @Test
    void saveAndReloadRoundTrip() throws Exception {
        String token = registerAndLogin("prefs-b@example.com");
        MvcResult saved = putPrefs(token,
                "{\"bottomNav\":[\"HOME\",\"ADD\",\"HABITS\",\"DIET\",\"HUB\"],"
                        + "\"homeWidgets\":[\"HEALTH\",\"DIET\",\"DAY_AT_A_GLANCE\"]}");
        assertThat(saved.getResponse().getStatus()).isEqualTo(200);
        JsonNode reloaded = getPrefs(token);
        assertThat(reloaded.get("bottomNav").toString())
                .contains("HOME", "ADD", "HABITS", "DIET", "HUB");
        // Hero is always kept first regardless of submitted order.
        assertThat(reloaded.get("homeWidgets").get(0).asText()).isEqualTo("DAY_AT_A_GLANCE");
    }

    @Test
    void unknownDestinationRejected() throws Exception {
        String token = registerAndLogin("prefs-c@example.com");
        MvcResult result = putPrefs(token, "{\"bottomNav\":[\"HOME\",\"ADD\",\"ADMIN\"]}");
        assertThat(result.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    void homeCannotBeRemoved() throws Exception {
        String token = registerAndLogin("prefs-d@example.com");
        MvcResult result = putPrefs(token, "{\"bottomNav\":[\"ADD\",\"HUB\"]}");
        assertThat(result.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    void usersHaveIndependentPreferences() throws Exception {
        String alice = registerAndLogin("prefs-alice@example.com");
        String bob = registerAndLogin("prefs-bob@example.com");
        putPrefs(alice, "{\"bottomNav\":[\"HOME\",\"ADD\",\"FINANCE\"]}");
        JsonNode bobPrefs = getPrefs(bob);
        assertThat(bobPrefs.get("bottomNav").toString()).doesNotContain("FINANCE");
    }

    @Test
    void unauthenticatedRejected() throws Exception {
        mockMvc.perform(get(URL)).andExpect(status().isUnauthorized());
    }
}
