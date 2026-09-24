package com.blistra.dashboard.controller;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.diet.domain.MealType;
import com.blistra.finance.domain.TransactionType;
import com.blistra.finance.dto.AccountRequest;
import com.blistra.finance.dto.TransactionRequest;
import com.blistra.habits.domain.HabitType;
import com.blistra.habits.dto.HabitRequest;
import com.blistra.habits.dto.ScheduleRequest;
import com.blistra.health.domain.MeasurementType;
import com.blistra.health.dto.MeasurementRequest;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.dto.MedicineRequest;
import com.blistra.planner.dto.TaskCreateRequest;
import com.blistra.users.repository.UserRepository;
import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class DashboardControllerIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private String userAToken;
    private String userBToken;

    @BeforeEach
    void setUp() throws Exception {
        deleteAllUsers();

        // Create User A
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(RegisterRequest.builder()
                                .email("usera@example.com")
                                .password("password123")
                                .build())))
                .andExpect(status().isCreated())
                .andReturn();
        userAToken = login("usera@example.com", "password123");

        // Create User B
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(RegisterRequest.builder()
                                .email("userb@example.com")
                                .password("password123")
                                .build())))
                .andExpect(status().isCreated())
                .andReturn();
        userBToken = login("userb@example.com", "password123");
    }

    private String login(String email, String password) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(LoginRequest.builder()
                                .email(email)
                                .password(password)
                                .build())))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString())
                .get("token")
                .asText();
    }

    private String authHeader(String token) {
        return "Bearer " + token;
    }

    @Test
    void testDashboardRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/dashboard"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testDashboardReturnsAllSectionsForNewUser() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).contains("\"date\"");
        assertThat(body).contains("\"generatedAt\"");
        assertThat(body).contains("\"planner\"");
        assertThat(body).contains("\"finance\"");
        assertThat(body).contains("\"diet\"");
        assertThat(body).contains("\"habits\"");
        assertThat(body).contains("\"health\"");
        assertThat(body).contains("\"medicines\"");
        assertThat(body).contains("\"week\"");
        assertThat(body).contains("\"completedTasks\":0");
        assertThat(body).contains("\"finance\"");
        assertThat(body).contains("\"today\"");
    }

    @Test
    void testUserADataNotVisibleToUserB() throws Exception {
        // Create data for User A across modules
        createPlannerTaskForUserA();
        createMedicineForUserA();
        createHabitForUserA();
        createMealForUserA();
        createHealthMeasurementForUserA();
        createFinanceAccountAndTransactionForUserA();

        // User B requests dashboard
        MvcResult result = mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userBToken)))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        // User B should see empty data
        assertThat(body).contains("\"overdueTasks\":[]");
        assertThat(body).contains("\"todayTasks\":[]");
        assertThat(body).contains("\"activeMedicineCount\":0");
        assertThat(body).contains("\"activeHabitCount\":0");
        assertThat(body).contains("\"mealCount\":0");
        assertThat(body).contains("\"latestMeasurements\":[]");
    }

    @Test
    void testDashboardWithPlannerData() throws Exception {
        createPlannerTaskForUserA();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.planner.unavailable").value(false))
                .andExpect(jsonPath("$.planner.todayTasks").isArray());
    }

    @Test
    void testDashboardWithFinanceData() throws Exception {
        createFinanceAccountAndTransactionForUserA();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userAToken)))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.finance.unavailable").value(false))
                        .andExpect(jsonPath("$.finance.today").isMap())
                        .andExpect(jsonPath("$.finance.today.currencies[0].currency").value("INR"));

    }

    @Test
    void testDashboardWithDietData() throws Exception {
        createMealForUserA();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.diet.unavailable").value(false));
    }

    @Test
    void testDashboardWithHabitData() throws Exception {
        createHabitForUserA();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.habits.unavailable").value(false));
    }

    @Test
    void testDashboardWithHealthData() throws Exception {
        createHealthMeasurementForUserA();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.health.unavailable").value(false));
    }

    @Test
    void testDashboardWithMedicineData() throws Exception {
        createMedicineForUserA();

        mockMvc.perform(get("/api/v1/dashboard")
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.medicines.unavailable").value(false));
    }

    @Test
    void testDashboardWithDateParameter() throws Exception {
        LocalDate yesterday = LocalDate.now().minusDays(1);

        MvcResult result = mockMvc.perform(get("/api/v1/dashboard")
                        .param("date", yesterday.toString())
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).contains(yesterday.toString());
    }

    @Test
    void testDashboardWithOffsetMinutes() throws Exception {
        MvcResult result = mockMvc.perform(get("/api/v1/dashboard")
                        .param("offsetMinutes", "330") // IST
                        .header("Authorization", authHeader(userAToken)))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).contains("date");
    }

    // Helper methods to create minimal test data

    private void createPlannerTaskForUserA() throws Exception {
        TaskCreateRequest request = TaskCreateRequest.builder()
                .title("User A Task")
                .build();
        mockMvc.perform(post("/api/v1/planner/tasks")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private void createMedicineForUserA() throws Exception {
        MedicineRequest request = MedicineRequest.builder()
                .name("Test Medicine")
                .status(MedicineStatus.ACTIVE)
                .build();
        mockMvc.perform(post("/api/v1/medicines")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private void createHabitForUserA() throws Exception {
        HabitRequest request = HabitRequest.builder()
                .name("Test Habit")
                .type(HabitType.BOOLEAN)
                .build();
        mockMvc.perform(post("/api/v1/habits")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private void createMealForUserA() throws Exception {
        com.blistra.diet.dto.CreateMealRequest request = com.blistra.diet.dto.CreateMealRequest.builder()
                .mealType(MealType.LUNCH)
                .title("Test Meal")
                .consumedAt(OffsetDateTime.now())
                .build();
        mockMvc.perform(post("/api/v1/diet/meals")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private void createHealthMeasurementForUserA() throws Exception {
        MeasurementRequest request = MeasurementRequest.builder()
                .type(MeasurementType.WEIGHT)
                .value(java.math.BigDecimal.valueOf(70.5))
                .unit("kg")
                .measuredAt(OffsetDateTime.now())
                .build();
        mockMvc.perform(post("/api/v1/health/measurements")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());
    }

    private void createFinanceAccountAndTransactionForUserA() throws Exception {
        // Create category (required by transaction payload)
        com.blistra.finance.dto.CategoryRequest categoryReq = com.blistra.finance.dto.CategoryRequest.builder()
                .name("Salary")
                .type(com.blistra.finance.domain.CategoryType.INCOME)
                .build();
        MvcResult categoryResult = mockMvc.perform(post("/api/v1/finance/categories")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(categoryReq)))
                .andExpect(status().isCreated())
                .andReturn();
        String categoryId = categoryResult.getResponse().getContentAsString()
                .split("\"id\":\"")[1].split("\"")[0];

        // Create account
        AccountRequest accountReq = AccountRequest.builder()
                .name("Test Account")
                .type(com.blistra.finance.domain.AccountType.BANK)
                .currency("INR")
                .openingBalance("0.00")
                .build();
        MvcResult accountResult = mockMvc.perform(post("/api/v1/finance/accounts")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(accountReq)))
                .andExpect(status().isCreated())
                .andReturn();

        // Extract account ID from response
        String accountBody = accountResult.getResponse().getContentAsString();
        String accountId = accountBody.split("\"id\":\"")[1].split("\"")[0];

        // Create transaction
        TransactionRequest txnReq = TransactionRequest.builder()
                .accountId(UUID.fromString(accountId))
                .categoryId(UUID.fromString(categoryId))
                .type(TransactionType.INCOME)
                .amount("1000.00")
                .build();
        mockMvc.perform(post("/api/v1/finance/transactions")
                        .header("Authorization", authHeader(userAToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(txnReq)))
                .andExpect(status().isCreated());
    }
}