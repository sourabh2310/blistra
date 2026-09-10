package com.blistra.medicines;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.medicines.dto.DoseRequest;
import com.blistra.medicines.dto.DoseUpdateRequest;
import com.blistra.medicines.dto.MedicineRequest;
import com.blistra.medicines.dto.RefillRequest;
import com.blistra.medicines.dto.ScheduleRequest;
import com.blistra.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class MedicinesIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private UserRepository userRepository;

    private static final String MEDICINES_URL = "/api/v1/medicines";

    @BeforeEach
    void setUp() {
        deleteAllUsers();
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private String register(String email) throws Exception {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .email(email)
                .password("password123")
                .build();
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(registerRequest)))
                .andExpect(status().isCreated());

        LoginRequest loginRequest = LoginRequest.builder()
                .email(email)
                .password("password123")
                .build();
        MvcResult login = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(login.getResponse().getContentAsString()).get("token").asText();
    }

    private UUID createMedicine(String token, String name) throws Exception {
        MedicineRequest request = MedicineRequest.builder()
                .name(name)
                .form("tablet")
                .strength(new java.math.BigDecimal("500"))
                .strengthUnit("mg")
                .build();
        MvcResult result = mockMvc.perform(post(MEDICINES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private UUID createSchedule(String token, UUID medicineId) throws Exception {
        ScheduleRequest request = ScheduleRequest.builder()
                .scheduleType(com.blistra.medicines.domain.ScheduleType.DAILY)
                .times(List.of("08:00", "20:00"))
                .doseAmount(new java.math.BigDecimal("1"))
                .doseUnit("tablet")
                .build();
        MvcResult result = mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private UUID createDose(String token, UUID medicineId, DoseRequest request) throws Exception {
        MvcResult result = mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private UUID createRefill(String token, UUID medicineId) throws Exception {
        RefillRequest request = RefillRequest.builder()
                .refillDate(java.time.LocalDate.of(2026, 9, 1))
                .quantity(new java.math.BigDecimal("30"))
                .remainingQuantity(new java.math.BigDecimal("30"))
                .build();
        MvcResult result = mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/refills")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    // ------------------------------------------------------------------
    // Core CRUD
    // ------------------------------------------------------------------

    @Test
    void authenticatedUserCanCreateMedicine() throws Exception {
        String token = register("alice@example.com");
        UUID id = createMedicine(token, "Metformin");
        assertThat(id).isNotNull();
    }

    @Test
    void unauthenticatedUserCannotAccessMedicines() throws Exception {
        mockMvc.perform(get(MEDICINES_URL))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(post(MEDICINES_URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"X\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void userCanRetrieveOwnMedicine() throws Exception {
        String token = register("alice@example.com");
        UUID id = createMedicine(token, "Metformin");
        mockMvc.perform(get(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Metformin"))
                .andExpect(jsonPath("$.status").value("ACTIVE"));
    }

    @Test
    void userCannotRetrieveAnotherUsersMedicine() throws Exception {
        String alice = register("alice@example.com");
        String bob = register("bob@example.com");
        UUID id = createMedicine(alice, "Metformin");
        mockMvc.perform(get(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotUpdateAnotherUsersMedicine() throws Exception {
        String alice = register("alice@example.com");
        String bob = register("bob@example.com");
        UUID id = createMedicine(alice, "Metformin");

        MedicineRequest request = MedicineRequest.builder().name("Hijacked").build();
        mockMvc.perform(put(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + bob)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound());

        mockMvc.perform(get(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Metformin"));
    }

    @Test
    void userCannotDeleteAnotherUsersMedicine() throws Exception {
        String alice = register("alice@example.com");
        String bob = register("bob@example.com");
        UUID id = createMedicine(alice, "Metformin");
        mockMvc.perform(delete(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
        mockMvc.perform(get(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk());
    }

    @Test
    void userCannotManipulateAnotherUsersSchedules() throws Exception {
        String alice = register("alice@example.com");
        String bob = register("bob@example.com");
        UUID medicineId = createMedicine(alice, "Metformin");
        UUID scheduleId = createSchedule(alice, medicineId);

        ScheduleRequest request = ScheduleRequest.builder()
                .scheduleType(com.blistra.medicines.domain.ScheduleType.DAILY)
                .times(List.of("09:00"))
                .build();

        mockMvc.perform(get(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + bob)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound());

        mockMvc.perform(put(MEDICINES_URL + "/" + medicineId + "/schedules/" + scheduleId)
                        .header("Authorization", "Bearer " + bob)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(MEDICINES_URL + "/" + medicineId + "/schedules/" + scheduleId)
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotManipulateAnotherUsersDoseRecords() throws Exception {
        String alice = register("alice@example.com");
        String bob = register("bob@example.com");
        UUID medicineId = createMedicine(alice, "Metformin");
        UUID doseId = createDose(alice, medicineId, DoseRequest.builder()
                .status(com.blistra.medicines.domain.DoseStatus.TAKEN)
                .scheduledAt(java.time.OffsetDateTime.parse("2026-09-10T08:00:00+05:30"))
                .build());

        mockMvc.perform(get(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + bob)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(DoseRequest.builder()
                                .status(com.blistra.medicines.domain.DoseStatus.TAKEN)
                                .build())))
                .andExpect(status().isNotFound());

        mockMvc.perform(put(MEDICINES_URL + "/" + medicineId + "/doses/" + doseId)
                        .header("Authorization", "Bearer " + bob)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(DoseUpdateRequest.builder()
                                .status(com.blistra.medicines.domain.DoseStatus.SKIPPED)
                                .build())))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(MEDICINES_URL + "/" + medicineId + "/doses/" + doseId)
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }

    @Test
    void userCannotManipulateAnotherUsersRefills() throws Exception {
        String alice = register("alice@example.com");
        String bob = register("bob@example.com");
        UUID medicineId = createMedicine(alice, "Metformin");
        UUID refillId = createRefill(alice, medicineId);

        RefillRequest request = RefillRequest.builder()
                .refillDate(java.time.LocalDate.of(2026, 10, 1))
                .quantity(new java.math.BigDecimal("10"))
                .build();

        mockMvc.perform(get(MEDICINES_URL + "/" + medicineId + "/refills")
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());

        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/refills")
                        .header("Authorization", "Bearer " + bob)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound());

        mockMvc.perform(put(MEDICINES_URL + "/" + medicineId + "/refills/" + refillId)
                        .header("Authorization", "Bearer " + bob)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isNotFound());

        mockMvc.perform(delete(MEDICINES_URL + "/" + medicineId + "/refills/" + refillId)
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isNotFound());
    }

    // ------------------------------------------------------------------
    // Validation
    // ------------------------------------------------------------------

    @Test
    void invalidMedicineDataIsRejected() throws Exception {
        String token = register("alice@example.com");

        mockMvc.perform(post(MEDICINES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(MEDICINES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"X\",\"strength\":-5}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(MEDICINES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"X\",\"startDate\":\"2026-09-10\",\"endDate\":\"2026-09-01\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidScheduleDataIsRejected() throws Exception {
        String token = register("alice@example.com");
        UUID medicineId = createMedicine(token, "Metformin");

        String weeklyWithoutDays =
                "{\"scheduleType\":\"WEEKLY\",\"times\":[\"08:00\"]}";
        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(weeklyWithoutDays))
                .andExpect(status().isBadRequest());

        String asNeededWithTimes =
                "{\"scheduleType\":\"AS_NEEDED\",\"times\":[\"08:00\"]}";
        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(asNeededWithTimes))
                .andExpect(status().isBadRequest());

        String badTime =
                "{\"scheduleType\":\"DAILY\",\"times\":[\"25:99\"]}";
        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(badTime))
                .andExpect(status().isBadRequest());

        String badDates =
                "{\"scheduleType\":\"DAILY\",\"times\":[\"08:00\"],\"startDate\":\"2026-09-10\",\"endDate\":\"2026-09-01\"}";
        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(badDates))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidDoseDataIsRejected() throws Exception {
        String token = register("alice@example.com");
        UUID medicineId = createMedicine(token, "Metformin");

        String missedWithTakenTime =
                "{\"status\":\"MISSED\",\"takenAt\":\"2026-09-10T08:05:00+05:30\"}";
        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(missedWithTakenTime))
                .andExpect(status().isBadRequest());

        String takenBeforeScheduled =
                "{\"status\":\"TAKEN\",\"scheduledAt\":\"2026-09-10T08:00:00+05:30\",\"takenAt\":\"2026-09-10T07:00:00+05:30\"}";
        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(takenBeforeScheduled))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidRefillDataIsRejected() throws Exception {
        String token = register("alice@example.com");
        UUID medicineId = createMedicine(token, "Metformin");

        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/refills")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refillDate\":\"2026-09-01\",\"quantity\":0}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/refills")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refillDate\":\"2099-01-01\",\"quantity\":10}"))
                .andExpect(status().isBadRequest());
    }

    // ------------------------------------------------------------------
    // Scope and history
    // ------------------------------------------------------------------

    @Test
    void medicineListOnlyContainsCurrentUsersMedicines() throws Exception {
        String alice = register("alice@example.com");
        String bob = register("bob@example.com");
        createMedicine(alice, "Metformin");
        createMedicine(bob, "Atorvastatin");

        MvcResult result = mockMvc.perform(get(MEDICINES_URL)
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andReturn();

        JsonNode body = jsonMapper.readTree(result.getResponse().getContentAsString());
        assertThat(body.get("content").get(0).get("name").asText()).isEqualTo("Metformin");
    }

    @Test
    void medicineListSupportsStatusFilter() throws Exception {
        String alice = register("alice@example.com");
        UUID id = createMedicine(alice, "Metformin");

        MedicineRequest request = MedicineRequest.builder().name("Metformin").status(com.blistra.medicines.domain.MedicineStatus.ARCHIVED).build();
        mockMvc.perform(put(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + alice)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isOk());

        mockMvc.perform(get(MEDICINES_URL + "?status=ACTIVE")
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));

        mockMvc.perform(get(MEDICINES_URL + "?status=ARCHIVED")
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void deletingArchivePreservesHistory() throws Exception {
        String alice = register("alice@example.com");
        UUID medicineId = createMedicine(alice, "Metformin");
        createDose(alice, medicineId, DoseRequest.builder()
                .status(com.blistra.medicines.domain.DoseStatus.TAKEN)
                .build());
        createRefill(alice, medicineId);

        mockMvc.perform(delete(MEDICINES_URL + "/" + medicineId)
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isNoContent());

        mockMvc.perform(get(MEDICINES_URL)
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));

        mockMvc.perform(get(MEDICINES_URL + "?status=ARCHIVED")
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(get(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));

        mockMvc.perform(get(MEDICINES_URL + "/" + medicineId + "/refills")
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1));
    }

    @Test
    void deletingSchedulePreservesDoseHistory() throws Exception {
        String alice = register("alice@example.com");
        UUID medicineId = createMedicine(alice, "Metformin");
        UUID scheduleId = createSchedule(alice, medicineId);

        mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + alice)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(DoseRequest.builder()
                                .status(com.blistra.medicines.domain.DoseStatus.TAKEN)
                                .build())))
                .andExpect(status().isCreated());

        mockMvc.perform(delete(MEDICINES_URL + "/" + medicineId + "/schedules/" + scheduleId)
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isNoContent());

        MvcResult result = mockMvc.perform(get(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andReturn();
        JsonNode body = jsonMapper.readTree(result.getResponse().getContentAsString());
        assertThat(body.get("content").get(0).get("scheduleId").isNull()).isTrue();
    }

    @Test
    void doseStatusTransitionsWork() throws Exception {
        String alice = register("alice@example.com");
        UUID medicineId = createMedicine(alice, "Metformin");
        UUID doseId = createDose(alice, medicineId, DoseRequest.builder()
                .status(com.blistra.medicines.domain.DoseStatus.TAKEN)
                .build());

        mockMvc.perform(put(MEDICINES_URL + "/" + medicineId + "/doses/" + doseId)
                        .header("Authorization", "Bearer " + alice)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(DoseUpdateRequest.builder()
                                .status(com.blistra.medicines.domain.DoseStatus.SKIPPED)
                                .note("Fasting day")
                                .build())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SKIPPED"))
                .andExpect(jsonPath("$.takenAt").doesNotExist());

        mockMvc.perform(put(MEDICINES_URL + "/" + medicineId + "/doses/" + doseId)
                        .header("Authorization", "Bearer " + alice)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(DoseUpdateRequest.builder()
                                .status(com.blistra.medicines.domain.DoseStatus.TAKEN)
                                .build())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("TAKEN"));
    }

    @Test
    void scheduleCrudRoundTrip() throws Exception {
        String alice = register("alice@example.com");
        UUID medicineId = createMedicine(alice, "Metformin");
        UUID scheduleId = createSchedule(alice, medicineId);

        mockMvc.perform(get(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].scheduleType").value("DAILY"))
                .andExpect(jsonPath("$[0].times.length()").value(2));
    }

    @Test
    void responseDoesNotExposeOwnershipFields() throws Exception {
        String alice = register("alice@example.com");
        UUID id = createMedicine(alice, "Metformin");
        MvcResult result = mockMvc.perform(get(MEDICINES_URL + "/" + id)
                        .header("Authorization", "Bearer " + alice))
                .andExpect(status().isOk())
                .andReturn();
        String body = result.getResponse().getContentAsString();
        assertThat(body).doesNotContain("userId");
        assertThat(body).doesNotContain("passwordHash");
    }
}