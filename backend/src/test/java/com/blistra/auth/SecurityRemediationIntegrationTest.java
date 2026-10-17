package com.blistra.auth;

import com.blistra.auth.otp.*;
import com.blistra.common.exception.OtpVerificationException;
import com.blistra.common.exception.VerificationUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@TestPropertySource(properties={"blistra.security.rate-limit.enabled=true",
    "blistra.security.private-discovery=true", "blistra.security.verified-sharing-required=true",
    "blistra.security.require-terms=true", "blistra.sms.enabled=false"})
class SecurityRemediationIntegrationTest extends AuthFlowTest {
    @MockitoBean EmailSender email;
    @Autowired VerificationService verification;
    @BeforeEach void clean() { deleteAllUsers(); jdbcTemplate.execute("DELETE FROM authentication_rate_limits"); }

    @Test void termsAreRequiredAndUnverifiedAccountsCannotWriteFinance() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
            .content(jsonMapper.writeValueAsString(Map.of("email","consent@example.com","password","password1"))))
            .andExpect(status().isBadRequest());
        var registered=registerFull("consent","consent@example.com",null,"password1");
        assertThat(registered.getResponse().getStatus()).isEqualTo(201);
        String token=tokenOf(registered);
        mockMvc.perform(post("/api/v1/finance/groups").header("Authorization","Bearer "+token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Trip\",\"currency\":\"INR\"}"))
            .andExpect(status().isForbidden());
        assertThat(verify(token,"email",devCode(token,"EMAIL_VERIFY")).getResponse().getStatus()).isEqualTo(200);
        mockMvc.perform(post("/api/v1/finance/groups").header("Authorization","Bearer "+token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Trip\",\"currency\":\"INR\"}"))
            .andExpect(status().isCreated());
        assertThat(jdbcTemplate.queryForObject("SELECT terms_version FROM users WHERE id=?::uuid",String.class,userIdOf(registered)))
            .isEqualTo("2026-10-17");
    }
    @Test void passwordChangeRevokesOldTokensAndNewLoginWorks() throws Exception {
        var registered=registerFull("revoke","revoke@example.com",null,"password1");
        String token=tokenOf(registered);
        mockMvc.perform(post("/api/v1/auth/change-password").header("Authorization","Bearer "+token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"currentPassword\":\"password1\",\"newPassword\":\"password2\"}"))
            .andExpect(status().isOk());
        mockMvc.perform(get("/api/v1/profile").header("Authorization","Bearer "+token)).andExpect(status().isUnauthorized());
        String fresh=loginToken("revoke","password2");
        mockMvc.perform(get("/api/v1/profile").header("Authorization","Bearer "+fresh)).andExpect(status().isOk());
    }
    @Test void emailOnlyOnboardingCompletesEvenWithAnUnverifiedOptionalPhone() throws Exception {
        var registered=registerFull("optionalphone","optionalphone@example.com","+919876543210","password1");
        String token=tokenOf(registered);
        assertThat(verify(token,"email",devCode(token,"EMAIL_VERIFY")).getResponse().getStatus()).isEqualTo(200);
        mockMvc.perform(put("/api/v1/profile").header("Authorization","Bearer "+token)
            .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(Map.of(
                "displayName","Optional Phone","dateOfBirth","1990-01-01","country","IN",
                "timezone","Asia/Kolkata","unitSystem","METRIC")))).andExpect(status().isOk());
        var response=mockMvc.perform(post("/api/v1/profile/complete-onboarding").header("Authorization","Bearer "+token))
            .andExpect(status().isOk()).andReturn();
        var profile=jsonMapper.readTree(response.getResponse().getContentAsString());
        assertThat(profile.get("status").asText()).isEqualTo("ACTIVE");
        assertThat(profile.get("onboardingCompleted").asBoolean()).isTrue();
        assertThat(profile.get("phoneVerified").asBoolean()).isFalse();
    }
    @Test void recoveryRevokesEveryExistingAccessToken() throws Exception {
        var registered=registerFull("recovery","recovery@example.com",null,"password1");
        String token=tokenOf(registered),second=loginToken("recovery","password1");
        verify(token,"email",devCode(token,"EMAIL_VERIFY"));
        mockMvc.perform(post("/api/v1/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
            .content("{\"identifier\":\"recovery\",\"channel\":\"EMAIL\"}")).andExpect(status().isOk());
        String code=devCode(token,"PASSWORD_RESET");
        mockMvc.perform(post("/api/v1/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
            .content(jsonMapper.writeValueAsString(Map.of("identifier","recovery","code",code,
                "newPassword","password2","confirmPassword","password2")))).andExpect(status().isOk());
        for (String old:java.util.List.of(token,second))
            mockMvc.perform(get("/api/v1/profile").header("Authorization","Bearer "+old)).andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/v1/profile").header("Authorization","Bearer "+loginToken("recovery","password2")))
            .andExpect(status().isOk());
    }
    @Test void deliveryFailureKeepsAccountAndAllowsImmediateRetry() throws Exception {
        doThrow(new VerificationUnavailableException("mail unavailable")).when(email).sendVerificationCode(anyString(),anyString());
        var registered=registerFull("retry","retry@example.com",null,"password1");
        assertThat(registered.getResponse().getStatus()).isEqualTo(201);
        String id=userIdOf(registered);
        assertThat(jdbcTemplate.queryForObject("SELECT count(*) FROM verification_otps WHERE user_id=?::uuid",Integer.class,id)).isZero();
        doNothing().when(email).sendVerificationCode(anyString(),anyString());
        mockMvc.perform(post("/api/v1/auth/resend/email").header("Authorization","Bearer "+tokenOf(registered)))
            .andExpect(status().isOk());
        assertThat(devCode(tokenOf(registered),"EMAIL_VERIFY")).matches("[0-9]{6}");
    }
    @Test void sameOtpCanOnlySucceedOnceUnderConcurrency() throws Exception {
        var reg=registerFull("parallel","parallel@example.com",null,"password1");
        String token=tokenOf(reg),code=devCode(token,"EMAIL_VERIFY");
        UUID id=UUID.fromString(userIdOf(reg));
        var start=new CountDownLatch(1);
        try (var pool=Executors.newFixedThreadPool(2)) {
            Callable<Boolean> check=() -> { start.await();
                try { verification.verify(id,OtpPurpose.EMAIL_VERIFY,code); return true; }
                catch (OtpVerificationException e) { return false; }
            };
            var a=pool.submit(check);var b=pool.submit(check);start.countDown();
            assertThat(java.util.List.of(a.get(10,TimeUnit.SECONDS),b.get(10,TimeUnit.SECONDS)))
                .containsExactlyInAnyOrder(true,false);
        }
    }
    @Test void failedRecoveryResendDoesNotDestroyTheLastDeliveredCode() throws Exception {
        var reg=registerFull("priorcode","priorcode@example.com",null,"password1");
        String token=tokenOf(reg);
        verify(token,"email",devCode(token,"EMAIL_VERIFY"));
        var body="{\"identifier\":\"priorcode\",\"channel\":\"EMAIL\"}";
        mockMvc.perform(post("/api/v1/auth/forgot-password").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk());
        String code=devCode(token,"PASSWORD_RESET");clearCooldowns(userIdOf(reg));
        doThrow(new VerificationUnavailableException("mail unavailable")).when(email).sendVerificationCode(anyString(),anyString());
        mockMvc.perform(post("/api/v1/auth/forgot-password").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isOk());
        assertThat(devCode(token,"PASSWORD_RESET")).isEqualTo(code);
        mockMvc.perform(post("/api/v1/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
            .content(jsonMapper.writeValueAsString(Map.of("identifier","priorcode","code",code,
                "newPassword","password2","confirmPassword","password2")))).andExpect(status().isOk());
    }
    @Test void privateDiscoveryDoesNotRevealEmailExistence() throws Exception {
        registerFull("privateuser","known@example.com",null,"password1");
        var known=mockMvc.perform(get("/api/v1/auth/availability").param("email","known@example.com")).andReturn();
        var unknown=mockMvc.perform(get("/api/v1/auth/availability").param("email","absent@example.com")).andReturn();
        assertThat(known.getResponse().getStatus()).isEqualTo(200);
        assertThat(known.getResponse().getContentAsString()).isEqualTo(unknown.getResponse().getContentAsString());
    }
    @Test void distributedPasswordGuessingIsLimitedPerAccount() throws Exception {
        registerFull("limited","limited@example.com",null,"password1");
        for (int i=0;i<20;i++) assertThat(loginAs("limited","wrongpassword1").getResponse().getStatus()).isEqualTo(401);
        assertThat(loginAs("limited","password1").getResponse().getStatus()).isEqualTo(429);
    }
}
