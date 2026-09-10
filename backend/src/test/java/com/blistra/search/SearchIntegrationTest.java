package com.blistra.search;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end regression tests for unified search against real PostgreSQL.
 *
 * <p>Covers every module branch of the UNION query, user isolation, from/to
 * filtering, database-level totals, OFFSET pagination, deterministic ordering,
 * invalid modules and empty results. Data is inserted with plain SQL so the
 * test exercises the repository SQL (not the module APIs) plus the
 * service/controller wiring.
 */
class SearchIntegrationTest extends AbstractIntegrationTest {

    private static final String SEARCH_URL = "/api/v1/search";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @BeforeEach
    void cleanDatabase() {
        deleteAllUsers();
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    private String registerAndLogin(String email) throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(RegisterRequest.builder()
                        .email(email).password("password123").build())))
                .andExpect(status().isCreated());
        MvcResult login = mockMvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(jsonMapper.writeValueAsString(LoginRequest.builder()
                        .email(email).password("password123").build())))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(login.getResponse().getContentAsString()).get("token").asText();
    }

    private UUID userIdOf(String email) {
        return jdbcTemplate.queryForObject("SELECT id FROM users WHERE email = ?", UUID.class, email);
    }

    private JsonNode search(String token, String q, String type, String from, String to,
                            Integer page, Integer size) throws Exception {
        StringBuilder url = new StringBuilder(SEARCH_URL).append("?q=").append(q);
        if (type != null) {
            url.append("&type=").append(type);
        }
        if (from != null) {
            url.append("&from=").append(from);
        }
        if (to != null) {
            url.append("&to=").append(to);
        }
        if (page != null) {
            url.append("&page=").append(page);
        }
        if (size != null) {
            url.append("&size=").append(size);
        }
        var action = mockMvc.perform(get(url.toString())
                .header("Authorization", "Bearer " + token));
        MvcResult result = action.andExpect(status().isOk()).andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString());
    }

    private static Timestamp ts(String isoLocal) {
        return Timestamp.valueOf(LocalDateTime.parse(isoLocal));
    }

    private static OffsetDateTime odt(String iso) {
        return OffsetDateTime.parse(iso);
    }

    /**
     * Seeds one searchable row per UNION branch for the given user. All rows
     * share the marker term so a single query can span every module.
     */
    private void seedAllModules(UUID userId, String marker) {
        // PLANNER
        UUID listId = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO planner_task_list (id, user_id, name, description, created_at) VALUES (?, ?, ?, ?, ?)",
                listId, userId, marker + " list Alpha", marker + " list", ts("2026-09-01T10:00:00"));
        jdbcTemplate.update(
                "INSERT INTO planner_task (id, user_id, list_id, title, description, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, listId, marker + " task One", marker + " task", ts("2026-09-02T10:00:00"));
        jdbcTemplate.update(
                "INSERT INTO planner_event (id, user_id, title, description, location, start_at, end_at, created_at)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, marker + " summit", marker + " event", marker + " hall",
                odt("2026-09-03T10:00:00Z"), odt("2026-09-03T11:00:00Z"), ts("2026-09-03T10:00:00"));

        // MEDICINES
        jdbcTemplate.update(
                "INSERT INTO medicines (id, user_id, name, generic_name, notes, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, marker + "cillin", marker + "mycin", marker + " meds",
                ts("2026-09-04T10:00:00"));

        // HEALTH
        jdbcTemplate.update(
                "INSERT INTO health_events (id, user_id, type, title, occurred_at, notes) VALUES (?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, "CHECKUP", marker + " checkup", odt("2026-09-05T10:00:00Z"),
                marker + " event");
        jdbcTemplate.update(
                "INSERT INTO health_appointments (id, user_id, title, scheduled_at, location, notes)"
                        + " VALUES (?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, marker + " dentist", odt("2026-09-06T10:00:00Z"),
                marker + " clinic", marker + " appointment");
        jdbcTemplate.update(
                "INSERT INTO health_symptom_logs (id, user_id, title, description, observed_at, notes)"
                        + " VALUES (?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, marker + " headache", marker + " symptom",
                odt("2026-09-07T10:00:00Z"), marker + " symptom note");
        jdbcTemplate.update(
                "INSERT INTO health_activities (id, user_id, type, performed_at, duration_minutes, notes)"
                        + " VALUES (?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, "OTHER", odt("2026-09-08T10:00:00Z"), 30, marker + " jog");
        jdbcTemplate.update(
                "INSERT INTO health_measurements (id, user_id, type, measured_at, value, unit, notes)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, "WEIGHT", odt("2026-09-09T10:00:00Z"),
                new java.math.BigDecimal("70.50"), "KG", marker + " scale");
        jdbcTemplate.update(
                "INSERT INTO health_sleep_records (id, user_id, started_at, ended_at, notes)"
                        + " VALUES (?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, odt("2026-09-10T22:00:00Z"), odt("2026-09-11T06:00:00Z"),
                marker + " deep rest");

        // DIET
        UUID mealId = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO meals (id, user_id, meal_type, title, notes, consumed_at) VALUES (?, ?, ?, ?, ?, ?)",
                mealId, userId, "BREAKFAST", marker + " breakfast bowl", marker + " meal",
                odt("2026-09-11T08:00:00Z"));
        jdbcTemplate.update(
                "INSERT INTO meal_items (id, meal_id, name, notes, created_at) VALUES (?, ?, ?, ?, ?)",
                UUID.randomUUID(), mealId, marker + " oats", marker + " item", ts("2026-09-11T08:05:00"));
        jdbcTemplate.update(
                "INSERT INTO diet_profiles (id, user_id, dietary_preference, notes, created_at)"
                        + " VALUES (?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, "VEGAN", marker + " vegan", ts("2026-09-11T09:00:00"));
        jdbcTemplate.update(
                "INSERT INTO water_intake (id, user_id, amount, unit, consumed_at) VALUES (?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, new java.math.BigDecimal("250.00"), "ml",
                odt("2026-09-11T10:00:00Z"));

        // HABITS
        jdbcTemplate.update(
                "INSERT INTO habits (id, user_id, name, description, type, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, marker + " meditation", marker + " habit", "BOOLEAN",
                ts("2026-09-12T10:00:00"));

        // FINANCE
        UUID accountId = UUID.randomUUID();
        UUID account2Id = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO finance_accounts (id, user_id, name, type, currency, opening_balance, created_at)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?)",
                accountId, userId, marker + " vault", "CASH", "USD", new java.math.BigDecimal("0.0000"),
                ts("2026-09-13T10:00:00"));
        jdbcTemplate.update(
                "INSERT INTO finance_accounts (id, user_id, name, type, currency, opening_balance, created_at)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?)",
                account2Id, userId, marker + " reserve", "BANK", "USD", new java.math.BigDecimal("0.0000"),
                ts("2026-09-13T11:00:00"));
        UUID categoryId = UUID.randomUUID();
        jdbcTemplate.update(
                "INSERT INTO finance_categories (id, user_id, name, type, created_at) VALUES (?, ?, ?, ?, ?)",
                categoryId, userId, marker + " snacks", "EXPENSE", ts("2026-09-13T12:00:00"));
        jdbcTemplate.update(
                "INSERT INTO finance_transactions (id, user_id, account_id, category_id, type, amount, currency,"
                        + " occurred_at, description, notes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, accountId, categoryId, "EXPENSE", new java.math.BigDecimal("5.0000"),
                "USD", LocalDate.parse("2026-09-14"), marker + " groceries", marker + " txn");
        jdbcTemplate.update(
                "INSERT INTO finance_transfers (id, user_id, source_account_id, destination_account_id, amount,"
                        + " currency, transferred_at, note) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, accountId, account2Id, new java.math.BigDecimal("10.0000"), "USD",
                LocalDate.parse("2026-09-15"), marker + " rent move");

        // DOCUMENTS
        jdbcTemplate.update(
                "INSERT INTO documents (id, user_id, original_filename, stored_object_key, content_type,"
                        + " file_size, content_hash, category, description, created_at)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                UUID.randomUUID(), userId, marker + " lab report.pdf", UUID.randomUUID().toString(),
                "application/pdf", 1024L,
                "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
                "REPORT", marker + " upload", ts("2026-09-16T10:00:00"));
    }

    // ------------------------------------------------------------------
    // module coverage: every result route
    // ------------------------------------------------------------------

    @Test
    void plannerModuleReturnsAllResultTypesWithRoutes() throws Exception {
        String token = registerAndLogin("search-planner@example.com");
        seedAllModules(userIdOf("search-planner@example.com"), "zqx-planner");

        JsonNode body = search(token, "zqx-planner", "PLANNER", null, null, 0, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(3);
        Set<String> routes = routesOf(body);
        assertThat(routes).anyMatch(r -> r.startsWith("planner/task/"));
        assertThat(routes).anyMatch(r -> r.startsWith("planner/list/"));
        assertThat(routes).anyMatch(r -> r.startsWith("planner/event/"));
        assertThat(body.get("results").get(0).get("module").asText()).isEqualTo("PLANNER");
    }

    @Test
    void medicinesModuleReturnsMedicineRoute() throws Exception {
        String token = registerAndLogin("search-meds@example.com");
        seedAllModules(userIdOf("search-meds@example.com"), "zqx-meds");

        JsonNode body = search(token, "zqx-medscillin", "MEDICINES", null, null, 0, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(1);
        JsonNode row = body.get("results").get(0);
        assertThat(row.get("module").asText()).isEqualTo("MEDICINES");
        assertThat(row.get("type").asText()).isEqualTo("MEDICINE");
        assertThat(row.get("route").asText()).startsWith("medicines/");
        assertThat(row.get("title").asText()).contains("zqx-meds");
    }

    @Test
    void healthModuleReturnsAllResultTypesWithRoutes() throws Exception {
        String token = registerAndLogin("search-health@example.com");
        seedAllModules(userIdOf("search-health@example.com"), "zqx-health");

        JsonNode body = search(token, "zqx-health", "HEALTH", null, null, 0, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(6);
        Set<String> routes = routesOf(body);
        assertThat(routes).anyMatch(r -> r.startsWith("health/event/"));
        assertThat(routes).anyMatch(r -> r.startsWith("health/appointment/"));
        assertThat(routes).anyMatch(r -> r.startsWith("health/symptom/"));
        assertThat(routes).anyMatch(r -> r.startsWith("health/activity/"));
        assertThat(routes).anyMatch(r -> r.startsWith("health/measurement/"));
        assertThat(routes).anyMatch(r -> r.startsWith("health/sleep/"));
    }

    @Test
    void dietModuleReturnsAllResultTypesWithRoutes() throws Exception {
        String token = registerAndLogin("search-diet@example.com");
        seedAllModules(userIdOf("search-diet@example.com"), "zqx-diet");

        JsonNode body = search(token, "zqx-diet", "DIET", null, null, 0, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(3);
        Set<String> routes = routesOf(body);
        assertThat(routes).anyMatch(r -> r.startsWith("diet/meal/") && !r.contains("/item/"));
        assertThat(routes).anyMatch(r -> r.startsWith("diet/meal/item/"));
        assertThat(routes).contains("diet/profile");
    }

    @Test
    void dietWaterIntakeMatchesTitleQuery() throws Exception {
        String token = registerAndLogin("search-water@example.com");
        seedAllModules(userIdOf("search-water@example.com"), "zqx-water");

        // "water" matches no stored column value; it must match the constant title.
        JsonNode body = search(token, "water", "DIET", null, null, 0, 50);

        Set<String> routes = routesOf(body);
        assertThat(routes).anyMatch(r -> r.startsWith("diet/water/"));
    }

    @Test
    void habitsModuleReturnsHabitRoute() throws Exception {
        String token = registerAndLogin("search-habits@example.com");
        seedAllModules(userIdOf("search-habits@example.com"), "zqx-habits");

        JsonNode body = search(token, "zqx-habits", "HABITS", null, null, 0, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(1);
        JsonNode row = body.get("results").get(0);
        assertThat(row.get("module").asText()).isEqualTo("HABITS");
        assertThat(row.get("type").asText()).isEqualTo("HABIT");
        assertThat(row.get("route").asText()).startsWith("habits/");
    }

    @Test
    void financeModuleReturnsAllResultTypesWithRoutes() throws Exception {
        String token = registerAndLogin("search-finance@example.com");
        seedAllModules(userIdOf("search-finance@example.com"), "zqx-finance");

        JsonNode body = search(token, "zqx-finance", "FINANCE", null, null, 0, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(5);
        Set<String> routes = routesOf(body);
        assertThat(routes).anyMatch(r -> r.startsWith("finance/accounts/"));
        assertThat(routes).anyMatch(r -> r.startsWith("finance/categories/"));
        assertThat(routes).anyMatch(r -> r.startsWith("finance/transactions/"));
        assertThat(routes).anyMatch(r -> r.startsWith("finance/transfers/"));
    }

    @Test
    void documentsModuleReturnsDocumentRoute() throws Exception {
        String token = registerAndLogin("search-docs@example.com");
        seedAllModules(userIdOf("search-docs@example.com"), "zqx-docs");

        JsonNode body = search(token, "zqx-docs", "DOCUMENTS", null, null, 0, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(1);
        JsonNode row = body.get("results").get(0);
        assertThat(row.get("module").asText()).isEqualTo("DOCUMENTS");
        assertThat(row.get("type").asText()).isEqualTo("DOCUMENT");
        assertThat(row.get("route").asText()).startsWith("documents/");
    }

    @Test
    void allModulesQuerySpansEveryModule() throws Exception {
        String token = registerAndLogin("search-all@example.com");
        seedAllModules(userIdOf("search-all@example.com"), "zqx-all");

        JsonNode body = search(token, "zqx-all", null, null, null, 0, 50);

        // 3 planner + 1 medicines + 6 health + 3 diet (+water only matches "water")
        // + 1 habits + 5 finance + 1 documents = 20
        assertThat(body.get("totalElements").asLong()).isEqualTo(20);
        Set<String> modules = new HashSet<>();
        body.get("results").forEach(r -> modules.add(r.get("module").asText()));
        assertThat(modules).containsExactlyInAnyOrder(
                "PLANNER", "MEDICINES", "HEALTH", "DIET", "HABITS", "FINANCE", "DOCUMENTS");
    }

    // ------------------------------------------------------------------
    // isolation, filtering, totals, pagination, ordering
    // ------------------------------------------------------------------

    @Test
    void userIsolationAcrossModules() throws Exception {
        String owner = registerAndLogin("search-owner@example.com");
        String intruder = registerAndLogin("search-intruder@example.com");
        seedAllModules(userIdOf("search-owner@example.com"), "zqx-isolation");

        JsonNode intruderBody = search(intruder, "zqx-isolation", null, null, null, 0, 50);
        assertThat(intruderBody.get("totalElements").asLong()).isZero();
        assertThat(intruderBody.get("results").size()).isZero();

        JsonNode ownerBody = search(owner, "zqx-isolation", null, null, null, 0, 50);
        assertThat(ownerBody.get("totalElements").asLong()).isEqualTo(20);
    }

    @Test
    void fromToFilteringIncludesBoundaries() throws Exception {
        String token = registerAndLogin("search-range@example.com");
        seedAllModules(userIdOf("search-range@example.com"), "zqx-range");

        // Widest range: everything (20 rows, water excluded by term).
        JsonNode all = search(token, "zqx-range", null,
                "2026-09-01T00:00:00Z", "2026-09-30T23:59:59Z", 0, 50);
        assertThat(all.get("totalElements").asLong()).isEqualTo(20);

        // Narrow window: only planner task (Sep 2) + planner event (Sep 3).
        JsonNode window = search(token, "zqx-range", "PLANNER",
                "2026-09-02T00:00:00Z", "2026-09-03T23:59:59Z", 0, 50);
        assertThat(window.get("totalElements").asLong()).isEqualTo(2);

        // Future window: nothing.
        JsonNode empty = search(token, "zqx-range", null,
                "2027-01-01T00:00:00Z", "2027-12-31T23:59:59Z", 0, 50);
        assertThat(empty.get("totalElements").asLong()).isZero();
        assertThat(empty.get("results").size()).isZero();
        assertThat(empty.get("last").asBoolean()).isTrue();
    }

    @Test
    void fromAfterToIsRejected() throws Exception {
        String token = registerAndLogin("search-badrange@example.com");

        mockMvc.perform(get(SEARCH_URL + "?q=hello&from=2026-09-10T00:00:00Z&to=2026-09-01T00:00:00Z")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());
    }

    @Test
    void totalElementsMatchesDatabaseCountAndPagination() throws Exception {
        String token = registerAndLogin("search-total@example.com");
        seedAllModules(userIdOf("search-total@example.com"), "zqx-total");

        JsonNode first = search(token, "zqx-total", null, null, null, 0, 7);

        assertThat(first.get("totalElements").asLong()).isEqualTo(20);
        assertThat(first.get("totalPages").asInt()).isEqualTo(3);
        assertThat(first.get("page").asInt()).isZero();
        assertThat(first.get("size").asInt()).isEqualTo(7);
        assertThat(first.get("results").size()).isEqualTo(7);
        assertThat(first.get("last").asBoolean()).isFalse();

        JsonNode lastPage = search(token, "zqx-total", null, null, null, 2, 7);
        assertThat(lastPage.get("results").size()).isEqualTo(6);
        assertThat(lastPage.get("last").asBoolean()).isTrue();
        assertThat(lastPage.get("totalElements").asLong()).isEqualTo(20);

        // Beyond the last page: empty content, totals still honest.
        JsonNode beyond = search(token, "zqx-total", null, null, null, 9, 7);
        assertThat(beyond.get("results").size()).isZero();
        assertThat(beyond.get("totalElements").asLong()).isEqualTo(20);
        assertThat(beyond.get("last").asBoolean()).isTrue();
    }

    @Test
    void paginationCollectsEveryRowExactlyOnceInDeterministicOrder() throws Exception {
        String token = registerAndLogin("search-pages@example.com");
        seedAllModules(userIdOf("search-pages@example.com"), "zqx-pages");

        List<String> firstPass = new ArrayList<>();
        for (int page = 0; page < 4; page++) {
            JsonNode body = search(token, "zqx-pages", null, null, null, page, 7);
            body.get("results").forEach(r -> firstPass.add(
                    r.get("module").asText() + "|" + r.get("type").asText() + "|" + r.get("id").asText()));
        }
        assertThat(firstPass).hasSize(20);
        assertThat(new HashSet<>(firstPass)).hasSize(20);

        // Repeat: identical order (deterministic ORDER BY incl. id tiebreak).
        List<String> secondPass = new ArrayList<>();
        for (int page = 0; page < 4; page++) {
            JsonNode body = search(token, "zqx-pages", null, null, null, page, 7);
            body.get("results").forEach(r -> secondPass.add(
                    r.get("module").asText() + "|" + r.get("type").asText() + "|" + r.get("id").asText()));
        }
        assertThat(secondPass).isEqualTo(firstPass);

        // Newest first: the documents row (Sep 16) leads.
        JsonNode head = search(token, "zqx-pages", null, null, null, 0, 1);
        assertThat(head.get("results").get(0).get("module").asText()).isEqualTo("DOCUMENTS");
    }

    // ------------------------------------------------------------------
    // invalid input and edge cases
    // ------------------------------------------------------------------

    @Test
    void invalidModuleIsRejected() throws Exception {
        String token = registerAndLogin("search-badmod@example.com");

        mockMvc.perform(get(SEARCH_URL + "?q=hello&type=NOPE")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());
    }

    @Test
    void noResultsReturnsEmptyPage() throws Exception {
        String token = registerAndLogin("search-empty@example.com");
        seedAllModules(userIdOf("search-empty@example.com"), "zqx-empty");

        JsonNode body = search(token, "qqq-no-such-term-zzz", null, null, null, 0, 20);

        assertThat(body.get("totalElements").asLong()).isZero();
        assertThat(body.get("totalPages").asInt()).isZero();
        assertThat(body.get("results").size()).isZero();
        assertThat(body.get("last").asBoolean()).isTrue();
    }

    @Test
    void shortQueryReturnsEmptyWithoutError() throws Exception {
        String token = registerAndLogin("search-short@example.com");
        seedAllModules(userIdOf("search-short@example.com"), "zqx-short");

        JsonNode body = search(token, "x", null, null, null, 0, 20);

        assertThat(body.get("totalElements").asLong()).isZero();
        assertThat(body.get("results").size()).isZero();
    }

    @Test
    void hugePageNumberReturnsEmptyWithoutError() throws Exception {
        String token = registerAndLogin("search-huge@example.com");
        seedAllModules(userIdOf("search-huge@example.com"), "zqx-huge");

        // page * size overflows int: must be an empty page, never a SQL error.
        JsonNode body = search(token, "zqx-huge", null, null, null, Integer.MAX_VALUE, 50);

        assertThat(body.get("totalElements").asLong()).isEqualTo(20);
        assertThat(body.get("results").size()).isZero();
        assertThat(body.get("last").asBoolean()).isTrue();
    }

    @Test
    void searchIsCaseInsensitive() throws Exception {
        String token = registerAndLogin("search-case@example.com");
        seedAllModules(userIdOf("search-case@example.com"), "zqx-case");

        JsonNode lower = search(token, "zqx-case", "HABITS", null, null, 0, 50);
        JsonNode upper = search(token, "ZQX-CASE", "HABITS", null, null, 0, 50);

        assertThat(lower.get("totalElements").asLong()).isEqualTo(1);
        assertThat(upper.get("totalElements").asLong()).isEqualTo(1);
    }

    @Test
    void unauthenticatedSearchIsRejected() throws Exception {
        mockMvc.perform(get(SEARCH_URL + "?q=hello"))
                .andExpect(status().isUnauthorized());
    }

    // ------------------------------------------------------------------

    private static Set<String> routesOf(JsonNode body) {
        Set<String> routes = new HashSet<>();
        body.get("results").forEach(r -> routes.add(r.get("route").asText()));
        return routes;
    }
}
