package com.blistra.auth;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Live availability checks for the registration wizard: taken values are
 * reported while typing, free values pass, unchecked fields stay absent.
 */
public class AvailabilityIntegrationTest extends AuthFlowTest {

    @Test
    void freshValuesAreAvailable() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/auth/availability")
                        .param("username", "freshuser123")
                        .param("email", "fresh@example.com")
                        .param("phone", "+919876543299"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode tree = jsonMapper.readTree(result.getResponse().getContentAsString());
        assertTrue(tree.get("usernameAvailable").asBoolean());
        assertTrue(tree.get("emailAvailable").asBoolean());
        assertTrue(tree.get("phoneAvailable").asBoolean());
    }

    @Test
    void takenValuesAreUnavailable() throws Exception {
        MvcResult registered = registerFull(
                "takenuser", "taken@example.com", "+919876543210", "Password1");
        assertEquals(201, registered.getResponse().getStatus());

        MvcResult result = mockMvc.perform(get("/api/v1/auth/availability")
                        .param("username", "takenuser")
                        .param("email", "taken@example.com")
                        .param("phone", "+919876543210"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode tree = jsonMapper.readTree(result.getResponse().getContentAsString());
        assertFalse(tree.get("usernameAvailable").asBoolean());
        assertFalse(tree.get("emailAvailable").asBoolean());
        assertFalse(tree.get("phoneAvailable").asBoolean());
    }

    @Test
    void matchingIsCaseInsensitiveForUsernameAndEmail() throws Exception {
        MvcResult registered = registerFull(
                "CaseUser", "Case@Example.com", null, "Password1");
        assertEquals(201, registered.getResponse().getStatus());

        MvcResult result = mockMvc.perform(get("/api/v1/auth/availability")
                        .param("username", "caseuser")
                        .param("email", "case@example.com"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode tree = jsonMapper.readTree(result.getResponse().getContentAsString());
        assertFalse(tree.get("usernameAvailable").asBoolean());
        assertFalse(tree.get("emailAvailable").asBoolean());
    }

    @Test
    void malformedValuesAreUnavailable() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/auth/availability")
                        .param("username", "x")
                        .param("email", "not-an-email")
                        .param("phone", "12345"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode tree = jsonMapper.readTree(result.getResponse().getContentAsString());
        assertFalse(tree.get("usernameAvailable").asBoolean());
        assertFalse(tree.get("emailAvailable").asBoolean());
        assertFalse(tree.get("phoneAvailable").asBoolean());
    }
}
