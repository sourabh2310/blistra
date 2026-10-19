package com.blistra.auth;

import com.blistra.auth.google.GoogleIdTokenVerifier;
import com.blistra.auth.google.GoogleIdentity;
import com.blistra.common.exception.InvalidCredentialsException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

@org.springframework.test.context.TestPropertySource(properties = {
        "blistra.security.require-terms=true"})
class GoogleLoginIntegrationTest extends AuthFlowTest {

    @MockitoBean
    GoogleIdTokenVerifier verifier;

    @BeforeEach
    void setUp() {
        deleteAllUsers();
        when(verifier.isConfigured()).thenReturn(true);
    }

    private void google(String sub, String email, boolean verified, String name) {
        when(verifier.verify(anyString()))
                .thenReturn(new GoogleIdentity(sub, email, verified, name));
    }

    private MvcResult signIn(Boolean termsAccepted) throws Exception {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("idToken", "token");
        if (termsAccepted != null) {
            body.put("termsAccepted", termsAccepted);
        }
        return mockMvc.perform(post("/api/v1/auth/google")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(body)))
                .andReturn();
    }

    private JsonNode json(MvcResult result) throws Exception {
        return jsonMapper.readTree(result.getResponse().getContentAsString());
    }

    @Test
    void newGoogleUserGetsVerifiedActiveAccountWithProfile() throws Exception {
        google("sub-1", "Jane.Doe@Example.com", true, "Jane Doe");

        MvcResult result = signIn(true);

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        JsonNode body = json(result);
        assertThat(body.get("token").asString()).isNotBlank();
        JsonNode user = body.get("user");
        assertThat(user.get("email").asString()).isEqualTo("jane.doe@example.com");
        assertThat(user.get("emailVerified").asBoolean()).isTrue();
        assertThat(user.get("onboardingCompleted").asBoolean()).isFalse();
        assertThat(user.get("status").asString()).isEqualTo("ACTIVE");
        assertThat(jdbcTemplate.queryForObject(
                "SELECT display_name FROM user_profiles WHERE user_id = ?::uuid",
                String.class, user.get("id").asString())).isEqualTo("Jane Doe");
    }

    @Test
    void repeatSignInReturnsTheSameAccountEvenWithoutTerms() throws Exception {
        google("sub-1", "jane@example.com", true, "Jane");
        String first = json(signIn(true)).get("user").get("id").asString();

        MvcResult again = signIn(null);

        assertThat(again.getResponse().getStatus()).isEqualTo(200);
        assertThat(json(again).get("user").get("id").asString()).isEqualTo(first);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users", Integer.class)).isEqualTo(1);
    }

    @Test
    void newAccountRequiresTermsAcceptance() throws Exception {
        google("sub-1", "jane@example.com", true, "Jane");

        assertThat(signIn(null).getResponse().getStatus()).isEqualTo(400);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM users", Integer.class)).isZero();
    }

    @Test
    void linksToExistingVerifiedPasswordAccount() throws Exception {
        MvcResult registered = registerFull("jane", "jane@example.com", null, "password1");
        String token = tokenOf(registered);
        verify(token, "email", devCode(token, "EMAIL_VERIFY"));
        google("sub-1", "jane@example.com", true, "Jane");

        MvcResult result = signIn(true);

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        assertThat(json(result).get("user").get("id").asString())
                .isEqualTo(userIdOf(registered));
        assertThat(loginAs("jane@example.com", "password1").getResponse().getStatus())
                .isEqualTo(200);
    }

    @Test
    void linkingAnUnverifiedAccountLocksOutTheOriginalRegistrant() throws Exception {
        MvcResult registered = registerFull("jane", "jane@example.com", null, "password1");
        String squatterToken = tokenOf(registered);
        google("sub-1", "jane@example.com", true, "Jane");

        MvcResult result = signIn(true);

        assertThat(result.getResponse().getStatus()).isEqualTo(200);
        assertThat(json(result).get("user").get("emailVerified").asBoolean()).isTrue();
        assertThat(loginAs("jane@example.com", "password1").getResponse().getStatus())
                .isEqualTo(401);
        assertThat(mockMvc.perform(
                        org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                                .get("/api/v1/profile")
                                .header("Authorization", "Bearer " + squatterToken))
                .andReturn().getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void rejectsUnverifiedGoogleEmail() throws Exception {
        google("sub-1", "jane@example.com", false, "Jane");

        assertThat(signIn(true).getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void rejectsAnInvalidToken() throws Exception {
        when(verifier.verify(anyString()))
                .thenThrow(new InvalidCredentialsException("Google sign-in failed"));

        assertThat(signIn(true).getResponse().getStatus()).isEqualTo(401);
    }

    private MvcResult deleteAccount(String bearer, String body) throws Exception {
        return mockMvc.perform(post("/api/v1/profile/delete-account")
                        .header("Authorization", "Bearer " + bearer)
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content(body))
                .andReturn();
    }

    @Test
    void googleAccountDeactivatesWithAFreshGoogleTokenAndCanSignUpAgain() throws Exception {
        google("sub-1", "jane@example.com", true, "Jane");
        JsonNode first = json(signIn(true));
        String oldId = first.get("user").get("id").asString();
        assertThat(profileGoogleLinked(first.get("token").asString())).isTrue();

        MvcResult done = deleteAccount(first.get("token").asString(), "{\"googleIdToken\":\"fresh\"}");

        assertThat(done.getResponse().getStatus()).isEqualTo(204);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT status FROM users WHERE id = ?::uuid", String.class, oldId))
                .isEqualTo("INACTIVE");
        MvcResult again = signIn(true);
        assertThat(again.getResponse().getStatus()).isEqualTo(200);
        assertThat(json(again).get("user").get("id").asString()).isNotEqualTo(oldId);
        assertThat(json(again).get("user").get("email").asString()).isEqualTo("jane@example.com");
    }

    @Test
    void googleDeactivationRejectsADifferentGoogleAccountAndAPasswordGuess() throws Exception {
        google("sub-1", "jane@example.com", true, "Jane");
        String token = json(signIn(true)).get("token").asString();

        google("someone-else", "other@example.com", true, "Other");
        assertThat(deleteAccount(token, "{\"googleIdToken\":\"fresh\"}")
                .getResponse().getStatus()).isEqualTo(400);
        assertThat(deleteAccount(token, "{\"currentPassword\":\"guess1234\"}")
                .getResponse().getStatus()).isEqualTo(400);
        assertThat(jdbcTemplate.queryForObject(
                "SELECT status FROM users WHERE google_sub = 'sub-1'", String.class))
                .isEqualTo("ACTIVE");
    }

    private boolean profileGoogleLinked(String bearer) throws Exception {
        MvcResult result = mockMvc.perform(
                        org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                                .get("/api/v1/profile")
                                .header("Authorization", "Bearer " + bearer))
                .andReturn();
        return json(result).get("googleLinked").asBoolean();
    }

    @Test
    void reportsUnavailableWhenGoogleIsNotConfigured() throws Exception {
        when(verifier.isConfigured()).thenReturn(false);

        assertThat(signIn(true).getResponse().getStatus()).isEqualTo(503);
    }
}
