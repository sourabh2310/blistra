package com.blistra.auth;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;

class OtpVerificationIntegrationTest extends AuthFlowTest {

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    @Test
    void emailAndPhoneVerifyActivatesAccount() throws Exception {
        MvcResult reg = registerFull("otpuser", "otp@example.com", "+914444444444", "password1");
        String token = tokenOf(reg);

        String emailCode = devCode(token, "EMAIL_VERIFY");
        assertThat(emailCode).matches("[0-9]{6}");
        MvcResult emailResult = verify(token, "email", emailCode);
        assertThat(emailResult.getResponse().getStatus()).isEqualTo(200);
        assertThat(emailResult.getResponse().getContentAsString()).contains("\"emailVerified\":true");
        // Phone still pending: account stays PENDING_VERIFICATION.
        assertThat(emailResult.getResponse().getContentAsString())
                .contains("\"status\":\"PENDING_VERIFICATION\"");

        String phoneCode = devCode(token, "PHONE_VERIFY");
        MvcResult phoneResult = verify(token, "phone", phoneCode);
        assertThat(phoneResult.getResponse().getStatus()).isEqualTo(200);
        assertThat(phoneResult.getResponse().getContentAsString()).contains("\"phoneVerified\":true");
        assertThat(phoneResult.getResponse().getContentAsString()).contains("\"status\":\"ACTIVE\"");

        // Codes are single-use.
        MvcResult reuse = verify(token, "email", emailCode);
        assertThat(reuse.getResponse().getStatus()).isEqualTo(400);
        assertThat(reuse.getResponse().getContentAsString()).contains("INVALID_OTP");
    }

    @Test
    void wrongCodeCountsAttemptsThenLocks() throws Exception {
        MvcResult reg = registerFull("attempts", "attempts@example.com", null, "password1");
        String token = tokenOf(reg);

        for (int i = 1; i <= 4; i++) {
            MvcResult wrong = verify(token, "email", "000000");
            assertThat(wrong.getResponse().getStatus()).isEqualTo(400);
            assertThat(wrong.getResponse().getContentAsString()).contains("INVALID_OTP");
        }
        MvcResult locked = verify(token, "email", "000000");
        assertThat(locked.getResponse().getStatus()).isEqualTo(400);
        assertThat(locked.getResponse().getContentAsString()).contains("TOO_MANY_ATTEMPTS");

        // Even the right code fails after lockout; a fresh code works.
        String real = devCode(token, "EMAIL_VERIFY");
        MvcResult stale = verify(token, "email", real);
        assertThat(stale.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    void expiredCodeIsRejected() throws Exception {
        MvcResult reg = registerFull("expired", "expired@example.com", null, "password1");
        String token = tokenOf(reg);
        String userId = userIdOf(reg);

        expireLatest(userId, "EMAIL_VERIFY");
        // Code value no longer matters; expiry is checked first.
        MvcResult result = verify(token, "email", "123456");
        assertThat(result.getResponse().getStatus()).isEqualTo(400);
        assertThat(result.getResponse().getContentAsString()).contains("EXPIRED_OTP");
    }

    @Test
    void resendCooldownIsEnforcedWithRetryHint() throws Exception {
        MvcResult reg = registerFull("cooldown", "cooldown@example.com", null, "password1");
        String token = tokenOf(reg);

        MvcResult immediate = mockMvc.perform(
                org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .post("/api/v1/auth/resend/email")
                        .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(immediate.getResponse().getStatus()).isEqualTo(429);
        assertThat(immediate.getResponse().getContentAsString()).contains("RESEND_COOLDOWN");
        assertThat(immediate.getResponse().getContentAsString()).contains("retryAfterSeconds");

        // After the window, resend succeeds and the new code verifies.
        clearCooldowns(userIdOf(reg));
        MvcResult resend = mockMvc.perform(
                org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .post("/api/v1/auth/resend/email")
                        .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(resend.getResponse().getStatus()).isEqualTo(200);
        MvcResult verified = verify(token, "email", devCode(token, "EMAIL_VERIFY"));
        assertThat(verified.getResponse().getStatus()).isEqualTo(200);
    }

    @Test
    void devEndpointIsAuthenticated() throws Exception {
        MvcResult result = mockMvc.perform(
                org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .get("/api/v1/auth/dev/otp"))
                .andReturn();
        assertThat(result.getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void otpCodesAreStoredHashedOnly() throws Exception {
        MvcResult reg = registerFull("hashcheck", "hashcheck@example.com", null, "password1");
        String token = tokenOf(reg);
        String code = devCode(token, "EMAIL_VERIFY");

        String hash = jdbcTemplate.queryForObject(
                "SELECT code_hash FROM verification_otps WHERE purpose = 'EMAIL_VERIFY' "
                        + "AND consumed = false ORDER BY created_at DESC LIMIT 1",
                String.class);
        assertThat(hash).isNotNull();
        assertThat(hash).doesNotContain(code);
        assertThat(hash).hasSize(64);
    }
}
