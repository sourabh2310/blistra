package com.blistra.auth;

import com.blistra.AbstractIntegrationTest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * Shared helpers for auth/OTP/profile flows: full registration, identifier
 * login and dev-mode OTP retrieval.
 */
public abstract class AuthFlowTest extends AbstractIntegrationTest {

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected JsonMapper jsonMapper;

    protected MvcResult registerFull(String username, String email, String phone,
                                     String password) throws Exception {
        return registerFull(username, email, phone, password, null);
    }

    protected MvcResult registerFull(String username, String email, String phone,
                                     String password, String displayName) throws Exception {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("email", email);
        body.put("password", password);
        if (username != null) {
            body.put("username", username);
        }
        if (phone != null) {
            body.put("phone", phone);
        }
        if (displayName != null) {
            body.put("displayName", displayName);
        }
        body.put("termsAccepted", true);
        return mockMvc.perform(post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(body)))
                .andReturn();
    }

    protected String tokenOf(MvcResult registerResult) throws Exception {
        JsonNode tree = jsonMapper.readTree(registerResult.getResponse().getContentAsString());
        return tree.get("token").asString();
    }

    protected String userIdOf(MvcResult registerResult) throws Exception {
        JsonNode tree = jsonMapper.readTree(registerResult.getResponse().getContentAsString());
        return tree.get("id").asString();
    }

    protected MvcResult loginAs(String identifier, String password) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(
                        Map.of("identifier", identifier, "password", password))))
                .andReturn();
    }

    protected String loginToken(String identifier, String password) throws Exception {
        MvcResult result = loginAs(identifier, password);
        JsonNode tree = jsonMapper.readTree(result.getResponse().getContentAsString());
        return tree.get("token").asString();
    }

    /** Dev-mode latest code for the authenticated account and purpose. */
    protected String devCode(String token, String purpose) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/auth/dev/otp")
                .header("Authorization", "Bearer " + token)
                .param("purpose", purpose))
                .andReturn();
        JsonNode tree = jsonMapper.readTree(result.getResponse().getContentAsString());
        return tree.get("code").asString();
    }

    protected MvcResult verify(String token, String channel, String code) throws Exception {
        return mockMvc.perform(post("/api/v1/auth/verify/" + channel)
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of("code", code))))
                .andReturn();
    }

    /** Pushes all OTP rows for the user outside the resend cooldown window. */
    protected void clearCooldowns(String userId) {
        jdbcTemplate.update(
                "UPDATE verification_otps SET created_at = created_at - INTERVAL '61 seconds' "
                        + "WHERE user_id = ?::uuid",
                userId);
    }

    /**
     * Expires the latest active OTP for (user, purpose). Uses a fixed ancient
     * timestamp: raw SQL bypasses Hibernate's UTC normalization, so relative
     * expressions would be timezone-fragile.
     */
    protected void expireLatest(String userId, String purpose) {
        int rows = jdbcTemplate.update(
                "UPDATE verification_otps SET expires_at = TIMESTAMP '2000-01-01 00:00:00' "
                        + "WHERE user_id = ?::uuid AND purpose = ? AND consumed = false",
                userId, purpose);
        if (rows == 0) {
            throw new IllegalStateException("No active OTP to expire for " + purpose);
        }
    }
}
