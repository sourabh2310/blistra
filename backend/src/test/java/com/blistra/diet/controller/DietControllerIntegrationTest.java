package com.blistra.diet.controller;

import com.blistra.AbstractIntegrationTest;
import com.blistra.diet.domain.Meal;
import com.blistra.diet.domain.MealType;
import com.blistra.diet.repository.MealRepository;
import com.blistra.users.domain.User;
import com.blistra.users.repository.UserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.json.JsonMapper;

import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.OffsetDateTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end coverage of the Diet module: CRUD, ownership isolation (IDOR),
 * validation, date filtering, summaries, referential integrity, and migrations.
 */
class DietControllerIntegrationTest extends AbstractIntegrationTest {

    private static final String MEALS = "/api/v1/diet/meals";
    private static final String WATER = "/api/v1/diet/water";
    private static final String SUMMARY = "/api/v1/diet/summary";
    private static final String PROFILE = "/api/v1/diet/profile";

    private static final String PASSWORD = "password123";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private MealRepository mealRepository;

    @Autowired
    private EntityManager entityManager;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private String userAToken;
    private String userBToken;

    @BeforeEach
    void setUp() throws Exception {
        deleteAllUsers();
        userAToken = registerAndLogin("a@example.com");
        userBToken = registerAndLogin("b@example.com");
    }

    // ------------------------------------------------------------------
    // Auth + ownership helpers
    // ------------------------------------------------------------------

    private String registerAndLogin(String email) throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(
                                java.util.Map.of("email", email, "password", PASSWORD))))
                .andExpect(status().isCreated());

        MvcResult login = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(
                                java.util.Map.of("email", email, "password", PASSWORD))))
                .andExpect(status().isOk())
                .andReturn();

        return jsonMapper.readTree(login.getResponse().getContentAsString()).get("token").asText();
    }

    private String createMeal(String token, String title, OffsetDateTime consumedAt)
            throws Exception {
        String body = """
                {
                  "mealType": "LUNCH",
                  "title": "%s",
                  "notes": "notes",
                  "consumedAt": "%s"
                }
                """.formatted(title, consumedAt.toString());

        MvcResult result = mockMvc.perform(post(MEALS)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();

        return jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText();
    }

    private String createWater(String token, String amount, String unit, OffsetDateTime consumedAt)
            throws Exception {
        String body = """
                {
                  "amount": %s,
                  "unit": "%s",
                  "consumedAt": "%s"
                }
                """.formatted(amount, unit, consumedAt.toString());

        MvcResult result = mockMvc.perform(post(WATER)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();

        return jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText();
    }

    // ------------------------------------------------------------------
    // 1. Authenticated user can create a meal
    // ------------------------------------------------------------------

    @Test
    void authenticatedUserCanCreateMeal() throws Exception {
        String body = """
                {
                  "mealType": "BREAKFAST",
                  "title": "Oatmeal with banana",
                  "consumedAt": "2026-08-10T08:30:00+05:30"
                }
                """;

        mockMvc.perform(post(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.mealType").value("BREAKFAST"))
                .andExpect(jsonPath("$.title").value("Oatmeal with banana"))
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    // ------------------------------------------------------------------
    // 2. Unauthenticated user cannot access Diet endpoints
    // ------------------------------------------------------------------

    @Test
    void unauthenticatedUserCannotAccessDietEndpoints() throws Exception {
        mockMvc.perform(get(MEALS)).andExpect(status().isUnauthorized());
        mockMvc.perform(post(MEALS).contentType(MediaType.APPLICATION_JSON)
                .content("{}")).andExpect(status().isUnauthorized());
        mockMvc.perform(get(WATER)).andExpect(status().isUnauthorized());
        mockMvc.perform(get(PROFILE)).andExpect(status().isUnauthorized());
        mockMvc.perform(get(SUMMARY).param("date", "2026-08-10")).andExpect(status().isUnauthorized());
    }

    // ------------------------------------------------------------------
    // 3. User can retrieve own meals
    // ------------------------------------------------------------------

    @Test
    void userCanRetrieveOwnMeals() throws Exception {
        String mealId = createMeal(userAToken, "Rice and vegetables",
                OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));

        mockMvc.perform(get(MEALS + "/" + mealId)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(mealId))
                .andExpect(jsonPath("$.title").value("Rice and vegetables"));

        mockMvc.perform(get(MEALS)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1));
    }

    // ------------------------------------------------------------------
    // 4-6. Cross-user access to meals is rejected
    // ------------------------------------------------------------------

    @Test
    void userCannotReadAnotherUsersMeal() throws Exception {
        String mealId = createMeal(userAToken, "User A meal",
                OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));

        mockMvc.perform(get(MEALS + "/" + mealId)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotUpdateAnotherUsersMeal() throws Exception {
        String mealId = createMeal(userAToken, "User A meal",
                OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));

        String body = """
                {
                  "mealType": "DINNER",
                  "title": "Hijacked",
                  "consumedAt": "2026-08-10T19:00:00+05:30"
                }
                """;

        mockMvc.perform(put(MEALS + "/" + mealId)
                        .header("Authorization", "Bearer " + userBToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotDeleteAnotherUsersMeal() throws Exception {
        String mealId = createMeal(userAToken, "User A meal",
                OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));

        mockMvc.perform(delete(MEALS + "/" + mealId)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());

        // Meal still belongs to user A.
        mockMvc.perform(get(MEALS + "/" + mealId)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk());
    }

    // ------------------------------------------------------------------
    // 7-9. Cross-user meal-item access is rejected
    // ------------------------------------------------------------------

    @Test
    void userCannotAccessAnotherUsersMealItems() throws Exception {
        String mealId = createMealWithItem(userAToken, "User A meal", "Rice");

        mockMvc.perform(get(MEALS + "/" + mealId + "/items")
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotAddItemsToAnotherUsersMeal() throws Exception {
        String mealId = createMeal(userAToken, "User A meal",
                OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));

        String body = """
                {"name": "Intruder food", "quantity": 1, "unit": "serving"}
                """;

        mockMvc.perform(post(MEALS + "/" + mealId + "/items")
                        .header("Authorization", "Bearer " + userBToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isNotFound());

        mockMvc.perform(get(MEALS + "/" + mealId + "/items")
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void userCannotModifyAnotherUsersMealItems() throws Exception {
        String mealId = createMealWithItem(userAToken, "User A meal", "Rice");
        String itemId = firstItemId(mealId, userAToken);

        String body = """
                {"name": "Hijacked item", "quantity": 0.5, "unit": "cup"}
                """;

        mockMvc.perform(put(MEALS + "/" + mealId + "/items/" + itemId)
                        .header("Authorization", "Bearer " + userBToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(MEALS + "/" + mealId + "/items/" + itemId)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());
    }

    // ------------------------------------------------------------------
    // 10. Cross-user water access is rejected
    // ------------------------------------------------------------------

    @Test
    void userCannotAccessAnotherUsersWater() throws Exception {
        String waterId = createWater(userAToken, "250", "ml",
                OffsetDateTime.parse("2026-08-10T09:00:00+05:30"));

        mockMvc.perform(get(WATER + "/" + waterId)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());

        String body = """
                {"amount": 500, "unit": "ml", "consumedAt": "2026-08-10T10:00:00+05:30"}
                """;

        mockMvc.perform(put(WATER + "/" + waterId)
                        .header("Authorization", "Bearer " + userBToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(WATER + "/" + waterId)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isNotFound());
    }

    // ------------------------------------------------------------------
    // 11-14. Validation
    // ------------------------------------------------------------------

    @Test
    void invalidMealDataIsRejected() throws Exception {
        mockMvc.perform(post(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title": "", "consumedAt": "not-a-date"}
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"mealType": "LUNCH", "title": "", "consumedAt": "2026-08-10T12:00:00+05:30"}
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"mealType": "BREAKFAST", "title": "Oatmeal",
                                  "consumedAt": "2099-01-01T08:00:00+05:30"}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidMealItemDataIsRejected() throws Exception {
        String mealId = createMeal(userAToken, "Meal",
                OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));

        mockMvc.perform(post(MEALS + "/" + mealId + "/items")
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "", "quantity": 1}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void negativeNutritionValuesAreRejected() throws Exception {
        String mealId = createMeal(userAToken, "Meal",
                OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));

        mockMvc.perform(post(MEALS + "/" + mealId + "/items")
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "Rice", "caloriesKcal": -100}
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(MEALS + "/" + mealId + "/items")
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "Rice", "quantity": -1}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidWaterAmountIsRejected() throws Exception {
        mockMvc.perform(post(WATER)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount": 0, "unit": "ml", "consumedAt": "2026-08-10T09:00:00+05:30"}
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(WATER)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount": -250, "unit": "ml", "consumedAt": "2026-08-10T09:00:00+05:30"}
                                """))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(WATER)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"amount": 250, "unit": "gallons", "consumedAt": "2026-08-10T09:00:00+05:30"}
                                """))
                .andExpect(status().isBadRequest());
    }

    // ------------------------------------------------------------------
    // 15. Date filtering
    // ------------------------------------------------------------------

    @Test
    void dateFilteringWorks() throws Exception {
        createMeal(userAToken, "Aug 10 meal", OffsetDateTime.parse("2026-08-10T12:00:00+05:30"));
        createMeal(userAToken, "Aug 12 meal", OffsetDateTime.parse("2026-08-12T12:00:00+05:30"));

        // Local day 2026-08-10 in IST (+05:30).
        mockMvc.perform(get(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("date", "2026-08-10")
                        .param("offsetMinutes", "330"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].title").value("Aug 10 meal"));

        // The other meal is outside the requested day.
        mockMvc.perform(get(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("date", "2026-08-11")
                        .param("offsetMinutes", "330"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0));

        // Without a date, recent history includes both.
        mockMvc.perform(get(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("size", "100"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2));
    }

    // ------------------------------------------------------------------
    // 16-17. Daily summary: ownership isolation + date/time boundaries
    // ------------------------------------------------------------------

    @Test
    void dailySummaryOnlyIncludesCorrectUser() throws Exception {
        createMeal(userAToken, "User A meal", OffsetDateTime.parse("2026-08-16T02:00:00+05:30"));
        createMeal(userBToken, "User B meal", OffsetDateTime.parse("2026-08-16T02:00:00+05:30"));
        createWater(userAToken, "250", "ml", OffsetDateTime.parse("2026-08-16T09:00:00+05:30"));

        mockMvc.perform(get(SUMMARY)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("date", "2026-08-16")
                        .param("offsetMinutes", "330"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mealCount").value(1))
                .andExpect(jsonPath("$.meals[0].title").value("User A meal"))
                .andExpect(jsonPath("$.waterCount").value(1));

        mockMvc.perform(get(SUMMARY)
                        .header("Authorization", "Bearer " + userBToken)
                        .param("date", "2026-08-16")
                        .param("offsetMinutes", "330"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mealCount").value(1))
                .andExpect(jsonPath("$.meals[0].title").value("User B meal"))
                .andExpect(jsonPath("$.waterCount").value(0));
    }

    @Test
    void dailySummaryRespectsDateBoundaries() throws Exception {
        // In IST (+05:30): 2026-08-15T20:00Z == local 2026-08-16T01:30 (day 16)
        //                 2026-08-16T02:00Z == local 2026-08-16T07:30 (day 16)
        //                 2026-08-16T20:00Z == local 2026-08-17T01:30 (day 17)
        createMeal(userAToken, "Late night +5:30", OffsetDateTime.parse("2026-08-15T20:00:00Z"));
        createMeal(userAToken, "Morning +5:30", OffsetDateTime.parse("2026-08-16T02:00:00Z"));
        createMeal(userAToken, "Next day +5:30", OffsetDateTime.parse("2026-08-16T20:00:00Z"));

        // IST day 2026-08-16 includes the first two.
        mockMvc.perform(get(SUMMARY)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("date", "2026-08-16")
                        .param("offsetMinutes", "330"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mealCount").value(2));

        // The 20:00Z meal belongs to the UTC day 2026-08-16 only when no offset shift is applied.
        mockMvc.perform(get(SUMMARY)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("date", "2026-08-16")
                        .param("offsetMinutes", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mealCount").value(2))
                .andExpect(jsonPath("$.meals[0].title").value("Morning +5:30"))
                .andExpect(jsonPath("$.meals[1].title").value("Next day +5:30"));

        // IST day 2026-08-17 includes only the last one.
        mockMvc.perform(get(SUMMARY)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("date", "2026-08-17")
                        .param("offsetMinutes", "330"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mealCount").value(1))
                .andExpect(jsonPath("$.meals[0].title").value("Next day +5:30"));
    }

    // ------------------------------------------------------------------
    // 18. Meal-item ownership is enforced through meal ownership
    // ------------------------------------------------------------------

    @Test
    void mealItemOwnershipEnforcedThroughMealOwnership() throws Exception {
        String mealA = createMealWithItem(userAToken, "User A meal", "Rice");
        String mealB = createMealWithItem(userBToken, "User B meal", "Bread");
        String itemB = firstItemId(mealB, userBToken);

        // User A cannot touch user B's item even when guessing the meal id, and vice versa.
        mockMvc.perform(put(MEALS + "/" + mealA + "/items/" + itemB)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "Hijack", "quantity": 1}
                                """))
                .andExpect(status().isNotFound());

        mockMvc.perform(put(MEALS + "/" + mealB + "/items/" + itemB)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "Hijack", "quantity": 1}
                                """))
                .andExpect(status().isNotFound());

        // Legitimate owner can still modify.
        mockMvc.perform(put(MEALS + "/" + mealB + "/items/" + itemB)
                        .header("Authorization", "Bearer " + userBToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name": "Bread roll", "quantity": 2, "unit": "slice"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Bread roll"));
    }

    // ------------------------------------------------------------------
    // 19-20. Referential integrity and migrations
    // ------------------------------------------------------------------

    @Test
    @org.springframework.transaction.annotation.Transactional
    void foreignKeyRelationshipsWork() throws Exception {
        // An orphan meal item (missing meal) is rejected by the database FK.
        // Runs in its own transaction so the deliberate violation does not
        // abort the surrounding test transaction.
        TransactionTemplate isolated = new TransactionTemplate(transactionManager);
        isolated.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        assertThatThrownBy(() -> isolated.execute(status -> {
            jdbcTemplate.update(
                    "INSERT INTO meal_items (id, meal_id, name) VALUES (?, ?, ?)",
                    UUID.randomUUID(), UUID.randomUUID(), "Rice");
            return null;
        })).isInstanceOf(DataIntegrityViolationException.class);

        // Deleting a user cascades to their meals and water records.
        User user = new User("fk@example.com", "hash");
        userRepository.save(user);

        Meal owned = new Meal(user.getId(), MealType.LUNCH, "Owned meal", null,
                OffsetDateTime.parse("2026-08-10T12:00:00Z"));
        Meal saved = mealRepository.save(owned);

        assertThat(mealRepository.findById(saved.getId())).isPresent();
        userRepository.delete(user);
        entityManager.flush();
        entityManager.clear();
        assertThat(mealRepository.findById(saved.getId())).isEmpty();
    }

    @Test
    void flywayMigrationSucceedsAndDietTablesExist() throws Exception {
        for (String table : new String[]{"diet_profiles", "meals", "meal_items", "water_intake"}) {
            Integer present = jdbcTemplate.queryForObject(
                    "SELECT count(*) FROM pg_tables WHERE tablename = ?", Integer.class, table);
            assertThat(present).isOne();
        }
    }

    // ------------------------------------------------------------------
    // Supplementary: profile + full summary behaviour
    // ------------------------------------------------------------------

    @Test
    void profileUpsertSupportsCustomPreference() throws Exception {
        mockMvc.perform(get(PROFILE)
                        .header("Authorization", "Bearer " + userAToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dietaryPreference").doesNotExist());

        mockMvc.perform(put(PROFILE)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"dietaryPreference": "OTHER", "customPreference": "Low-fodmap-ish",
                                 "dislikedFoods": "eggplant", "notes": "personal"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dietaryPreference").value("OTHER"))
                .andExpect(jsonPath("$.customPreference").value("Low-fodmap-ish"));

        // OTHER without custom is rejected.
        mockMvc.perform(put(PROFILE)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"dietaryPreference": "OTHER"}
                                """))
                .andExpect(status().isBadRequest());

        // Profiles are isolated per user.
        mockMvc.perform(get(PROFILE)
                        .header("Authorization", "Bearer " + userBToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dietaryPreference").doesNotExist());
    }

    @Test
    void summaryAggregatesRecordedNutritionAndWater() throws Exception {
        String body = """
                {
                  "mealType": "DINNER",
                  "title": "Rice and vegetables",
                  "consumedAt": "2026-08-16T19:00:00+05:30",
                  "items": [
                    {"name": "Rice", "quantity": 100, "unit": "g",
                     "caloriesKcal": 130, "proteinG": 2.7},
                    {"name": "Spinach", "quantity": 50, "unit": "g",
                     "caloriesKcal": 12}
                  ]
                }
                """;

        mockMvc.perform(post(MEALS)
                        .header("Authorization", "Bearer " + userAToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated());

        createWater(userAToken, "500", "ml", OffsetDateTime.parse("2026-08-16T10:00:00+05:30"));
        createWater(userAToken, "1", "L", OffsetDateTime.parse("2026-08-16T17:00:00+05:30"));
        createWater(userAToken, "1", "glass", OffsetDateTime.parse("2026-08-16T20:00:00+05:30"));

        mockMvc.perform(get(SUMMARY)
                        .header("Authorization", "Bearer " + userAToken)
                        .param("date", "2026-08-16")
                        .param("offsetMinutes", "330"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mealCount").value(1))
                .andExpect(jsonPath("$.meals[0].items.length()").value(2))
                .andExpect(jsonPath("$.waterCount").value(3))
                // Numeric units (ml/L) sum to 1500 ml; "glass" is excluded from the derived total.
                .andExpect(jsonPath("$.waterTotalMilliliters").value(1500))
                .andExpect(jsonPath("$.nutrition.caloriesKcal.total").value(142))
                .andExpect(jsonPath("$.nutrition.caloriesKcal.recordedItems").value(2))
                .andExpect(jsonPath("$.nutrition.proteinG.total").value(2.7))
                .andExpect(jsonPath("$.nutrition.carbohydratesG.recordedItems").value(0))
                .andExpect(jsonPath("$.nutrition.carbohydratesG.total").doesNotExist());
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private String createMealWithItem(String token, String title, String itemName) throws Exception {
        String body = """
                {
                  "mealType": "LUNCH",
                  "title": "%s",
                  "consumedAt": "2026-08-10T12:00:00+05:30",
                  "items": [{"name": "%s", "quantity": 1, "unit": "serving"}]
                }
                """.formatted(title, itemName);

        MvcResult result = mockMvc.perform(post(MEALS)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();

        return jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText();
    }

    private String firstItemId(String mealId, String token) throws Exception {
        MvcResult result = mockMvc.perform(get(MEALS + "/" + mealId + "/items")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString()).get(0).get("id").asText();
    }
}