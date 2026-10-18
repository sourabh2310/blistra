package com.blistra.ai;

import com.blistra.auth.AuthFlowTest;
import org.junit.jupiter.api.*;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import java.util.*;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@TestPropertySource(properties = "blistra.ai.enabled=true")
class AiEntryIntegrationTest extends AuthFlowTest {
    @MockitoBean AiGateway gateway;
    String action;
    Map<String, Object> data;
    Map<String, String> sourceOverrides;
    String token;
    String message;
    String messageOverride;

    @BeforeEach void setup() throws Exception {
        deleteAllUsers(); jdbcTemplate.execute("DELETE FROM authentication_rate_limits");
        token = tokenOf(registerFull("entryowner", "entryowner@example.com", null, "password123"));
        action = "task"; data = Map.of("title", "Exercise"); sourceOverrides = null; messageOverride = null;
        when(gateway.reply(anyList())).thenAnswer(call -> {
            List<Map<String, String>> messages = call.getArgument(0);
            boolean extract = messages.stream().anyMatch(m -> m.get("content").contains("Draft extraction mode."));
            if (!extract) return jsonMapper.writeValueAsString(Map.of("action", action, "reply", "Let's prepare your entry."));
            Map<String, String> sources = new LinkedHashMap<>();
            data.keySet().forEach(key -> sources.put(key, message));
            return jsonMapper.writeValueAsString(Map.of("data", data, "sources", sourceOverrides == null ? sources : sourceOverrides));
        });
    }

    private Map<String, Object> draft() throws Exception { return draft(null); }
    @SuppressWarnings("unchecked")
    private Map<String, Object> draft(String previous) throws Exception {
        message = messageOverride == null ? jsonMapper.writeValueAsString(data) : messageOverride;
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("chat", Map.of("message", message, "history", List.of(), "includeSummary", false));
        if (previous != null) body.put("draftId", previous);
        var result = mockMvc.perform(post("/api/v1/ai/entries/chat").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(body)))
                .andExpect(status().isOk()).andExpect(header().string("Cache-Control", "no-store")).andReturn();
        return (Map<String, Object>) jsonMapper.readValue(result.getResponse().getContentAsString(), Map.class).get("draft");
    }
    private org.springframework.test.web.servlet.ResultActions approve(Map<String, Object> d, String owner, int revision) throws Exception {
        return mockMvc.perform(post("/api/v1/ai/entries/" + d.get("id") + "/approve").header("Authorization", "Bearer " + owner)
                .contentType(MediaType.APPLICATION_JSON).content(jsonMapper.writeValueAsString(Map.of("revision", revision, "reviewed", true))));
    }
    private long taskCount() { return jdbcTemplate.queryForObject("SELECT count(*) FROM planner_task", Long.class); }

    @Test void chatOnlyCreatesDraftAndApprovalSavesExactlyOnce() throws Exception {
        var d = draft();
        assertThat(taskCount()).isZero();
        assertThat((Map<?, ?>) d.get("errors")).isEmpty();
        approve(d, token, 1).andExpect(status().isOk()).andExpect(jsonPath("$.state").value("APPLIED"))
                .andExpect(jsonPath("$.result.title").value("Exercise"));
        approve(d, token, 1).andExpect(status().isOk()).andExpect(jsonPath("$.state").value("APPLIED"));
        assertThat(taskCount()).isEqualTo(1);
    }

    @Test void missingFieldsAndMissingExplicitReviewCannotExecute() throws Exception {
        data = Map.of("description", "Exercise");
        var d = draft();
        assertThat(((Map<?, ?>) d.get("errors")).containsKey("title")).isTrue();
        approve(d, token, 1).andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/v1/ai/entries/" + d.get("id") + "/approve").header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"revision\":1,\"reviewed\":false}"))
                .andExpect(status().isBadRequest());
        assertThat(taskCount()).isZero();
    }

    @Test void editRequiresNewApprovalAndOnlyReviewedPayloadCanBeSaved() throws Exception {
        var d = draft();
        mockMvc.perform(put("/api/v1/ai/entries/" + d.get("id")).header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content("{\"revision\":1,\"data\":{\"title\":\"Walk\"}}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.revision").value(2));
        approve(d, token, 1).andExpect(status().isConflict());
        approve(d, token, 2).andExpect(status().isOk()).andExpect(jsonPath("$.result.title").value("Walk"));
        assertThat(jdbcTemplate.queryForObject("SELECT title FROM planner_task", String.class)).isEqualTo("Walk");
    }

    @Test void cancelledSupersededAndExpiredDraftsCannotExecute() throws Exception {
        var cancelled = draft();
        mockMvc.perform(post("/api/v1/ai/entries/" + cancelled.get("id") + "/cancel").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content("{\"revision\":1}" )).andExpect(status().isOk());
        approve(cancelled, token, 1).andExpect(status().isConflict());
        var old = draft(); var replacement = draft(old.get("id").toString());
        approve(old, token, 1).andExpect(status().isConflict());
        jdbcTemplate.update("UPDATE ai_entry_drafts SET expires_at=CURRENT_TIMESTAMP - INTERVAL '1 minute' WHERE id=?", UUID.fromString(replacement.get("id").toString()));
        approve(replacement, token, 1).andExpect(status().isConflict());
        assertThat(taskCount()).isZero();
    }

    @Test void anotherUserCannotReadEditApproveOrCancelADraft() throws Exception {
        var d = draft();
        String other = tokenOf(registerFull("otherentry", "otherentry@example.com", null, "password123"));
        mockMvc.perform(get("/api/v1/ai/entries/" + d.get("id")).header("Authorization", "Bearer " + other)).andExpect(status().isNotFound());
        mockMvc.perform(put("/api/v1/ai/entries/" + d.get("id")).header("Authorization", "Bearer " + other)
                .contentType(MediaType.APPLICATION_JSON).content("{\"revision\":1,\"data\":{\"title\":\"Other\"}}" )).andExpect(status().isNotFound());
        approve(d, other, 1).andExpect(status().isNotFound());
        mockMvc.perform(post("/api/v1/ai/entries/" + d.get("id") + "/cancel").header("Authorization", "Bearer " + other)
                .contentType(MediaType.APPLICATION_JSON).content("{\"revision\":1}" )).andExpect(status().isNotFound());
        mockMvc.perform(post("/api/v1/ai/entries/" + d.get("id") + "/approve").contentType(MediaType.APPLICATION_JSON)
                .content("{\"revision\":1,\"reviewed\":true}")).andExpect(status().isUnauthorized());
        assertThat(taskCount()).isZero();
    }

    @Test void concurrentApprovalsAreIdempotent() throws Exception {
        var d = draft();
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            var first = pool.submit(() -> approve(d, token, 1).andReturn().getResponse().getStatus());
            var second = pool.submit(() -> approve(d, token, 1).andReturn().getResponse().getStatus());
            assertThat(first.get(20, TimeUnit.SECONDS)).isEqualTo(200);
            assertThat(second.get(20, TimeUnit.SECONDS)).isEqualTo(200);
            assertThat(taskCount()).isEqualTo(1);
        } finally { pool.shutdownNow(); }
    }

    @Test void ungroundedModelValuesAndUnknownFieldsAreRemoved() throws Exception {
        data = Map.of("title", "Exercise", "priority", "HIGH", "ownerId", UUID.randomUUID().toString());
        sourceOverrides = Map.of("title", "Exercise", "priority", "not a user quote");
        var d = draft();
        var values = (Map<?, ?>) d.get("data");
        assertThat(values.containsKey("title")).isTrue();
        assertThat(values.containsKey("priority")).isFalse();
        assertThat(values.containsKey("ownerId")).isFalse();
        assertThat(taskCount()).isZero();
    }

    @Test void preflightChecksConditionalFieldsAndReferencesWithoutSaving() throws Exception {
        action = "measurement";
        data = Map.of("type", "BLOOD_PRESSURE", "measuredAt", "2026-10-17T08:00:00+05:30", "value", 120, "unit", "MMHG");
        var d = draft();
        assertThat((Map<?, ?>) d.get("errors")).isNotEmpty();
        approve(d, token, 1).andExpect(status().isBadRequest());
        action = "task"; data = Map.of("title", "Exercise", "taskListId", UUID.randomUUID().toString());
        var missingReference = draft();
        assertThat((Map<?, ?>) missingReference.get("errors")).isNotEmpty();
        approve(missingReference, token, 1).andExpect(status().isBadRequest());
        assertThat(taskCount()).isZero();
    }

    @Test void representativeEntriesAcrossModulesUseDomainServices() throws Exception {
        Map<String, Map<String, Object>> fixtures = new LinkedHashMap<>();
        fixtures.put("habit", Map.of("name", "Meditate", "type", "BOOLEAN"));
        fixtures.put("medicine", Map.of("name", "User supplied medicine"));
        fixtures.put("water", Map.of("amount", 250, "unit", "ml", "consumedAt", "2026-10-17T08:00:00+05:30"));
        fixtures.put("activity", Map.of("type", "WALKING", "durationMinutes", 20, "performedAt", "2026-10-17T08:00:00+05:30"));
        fixtures.put("account", Map.of("name", "Cash", "type", "CASH", "currency", "INR", "openingBalance", "0"));
        fixtures.put("reminder", Map.of("title", "Call home", "type", "GENERAL", "timezone", "Asia/Kolkata", "scheduledAt", "2099-10-18T08:00:00+05:30"));
        for (var fixture : fixtures.entrySet()) {
            action = fixture.getKey(); data = fixture.getValue();
            var d = draft();
            assertThat((Map<?, ?>) d.get("errors")).as(action).isEmpty();
            approve(d, token, 1).andExpect(status().isOk()).andExpect(jsonPath("$.state").value("APPLIED"));
        }
    }

    @Test void nestedNutritionIsNotInventedAndAnUnmentionedDateIsDropped() throws Exception {
        action = "meal";
        data = Map.of("mealType", "LUNCH", "title", "Lunch", "consumedAt", "2026-10-17T08:00:00+05:30",
                "items", List.of(Map.of("name", "Rice", "caloriesKcal", 900)));
        messageOverride = "Log LUNCH titled Lunch at 2026-10-17T08:00:00+05:30 with Rice.";
        var d = draft();
        @SuppressWarnings("unchecked") var payload = (Map<String, Object>) d.get("data");
        assertThat(jsonMapper.writeValueAsString(payload.get("items"))).contains("Rice").doesNotContain("900", "caloriesKcal");
        action = "task"; data = Map.of("title", "Exercise", "dueDate", "2099-10-18");
        messageOverride = "Add Exercise";
        var task = draft();
        assertThat(((Map<?, ?>) task.get("data")).containsKey("dueDate")).isFalse();
        assertThat(taskCount()).isZero();
    }

    @Test void catalogIsBoundedAndTypingApproveCannotCreateAnEntry() throws Exception {
        mockMvc.perform(get("/api/v1/ai/entries/catalog").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(27));
        var d = draft();
        messageOverride = "Approve this entry";
        draft(d.get("id").toString());
        assertThat(taskCount()).isZero();
    }

    @Test void changingFoodDoesNotCarryOverOldNutritionAndKeepsOtherDraftFields() throws Exception {
        action = "meal";
        data = Map.of("mealType", "LUNCH", "title", "Lunch", "consumedAt", "2026-10-17T08:00:00+05:30",
                "items", List.of(Map.of("name", "Rice", "caloriesKcal", 100)));
        var original = draft();
        data = Map.of("items", List.of(Map.of("name", "Banana")));
        messageOverride = "Change Rice to Banana";
        var revised = draft(original.get("id").toString());
        String payload = jsonMapper.writeValueAsString(revised.get("data"));
        assertThat(payload).contains("Banana", "LUNCH", "consumedAt").doesNotContain("Rice", "caloriesKcal");
    }

    @Test void aDraftCannotReferenceAnotherUsersMedicine() throws Exception {
        String other = tokenOf(registerFull("othermedicine", "othermedicine@example.com", null, "password123"));
        var medicine = mockMvc.perform(post("/api/v1/medicines").header("Authorization", "Bearer " + other)
                .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Private medicine\"}"))
                .andExpect(status().isCreated()).andReturn();
        String medicineId = jsonMapper.readTree(medicine.getResponse().getContentAsString()).path("id").asString();
        action = "dose"; data = Map.of("medicineId", medicineId, "status", "TAKEN");
        var d = draft();
        assertThat(((Map<?, ?>) d.get("errors")).containsKey("medicineId")).isTrue();
        approve(d, token, 1).andExpect(status().isBadRequest());
    }

    @Test void numericSubstringsAndUnitLettersAreNotUserEvidence() throws Exception {
        action = "water";
        data = Map.of("amount", 200, "unit", "ml", "consumedAt", "2026-10-17T08:00:00+05:30");
        messageOverride = "Log 1200 ml at 2026-10-17T08:00:00+05:30";
        var wrongAmount = draft();
        assertThat(((Map<?, ?>) wrongAmount.get("data")).containsKey("amount")).isFalse();
        data = Map.of("amount", 250, "unit", "L", "consumedAt", "2026-10-17T08:00:00+05:30");
        messageOverride = "Log 250 ml at 2026-10-17T08:00:00+05:30";
        var wrongUnit = draft();
        assertThat(((Map<?, ?>) wrongUnit.get("data")).containsKey("unit")).isFalse();
        approve(wrongUnit, token, 1).andExpect(status().isBadRequest());
    }
}
