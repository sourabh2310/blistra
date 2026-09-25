package com.blistra.auth;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * Recovery identity resolution: unknown identifiers stop with 404 and never
 * reach OTP delivery; only verified channels are offered; OTPs are issued
 * only to verified destinations.
 */
class RecoveryChannelsIntegrationTest extends AuthFlowTest {

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    private JsonNode channelsOf(String identifier) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/recovery/channels")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(
                                Map.of("identifier", identifier))))
                .andReturn();
        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        return jsonMapper.readTree(result.getResponse().getContentAsString());
    }

    private int passwordResetOtpCount(String userId) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM verification_otps WHERE user_id = ?::uuid AND purpose = 'PASSWORD_RESET'",
                Integer.class, userId);
        return count == null ? 0 : count;
    }

    @Test
    void unknownUsernameStopsWith404AndNoOtp() throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/recovery/channels")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(
                                Map.of("identifier", "ghostuser"))))
                .andReturn();
        assertThat(result.getResponse().getStatus()).isEqualTo(404);
        assertThat(result.getResponse().getContentAsString())
                .contains("Couldn't find an account");

        // The generic issuance endpoint also creates nothing for unknown ids.
        mockMvc.perform(post("/api/v1/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(
                                Map.of("identifier", "ghostuser"))))
                .andReturn();
        Integer total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM verification_otps WHERE purpose = 'PASSWORD_RESET'",
                Integer.class);
        assertThat(total == null ? 0 : total).isEqualTo(0);
    }

    @Test
    void unknownEmailAndPhoneStopWith404() throws Exception {
        for (String identifier : new String[]{
                "ghost@example.com", "+919999999999"}) {
            MvcResult result = mockMvc.perform(post("/api/v1/auth/recovery/channels")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(jsonMapper.writeValueAsString(
                                    Map.of("identifier", identifier))))
                    .andReturn();
            assertThat(result.getResponse().getStatus()).isEqualTo(404);
        }
    }

    @Test
    void verifiedEmailOnlyOffersEmail() throws Exception {
        MvcResult reg = registerFull(
                "emailonly", "emailonly@example.com", null, "password1");
        String token = tokenOf(reg);

        // Verify the email first.
        String code = devCode(token, "EMAIL_VERIFY");
        mockMvc.perform(post("/api/v1/auth/verify/email")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(Map.of("code", code))))
                .andReturn();

        JsonNode tree = channelsOf("emailonly");
        assertThat(tree.get("channels").toString()).contains("EMAIL");
        assertThat(tree.get("channels").toString()).doesNotContain("SMS");
        assertThat(tree.get("emailMasked").asString()).contains("@example.com");
        assertThat(tree.get("emailMasked").asString()).doesNotContain("emailonly");
        assertThat(tree.has("phoneMasked")
                && !tree.get("phoneMasked").isNull()
                && !tree.get("phoneMasked").asString().isEmpty()).isFalse();
    }

    @Test
    void unverifiedPhoneIsNotOfferedAndReceivesNoOtp() throws Exception {
        MvcResult reg = registerFull(
                "unverifiedphone", "unverifiedphone@example.com", "+918888888888", "password1");
        String token = tokenOf(reg);
        String userId = userIdOf(reg);

        // Verify email only; phone stays unverified.
        String code = devCode(token, "EMAIL_VERIFY");
        mockMvc.perform(post("/api/v1/auth/verify/email")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(Map.of("code", code))))
                .andReturn();

        JsonNode tree = channelsOf("unverifiedphone");
        assertThat(tree.get("channels").toString()).doesNotContain("SMS");

        // Explicitly requesting the unverified channel issues nothing.
        mockMvc.perform(post("/api/v1/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(Map.of(
                                "identifier", "unverifiedphone", "channel", "SMS"))))
                .andReturn();
        assertThat(passwordResetOtpCount(userId)).isEqualTo(0);
    }

    @Test
    void verifiedChannelIssuesOtpAfterResolution() throws Exception {
        MvcResult reg = registerFull(
                "bothverified", "bothverified@example.com", "+917777777777", "password1");
        String token = tokenOf(reg);
        String userId = userIdOf(reg);

        String emailCode = devCode(token, "EMAIL_VERIFY");
        mockMvc.perform(post("/api/v1/auth/verify/email")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(Map.of("code", emailCode))))
                .andReturn();
        String phoneCode = devCode(token, "PHONE_VERIFY");
        mockMvc.perform(post("/api/v1/auth/verify/phone")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(Map.of("code", phoneCode))))
                .andReturn();

        JsonNode tree = channelsOf("bothverified");
        assertThat(tree.get("channels").toString()).contains("EMAIL", "SMS");

        mockMvc.perform(post("/api/v1/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(Map.of(
                                "identifier", "bothverified", "channel", "EMAIL"))))
                .andReturn();
        assertThat(passwordResetOtpCount(userId)).isEqualTo(1);
    }
}
