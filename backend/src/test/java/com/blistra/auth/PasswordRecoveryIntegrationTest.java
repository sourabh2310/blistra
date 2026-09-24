package com.blistra.auth;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

class PasswordRecoveryIntegrationTest extends AuthFlowTest {

    private static final String GENERIC =
            "If the account exists, a verification code will be sent.";

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    @Test
    void forgotPasswordDoesNotEnumerate() throws Exception {
        registerFull("recovery", "recovery@example.com", "+915555555555", "password1");

        MvcResult known = mockMvc.perform(post("/api/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(
                        Map.of("identifier", "recovery@example.com"))))
                .andReturn();
        MvcResult unknown = mockMvc.perform(post("/api/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(
                        Map.of("identifier", "ghost@example.com"))))
                .andReturn();

        assertThat(known.getResponse().getStatus()).isEqualTo(200);
        assertThat(unknown.getResponse().getStatus()).isEqualTo(200);
        assertThat(known.getResponse().getContentAsString()).contains(GENERIC);
        // Identical shape: only the timestamp may differ.
        assertThat(unknown.getResponse().getContentAsString()).contains(GENERIC);
        assertThat(unknown.getResponse().getContentAsString()).doesNotContain("ghost");
    }

    @Test
    void resetFlowSetsNewPassword() throws Exception {
        MvcResult reg = registerFull("resetme", "resetme@example.com", "+916666666666", "password1");
        String token = tokenOf(reg);

        // Recovery issues OTPs only to verified destinations: verify email first.
        String verifyCode = devCode(token, "EMAIL_VERIFY");
        mockMvc.perform(post("/api/v1/auth/verify/email")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(
                                Map.of("code", verifyCode))))
                .andReturn();

        mockMvc.perform(post("/api/v1/auth/forgot-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(
                        Map.of("identifier", "resetme", "channel", "EMAIL"))))
                .andReturn();
        String code = devCode(token, "PASSWORD_RESET");
        assertThat(code).matches("[0-9]{6}");

        // Mismatched confirmation is rejected without consuming the code.
        MvcResult mismatch = mockMvc.perform(post("/api/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "identifier", "resetme", "code", code,
                        "newPassword", "newpass1", "confirmPassword", "otherpass1"))))
                .andReturn();
        assertThat(mismatch.getResponse().getStatus()).isEqualTo(400);

        // Wrong code is rejected generically.
        MvcResult wrong = mockMvc.perform(post("/api/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "identifier", "resetme", "code", "000000",
                        "newPassword", "newpass1", "confirmPassword", "newpass1"))))
                .andReturn();
        assertThat(wrong.getResponse().getStatus()).isEqualTo(400);
        assertThat(wrong.getResponse().getContentAsString()).contains("INVALID_OTP");

        // Correct reset works and the new password logs in (by phone too).
        MvcResult reset = mockMvc.perform(post("/api/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "identifier", "resetme@example.com", "code", code,
                        "newPassword", "newpass1", "confirmPassword", "newpass1"))))
                .andReturn();
        assertThat(reset.getResponse().getStatus()).isEqualTo(200);

        MvcResult login = loginAs("+916666666666", "newpass1");
        assertThat(login.getResponse().getStatus()).isEqualTo(200);

        MvcResult oldLogin = loginAs("resetme", "password1");
        assertThat(oldLogin.getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void resetWithWeakPasswordIsRejected() throws Exception {
        MvcResult reg = registerFull("weakreset", "weakreset@example.com", null, "password1");
        String token = tokenOf(reg);
        String code = devCode(token, "PASSWORD_RESET");

        MvcResult weak = mockMvc.perform(post("/api/v1/auth/reset-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "identifier", "weakreset@example.com", "code", code,
                        "newPassword", "short", "confirmPassword", "short"))))
                .andReturn();
        assertThat(weak.getResponse().getStatus()).isEqualTo(400);
    }
}
