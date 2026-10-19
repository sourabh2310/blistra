package com.blistra.profile;

import com.blistra.auth.AuthFlowTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

/** Profile photo, extended profile fields, privacy switch and account deletion. */
class ProfileHubIntegrationTest extends AuthFlowTest {

    private static final byte[] PNG = {
            (byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D, 'I', 'H', 'D', 'R'};

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    @Test
    void extendedFieldsSaveClearAndValidate() throws Exception {
        String token = tokenOf(registerFull("hubuser", "hubuser@example.com", null, "password1"));

        MvcResult saved = mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(Map.of(
                        "bio", "  Runner and reader  ",
                        "gender", "FEMALE",
                        "emergencyContactName", "Asha",
                        "emergencyContactPhone", "+91 98765 43210",
                        "emergencyContactRelation", "Sister"))))
                .andReturn();
        assertThat(saved.getResponse().getStatus()).isEqualTo(200);
        String body = saved.getResponse().getContentAsString();
        assertThat(body).contains("\"bio\":\"Runner and reader\"");
        assertThat(body).contains("\"gender\":\"FEMALE\"");
        assertThat(body).contains("\"emergencyContactPhone\":\"+919876543210\"");
        assertThat(body).contains("\"allowFriendRequests\":true");
        assertThat(body).contains("\"hasAvatar\":false");
        assertThat(body).contains("\"memberSince\":");

        MvcResult cleared = mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"bio\":\"\",\"gender\":\"\"}"))
                .andReturn();
        assertThat(cleared.getResponse().getContentAsString())
                .doesNotContain("\"bio\":").doesNotContain("\"gender\":");

        MvcResult badPhone = mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"emergencyContactPhone\":\"call me\"}"))
                .andReturn();
        assertThat(badPhone.getResponse().getStatus()).isEqualTo(400);

        MvcResult badGender = mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"gender\":\"ROBOT\"}"))
                .andReturn();
        assertThat(badGender.getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    void avatarUploadDownloadAndRemove() throws Exception {
        String token = tokenOf(registerFull("photoed", "photoed@example.com", null, "password1"));

        MvcResult rejected = mockMvc.perform(multipart("/api/v1/profile/avatar")
                .file(new MockMultipartFile("file", "x.png", "image/png", "not an image".getBytes()))
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(rejected.getResponse().getStatus()).isEqualTo(400);

        MvcResult uploaded = mockMvc.perform(multipart("/api/v1/profile/avatar")
                .file(new MockMultipartFile("file", "me.png", "application/octet-stream", PNG))
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(uploaded.getResponse().getStatus()).isEqualTo(200);
        assertThat(uploaded.getResponse().getContentAsString())
                .contains("\"hasAvatar\":true").contains("\"avatarVersion\":");

        MvcResult image = mockMvc.perform(get("/api/v1/profile/avatar")
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(image.getResponse().getStatus()).isEqualTo(200);
        assertThat(image.getResponse().getContentType()).isEqualTo("image/png");
        assertThat(image.getResponse().getContentAsByteArray()).isEqualTo(PNG);

        MvcResult removed = mockMvc.perform(delete("/api/v1/profile/avatar")
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(removed.getResponse().getContentAsString()).contains("\"hasAvatar\":false");

        MvcResult gone = mockMvc.perform(get("/api/v1/profile/avatar")
                .header("Authorization", "Bearer " + token))
                .andReturn();
        assertThat(gone.getResponse().getStatus()).isEqualTo(404);
    }

    @Test
    void friendRequestsCanBeTurnedOff() throws Exception {
        String alice = tokenOf(registerFull("alicehub", "alicehub@example.com", null, "password1"));
        String bob = tokenOf(registerFull("bobhub", "bobhub@example.com", null, "password1"));

        mockMvc.perform(put("/api/v1/profile")
                .header("Authorization", "Bearer " + bob)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"allowFriendRequests\":false}"))
                .andReturn();

        MvcResult blocked = mockMvc.perform(post("/api/v1/finance/friends")
                .header("Authorization", "Bearer " + alice)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"username\":\"bobhub\"}"))
                .andReturn();
        assertThat(blocked.getResponse().getStatus()).isEqualTo(400);
        assertThat(blocked.getResponse().getContentAsString()).contains("isn't accepting friend requests");
    }

    @Test
    void deleteAccountNeedsPasswordAndDeactivatesUser() throws Exception {
        MvcResult reg = registerFull("leaver", "leaver@example.com", null, "password1");
        String token = tokenOf(reg);
        UUID id = UUID.fromString(userIdOf(reg));

        MvcResult wrong = mockMvc.perform(post("/api/v1/profile/delete-account")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"currentPassword\":\"nope12345\"}"))
                .andReturn();
        assertThat(wrong.getResponse().getStatus()).isEqualTo(400);

        MvcResult missing = mockMvc.perform(post("/api/v1/profile/delete-account")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andReturn();
        assertThat(missing.getResponse().getStatus()).isEqualTo(400);

        MvcResult ok = mockMvc.perform(post("/api/v1/profile/delete-account")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"currentPassword\":\"password1\"}"))
                .andReturn();
        assertThat(ok.getResponse().getStatus()).isEqualTo(204);

        // The row and its profile are kept, but inactive and anonymised.
        Map<String, Object> row = jdbcTemplate.queryForMap(
                "SELECT username, email, status FROM users WHERE id = ?", id);
        assertThat(row.get("status")).isEqualTo("INACTIVE");
        assertThat(row.get("username").toString()).startsWith("deleted_");
        assertThat(row.get("email").toString()).doesNotContain("leaver");
        assertThat(jdbcTemplate.queryForObject(
                "SELECT display_name FROM user_profiles WHERE user_id = ?",
                String.class, id)).isEqualTo("Deleted user");

        // It can no longer sign in, and the old session is dead.
        assertThat(loginAs("leaver@example.com", "password1").getResponse().getStatus())
                .isEqualTo(401);
        assertThat(mockMvc.perform(get("/api/v1/profile")
                        .header("Authorization", "Bearer " + token))
                .andReturn().getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void deactivatedUserCanRegisterAgainWithTheSameDetails() throws Exception {
        MvcResult first = registerFull("leaver", "leaver@example.com", "+919876543210", "password1");
        mockMvc.perform(post("/api/v1/profile/delete-account")
                .header("Authorization", "Bearer " + tokenOf(first))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"currentPassword\":\"password1\"}"));

        MvcResult again = registerFull("leaver", "leaver@example.com", "+919876543210", "password2");

        assertThat(again.getResponse().getStatus()).isEqualTo(201);
        assertThat(userIdOf(again)).isNotEqualTo(userIdOf(first));
        assertThat(loginAs("leaver@example.com", "password2").getResponse().getStatus())
                .isEqualTo(200);
        assertThat(loginAs("leaver@example.com", "password1").getResponse().getStatus())
                .isEqualTo(401);
    }

    @Test
    void deactivationKeepsSharedExpensesForFriends() throws Exception {
        MvcResult regA = registerFull("sharera", "sharera@example.com", null, "password1");
        MvcResult regB = registerFull("sharerb", "sharerb@example.com", null, "password1");
        UUID a = UUID.fromString(userIdOf(regA));
        UUID b = UUID.fromString(userIdOf(regB));
        UUID expense = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO finance_expenses (id, created_by, paid_by, description, category,
                    amount, currency, spent_on, split_type)
                VALUES (?, ?, ?, 'Dinner', 'FOOD', 100, 'INR', CURRENT_DATE, 'EQUAL')""",
                expense, a, a);
        jdbcTemplate.update("INSERT INTO finance_expense_shares (expense_id, user_id, amount) VALUES (?, ?, 50)",
                expense, a);
        jdbcTemplate.update("INSERT INTO finance_expense_shares (expense_id, user_id, amount) VALUES (?, ?, 50)",
                expense, b);

        MvcResult ok = mockMvc.perform(post("/api/v1/profile/delete-account")
                .header("Authorization", "Bearer " + tokenOf(regA))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"currentPassword\":\"password1\"}"))
                .andReturn();
        assertThat(ok.getResponse().getStatus()).isEqualTo(204);

        Integer shares = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM finance_expense_shares WHERE expense_id = ?", Integer.class, expense);
        assertThat(shares).isEqualTo(2);
    }
}
