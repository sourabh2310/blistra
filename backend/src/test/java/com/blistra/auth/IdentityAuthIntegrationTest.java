package com.blistra.auth;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class IdentityAuthIntegrationTest extends AuthFlowTest {

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    @Test
    void registerCreatesPendingAccountWithProfileAndToken() throws Exception {
        MvcResult result = registerFull("sourabh123", "user@example.com", "+919876543210",
                "password1", "Sourabh");

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .post("/api/v1/auth/register")
                .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                .content("{\"username\":\"dup_check@example.com\"}"))
                .andExpect(status().isBadRequest());

        assertThat(result.getResponse().getStatus()).isEqualTo(201);
        String body = result.getResponse().getContentAsString();
        assertThat(body).contains("\"username\":\"sourabh123\"");
        assertThat(body).contains("\"phone\":\"+919876543210\"");
        assertThat(body).contains("\"status\":\"PENDING_VERIFICATION\"");
        assertThat(body).contains("\"emailVerified\":false");
        assertThat(body).contains("\"token\":\"");
        assertThat(body).doesNotContain("password");

        // Atomic profile row with the requested display name.
        Integer profiles = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM user_profiles WHERE display_name = 'Sourabh'", Integer.class);
        assertThat(profiles).isEqualTo(1);

        // OTP rows issued for both channels.
        Integer otps = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM verification_otps WHERE consumed = false", Integer.class);
        assertThat(otps).isEqualTo(2);
    }

    @Test
    void registerRejectsDuplicateUsernameEmailPhone() throws Exception {
        assertThat(registerFull("taken", "first@example.com", "+911111111111", "password1")
                .getResponse().getStatus()).isEqualTo(201);

        // Duplicate username (case-insensitive).
        assertThat(registerFull("TAKEN", "second@example.com", "+912222222222", "password1")
                .getResponse().getStatus()).isEqualTo(409);
        // Duplicate email (case-insensitive).
        assertThat(registerFull("other", "FIRST@example.com", "+913333333333", "password1")
                .getResponse().getStatus()).isEqualTo(409);
        // Duplicate phone.
        assertThat(registerFull("third", "third@example.com", "+911111111111", "password1")
                .getResponse().getStatus()).isEqualTo(409);
    }

    @Test
    void registerRejectsBadUsernamePhonePassword() throws Exception {
        // Bad username.
        assertThat(registerFull("ab", "a@example.com", null, "password1")
                .getResponse().getStatus()).isEqualTo(400);
        // Phone without country code.
        assertThat(registerFull("validname", "b@example.com", "9876543210", "password1")
                .getResponse().getStatus()).isEqualTo(400);
        // Weak password (no digit).
        assertThat(registerFull("validname", "c@example.com", null, "passwordonly")
                .getResponse().getStatus()).isEqualTo(400);
        // Terms explicitly rejected.
        MvcResult terms = mockMvc.perform(
                org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .post("/api/v1/auth/register")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"terms\",\"email\":\"t@example.com\","
                                + "\"password\":\"password1\",\"termsAccepted\":false}"))
                .andReturn();
        assertThat(terms.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    void loginByUsernameEmailAndPhoneResolveSameAccount() throws Exception {
        MvcResult reg = registerFull("sourabh123", "user@example.com", "+919876543210", "password1");
        String id = userIdOf(reg);

        for (String identifier : new String[]{"sourabh123", "SOURABH123", "user@example.com",
                "USER@EXAMPLE.COM", "+919876543210"}) {
            MvcResult login = loginAs(identifier, "password1");
            assertThat(login.getResponse().getStatus())
                    .as("login with %s", identifier)
                    .isEqualTo(200);
            String body = login.getResponse().getContentAsString();
            assertThat(body).contains(id);
            assertThat(body).contains("\"username\":\"sourabh123\"");
        }
    }

    @Test
    void loginRejectsWrongPasswordWithoutEnumeration() throws Exception {
        registerFull("sourabh123", "user@example.com", "+919876543210", "password1");

        MvcResult wrong = loginAs("sourabh123", "wrongpass1");
        assertThat(wrong.getResponse().getStatus()).isEqualTo(401);
        assertThat(wrong.getResponse().getContentAsString()).doesNotContain("sourabh123");

        MvcResult unknown = loginAs("nosuchuser", "password1");
        assertThat(unknown.getResponse().getStatus()).isEqualTo(401);
        // Same generic code for unknown identifier vs wrong password.
        assertThat(unknown.getResponse().getContentAsString()).contains("INVALID_CREDENTIALS");
        assertThat(wrong.getResponse().getContentAsString()).contains("INVALID_CREDENTIALS");
    }

    @Test
    void legacyEmailOnlyRegistrationStillWorks() throws Exception {
        MvcResult result = mockMvc.perform(
                org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .post("/api/v1/auth/register")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"legacy@example.com\",\"password\":\"password1\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.email").value("legacy@example.com"))
                .andExpect(jsonPath("$.username").value("legacy"))
                .andReturn();
        assertThat(result.getResponse().getContentAsString()).doesNotContain("password");
    }
}
