package com.blistra.profile;

import com.blistra.auth.AuthFlowTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

class ProfileIntegrationTest extends AuthFlowTest {

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    @Test
    void getProfileReflectsIdentityAndEmptyProfile() throws Exception {
        MvcResult reg = registerFull("profilist", "profilist@example.com", "+917777777777",
                "password1", "Profilist");
        String token = tokenOf(reg);

        MvcResult result = mockMvc.perform(get("/api/v1/profile")
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        String body = result.getResponse().getContentAsString();
        assertThat(body).contains("\"username\":\"profilist\"");
        assertThat(body).contains("\"displayName\":\"Profilist\"");
        assertThat(body).contains("\"emailVerified\":false");
        assertThat(body).doesNotContain("\"age\":");
    }

    @Test
    void updateProfilePersistsAndDerivesAge() throws Exception {
        MvcResult reg = registerFull("agecheck", "agecheck@example.com", null, "password1");
        String token = tokenOf(reg);

        MvcResult updated = mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "displayName", "Age Check",
                        "dateOfBirth", "1990-05-15",
                        "country", "IN",
                        "timezone", "Asia/Kolkata",
                        "language", "en",
                        "unitSystem", "METRIC"))))
                .andReturn();
        assertThat(updated.getResponse().getStatus()).isEqualTo(200);
        String body = updated.getResponse().getContentAsString();
        assertThat(body).contains("\"displayName\":\"Age Check\"");
        assertThat(body).contains("\"country\":\"IN\"");
        assertThat(body).contains("\"age\":");

        // Invalid locale values are rejected; valid ones are untouched by others.
        MvcResult badCountry = mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"country\":\"IND\"}"))
                .andReturn();
        assertThat(badCountry.getResponse().getStatus()).isEqualTo(400);

        MvcResult badTz = mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"timezone\":\"Mars/Olympus\"}"))
                .andReturn();
        assertThat(badTz.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    void completeOnboardingRequiresVerificationAndProfile() throws Exception {
        MvcResult reg = registerFull("onboard", "onboard@example.com", null, "password1");
        String token = tokenOf(reg);

        MvcResult early = mockMvc.perform(post("/api/v1/profile/complete-onboarding")
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(early.getResponse().getStatus()).isEqualTo(400);
        assertThat(early.getResponse().getContentAsString()).contains("email verification");

        verify(token, "email", devCode(token, "EMAIL_VERIFY"));

        mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "displayName", "On Board",
                        "dateOfBirth", "1995-01-20",
                        "country", "IN",
                        "timezone", "Asia/Kolkata",
                        "unitSystem", "METRIC"))))
                .andReturn();

        MvcResult done = mockMvc.perform(post("/api/v1/profile/complete-onboarding")
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(done.getResponse().getStatus()).isEqualTo(200);
        assertThat(done.getResponse().getContentAsString()).contains("\"onboardingCompleted\":true");
        assertThat(done.getResponse().getContentAsString()).contains("\"status\":\"ACTIVE\"");
    }

    @Test
    void emailChangeRequiresOtpAndPreservesOld() throws Exception {
        MvcResult reg = registerFull("changer", "changer@example.com", null, "password1");
        String token = tokenOf(reg);
        verify(token, "email", devCode(token, "EMAIL_VERIFY"));

        // Wrong current password: rejected, nothing staged.
        MvcResult badPw = mockMvc.perform(post("/api/v1/profile/identity")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "currentPassword", "wrongpass1",
                        "email", "newmail@example.com"))))
                .andReturn();
        assertThat(badPw.getResponse().getStatus()).isEqualTo(401);

        MvcResult staged = mockMvc.perform(post("/api/v1/profile/identity")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "currentPassword", "password1",
                        "email", "newmail@example.com"))))
                .andReturn();
        assertThat(staged.getResponse().getStatus()).isEqualTo(200);

        // Old email still live and verified until confirmation.
        MvcResult before = mockMvc.perform(get("/api/v1/profile")
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(before.getResponse().getContentAsString())
                .contains("\"email\":\"changer@example.com\"");

        // Wrong code keeps the old value.
        MvcResult wrong = mockMvc.perform(post("/api/v1/profile/identity/confirm")
                .header("Authorization", "Bearer " + token)
                .param("channel", "EMAIL")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"code\":\"000000\"}"))
                .andReturn();
        assertThat(wrong.getResponse().getStatus()).isEqualTo(400);

        // Right code swaps and verifies.
        String code = devCode(token, "EMAIL_CHANGE");
        MvcResult confirmed = mockMvc.perform(post("/api/v1/profile/identity/confirm")
                .header("Authorization", "Bearer " + token)
                .param("channel", "EMAIL")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of("code", code))))
                .andReturn();
        assertThat(confirmed.getResponse().getStatus()).isEqualTo(200);
        assertThat(confirmed.getResponse().getContentAsString())
                .contains("\"email\":\"newmail@example.com\"");
        assertThat(confirmed.getResponse().getContentAsString())
                .contains("\"emailVerified\":true");

        // New email logs in.
        MvcResult login = loginAs("newmail@example.com", "password1");
        assertThat(login.getResponse().getStatus()).isEqualTo(200);
    }

    @Test
    void profileIsOwnershipScoped() throws Exception {
        MvcResult first = registerFull("ownera", "ownera@example.com", null, "password1");
        MvcResult second = registerFull("ownerb", "ownerb@example.com", null, "password1");

        MvcResult result = mockMvc.perform(get("/api/v1/profile")
                .header("Authorization", "Bearer " + tokenOf(second)))
                .andReturn();
        assertThat(result.getResponse().getContentAsString()).contains("\"username\":\"ownerb\"");
        assertThat(result.getResponse().getContentAsString()).doesNotContain("ownera");

        MvcResult unauth = mockMvc.perform(get("/api/v1/profile")).andReturn();
        assertThat(unauth.getResponse().getStatus()).isEqualTo(401);

        assertThat(tokenOf(first)).isNotEmpty();
    }
}
