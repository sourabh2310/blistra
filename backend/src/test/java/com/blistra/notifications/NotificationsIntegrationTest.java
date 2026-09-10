package com.blistra.notifications;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.json.JsonMapper;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Integration tests for the Notifications platform covering authentication,
 * ownership (IDOR), validation, timezone behavior, device tokens and preferences.
 */
class NotificationsIntegrationTest extends AbstractIntegrationTest {

    private static final String PREFERENCES_URL = "/api/v1/notifications/preferences";
    private static final String REMINDERS_URL = "/api/v1/notifications/reminders";
    private static final String DEVICES_URL = "/api/v1/notifications/devices";
    private static final String REGISTER_URL = "/api/v1/auth/register";
    private static final String LOGIN_URL = "/api/v1/auth/login";

    private static final String A_EMAIL = "notif-a@example.com";
    private static final String B_EMAIL = "notif-b@example.com";
    private static final String PASSWORD = "password123";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private UserRepository userRepository;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Test
    void authenticatedUserCanAccessNotificationPreferences() throws Exception {
        String token = createUserAndLogin(A_EMAIL);

        mockMvc.perform(get(PREFERENCES_URL)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(true))
                .andExpect(jsonPath("$.medicineEnabled").value(true))
                .andExpect(jsonPath("$.habitEnabled").value(true))
                .andExpect(jsonPath("$.plannerEnabled").value(true))
                .andExpect(jsonPath("$.healthEnabled").value(true))
                .andExpect(jsonPath("$.generalEnabled").value(true))
                .andExpect(jsonPath("$.hideSensitiveContent").value(false));
    }

    @Test
    void unauthenticatedUserCannotAccessNotificationApis() throws Exception {
        mockMvc.perform(get(PREFERENCES_URL)).andExpect(status().isUnauthorized());
        mockMvc.perform(put(PREFERENCES_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"enabled\":false}"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get(REMINDERS_URL)).andExpect(status().isUnauthorized());
        mockMvc.perform(post(REMINDERS_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validReminderJson(OffsetDateTime.now().plusDays(2))))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get(DEVICES_URL)).andExpect(status().isUnauthorized());
        mockMvc.perform(post(DEVICES_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deviceId\":\"d\",\"pushToken\":\"t\",\"platform\":\"ANDROID\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void userCanCreateReminder() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        OffsetDateTime scheduledAt = OffsetDateTime.now().plusDays(2).withHour(8).withMinute(0).withSecond(0).withNano(0);

        mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validReminderJson(scheduledAt)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.type").value("GENERAL"))
                .andExpect(jsonPath("$.title").value("Call the dentist"))
                .andExpect(jsonPath("$.status").value("SCHEDULED"))
                .andExpect(jsonPath("$.timezone").value("Asia/Kolkata"));
    }

    @Test
    void userCanRetrieveOwnReminder() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        String id = createReminder(token);

        mockMvc.perform(get(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.title").value("Call the dentist"));
    }

    @Test
    void userCannotRetrieveAnotherUsersReminder() throws Exception {
        String tokenA = createUserAndLogin(A_EMAIL);
        String tokenB = createUserAndLogin(B_EMAIL);
        String id = createReminder(tokenA);

        mockMvc.perform(get(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotModifyAnotherUsersReminder() throws Exception {
        String tokenA = createUserAndLogin(A_EMAIL);
        String tokenB = createUserAndLogin(B_EMAIL);
        String id = createReminder(tokenA);

        mockMvc.perform(put(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Hijacked\"}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotDeleteAnotherUsersReminder() throws Exception {
        String tokenA = createUserAndLogin(A_EMAIL);
        String tokenB = createUserAndLogin(B_EMAIL);
        String id = createReminder(tokenA);

        mockMvc.perform(delete(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound());

        mockMvc.perform(get(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SCHEDULED"));
    }

    @Test
    void userCannotManipulateAnotherUsersDeviceRegistration() throws Exception {
        String tokenA = createUserAndLogin(A_EMAIL);
        String tokenB = createUserAndLogin(B_EMAIL);

        MvcResult registerResult = mockMvc.perform(post(DEVICES_URL)
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deviceId\":\"device-a-1\",\"pushToken\":\"top-secret-token\",\"platform\":\"ANDROID\"}"))
                .andExpect(status().isOk())
                .andReturn();

        String deviceId = jsonMapper.readTree(registerResult.getResponse().getContentAsString()).get("id").asText();

        // B cannot remove A's device.
        mockMvc.perform(delete(DEVICES_URL + "/" + deviceId)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound());

        // B's list never shows A's device.
        mockMvc.perform(get(DEVICES_URL)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        // A can remove their own device.
        mockMvc.perform(delete(DEVICES_URL + "/" + deviceId)
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isNoContent());
    }

    @Test
    void clientCannotSubmitAnotherUsersIdToGainOwnership() throws Exception {
        String tokenA = createUserAndLogin(A_EMAIL);
        String tokenB = createUserAndLogin(B_EMAIL);
        UUID userIdB = userRepository.findByEmail(B_EMAIL).orElseThrow().getId();

        String body = validReminderJson(OffsetDateTime.now().plusDays(2))
                .replace("}", ",\"userId\":\"" + userIdB + "\",\"ownerId\":\"" + userIdB + "\"}");

        MvcResult result = mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        assertThat(responseBody).doesNotContain("userId");
        assertThat(responseBody).doesNotContain("ownerId");

        String id = jsonMapper.readTree(responseBody).get("id").asText();

        // The reminder is owned by A (creator), not by the id that was submitted.
        mockMvc.perform(get(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + tokenA))
                .andExpect(status().isOk());
        mockMvc.perform(get(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isNotFound());
    }

    @Test
    void invalidReminderTimeIsRejected() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        OffsetDateTime past = OffsetDateTime.now().minusMinutes(5);

        mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validReminderJson(past)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REMINDER_TIME"));
    }

    @Test
    void invalidReminderDataIsRejected() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        String futureBody = validReminderJson(OffsetDateTime.now().plusDays(2));

        // Missing title.
        mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"GENERAL\",\"scheduledAt\":\"" + OffsetDateTime.now().plusDays(2) + "\",\"timezone\":\"Asia/Kolkata\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        // Domain-generated type cannot be created by the client.
        mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(futureBody.replace("\"GENERAL\"", "\"MEDICINE\"")))
                .andExpect(status().isBadRequest());

        // Invalid timezone.
        mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(futureBody.replace("Asia/Kolkata", "Mars/Olympus")))
                .andExpect(status().isBadRequest());

        // Missing timezone.
        mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"GENERAL\",\"title\":\"X\",\"scheduledAt\":\"" + OffsetDateTime.now().plusDays(2) + "\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        // Scheduled time without offset is malformed.
        mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"GENERAL\",\"title\":\"X\",\"scheduledAt\":\"2030-01-01T08:00:00\",\"timezone\":\"Asia/Kolkata\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("MALFORMED_REQUEST"));
    }

    @Test
    void notificationPreferencesAreUserScoped() throws Exception {
        String tokenA = createUserAndLogin(A_EMAIL);
        String tokenB = createUserAndLogin(B_EMAIL);

        mockMvc.perform(put(PREFERENCES_URL)
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"enabled\":false,\"medicineEnabled\":false,\"hideSensitiveContent\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(false))
                .andExpect(jsonPath("$.medicineEnabled").value(false))
                .andExpect(jsonPath("$.hideSensitiveContent").value(true));

        // B's defaults are completely unaffected by A's changes.
        mockMvc.perform(get(PREFERENCES_URL)
                        .header("Authorization", "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(true))
                .andExpect(jsonPath("$.medicineEnabled").value(true))
                .andExpect(jsonPath("$.hideSensitiveContent").value(false));
    }

    @Test
    void preferenceChangesArePersisted() throws Exception {
        String token = createUserAndLogin(A_EMAIL);

        mockMvc.perform(put(PREFERENCES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"generalEnabled\":false,\"plannerEnabled\":false,\"healthEnabled\":false,\"hideSensitiveContent\":true}"))
                .andExpect(status().isOk());

        // A fresh read reflects the persisted state.
        mockMvc.perform(get(PREFERENCES_URL)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.generalEnabled").value(false))
                .andExpect(jsonPath("$.plannerEnabled").value(false))
                .andExpect(jsonPath("$.healthEnabled").value(false))
                .andExpect(jsonPath("$.hideSensitiveContent").value(true))
                .andExpect(jsonPath("$.enabled").value(true));
    }

    @Test
    void cancelledRemindersAreNotTreatedAsActive() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        String id = createReminder(token);

        mockMvc.perform(delete(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        // Cancelled reminder is still retrievable by id with status CANCELLED.
        mockMvc.perform(get(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));

        // Default list only includes SCHEDULED reminders.
        mockMvc.perform(get(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        // status=ALL includes the cancelled reminder.
        mockMvc.perform(get(REMINDERS_URL + "?status=ALL")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value("CANCELLED"));

        // Cancelling again is idempotent.
        mockMvc.perform(delete(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());
    }

    @Test
    void updatingCancelledReminderIsRejected() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        String id = createReminder(token);

        mockMvc.perform(delete(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mockMvc.perform(put(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Updated\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("REMINDER_STATE_CONFLICT"));
    }

    @Test
    void reminderCanBeUpdated() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        String id = createReminder(token);
        OffsetDateTime newTime = OffsetDateTime.now().plusDays(5).withHour(9).withMinute(30);

        mockMvc.perform(put(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Updated title\",\"body\":\"New body\","
                                + "\"scheduledAt\":\"" + newTime + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Updated title"))
                .andExpect(jsonPath("$.body").value("New body"))
                .andExpect(jsonPath("$.status").value("SCHEDULED"));

        // No fields provided -> 400.
        mockMvc.perform(put(REMINDERS_URL + "/" + id)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void timezoneBehaviorPreservesTheIntendedInstant() throws Exception {
        String token = createUserAndLogin(A_EMAIL);

        // 8:00 AM in Asia/Kolkata (UTC+05:30) = 02:30 UTC.
        OffsetDateTime kolkataTime = OffsetDateTime.of(
                2030, 6, 15, 8, 0, 0, 0, ZoneOffset.ofHoursMinutes(5, 30));
        Instant expectedInstant = kolkataTime.toInstant();

        MvcResult result = mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"GENERAL\",\"title\":\"Timezone test\","
                                + "\"scheduledAt\":\"" + kolkataTime + "\",\"timezone\":\"Asia/Kolkata\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.timezone").value("Asia/Kolkata"))
                .andReturn();

        String scheduledAt = jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("scheduledAt").asText();
        Instant storedInstant = OffsetDateTime.parse(scheduledAt).toInstant();
        assertThat(storedInstant).isEqualTo(expectedInstant);
    }

    @Test
    void deviceTokenIsNeverReturnedThroughApis() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        String secretToken = "push-token-please-do-not-expose";

        MvcResult registerResult = mockMvc.perform(post(DEVICES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deviceId\":\"device-secure-1\",\"pushToken\":\"" + secretToken + "\",\"platform\":\"ANDROID\"}"))
                .andExpect(status().isOk())
                .andReturn();

        assertThat(registerResult.getResponse().getContentAsString()).doesNotContain(secretToken);
        assertThat(registerResult.getResponse().getContentAsString()).doesNotContain("pushToken");

        MvcResult listResult = mockMvc.perform(get(DEVICES_URL)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();

        assertThat(listResult.getResponse().getContentAsString()).doesNotContain(secretToken);
        assertThat(listResult.getResponse().getContentAsString()).doesNotContain("pushToken");
    }

    @Test
    void repeatedDeviceRegistrationUpsertsInsteadOfDuplicating() throws Exception {
        String token = createUserAndLogin(A_EMAIL);

        mockMvc.perform(post(DEVICES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deviceId\":\"device-upsert-1\",\"pushToken\":\"token-v1\",\"platform\":\"ANDROID\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post(DEVICES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"deviceId\":\"device-upsert-1\",\"pushToken\":\"token-v2\",\"platform\":\"ANDROID\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(get(DEVICES_URL)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void sensitiveFieldsAreNotExposed() throws Exception {
        String token = createUserAndLogin(A_EMAIL);
        String reminderId = createReminder(token);

        MvcResult result = mockMvc.perform(get(REMINDERS_URL + "/" + reminderId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).doesNotContain("userId");
        assertThat(body).doesNotContain("ownerId");
        assertThat(body).doesNotContain("pushToken");
        assertThat(body).doesNotContain("password");
    }

    @Test
    void listFilterAcceptsOnlyKnownStatuses() throws Exception {
        String token = createUserAndLogin(A_EMAIL);

        mockMvc.perform(get(REMINDERS_URL + "?status=NONSENSE")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());
    }

    // ----------------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------------

    private String createUserAndLogin(String email) throws Exception {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .email(email)
                .password(PASSWORD)
                .build();
        mockMvc.perform(post(REGISTER_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(registerRequest)))
                .andExpect(status().isCreated());

        LoginRequest loginRequest = LoginRequest.builder()
                .email(email)
                .password(PASSWORD)
                .build();
        MvcResult loginResult = mockMvc.perform(post(LOGIN_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();

        String body = loginResult.getResponse().getContentAsString();
        return jsonMapper.readTree(body).get("token").asText();
    }

    private String createReminder(String token) throws Exception {
        OffsetDateTime scheduledAt = OffsetDateTime.now().plusDays(2).withHour(8).withMinute(0).withSecond(0).withNano(0);
        MvcResult result = mockMvc.perform(post(REMINDERS_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validReminderJson(scheduledAt)))
                .andExpect(status().isCreated())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText();
    }

    private String validReminderJson(OffsetDateTime scheduledAt) {
        return "{\"type\":\"GENERAL\",\"title\":\"Call the dentist\",\"body\":\"Call the clinic\","
                + "\"scheduledAt\":\"" + scheduledAt + "\",\"timezone\":\"Asia/Kolkata\"}";
    }
}