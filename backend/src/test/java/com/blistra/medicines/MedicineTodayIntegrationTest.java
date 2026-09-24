package com.blistra.medicines;

import com.blistra.AbstractIntegrationTest;
import com.blistra.auth.dto.LoginRequest;
import com.blistra.auth.dto.RegisterRequest;
import com.blistra.medicines.domain.DoseStatus;
import com.blistra.medicines.domain.MedicineStatus;
import com.blistra.medicines.domain.ScheduleType;
import com.blistra.medicines.dto.DoseRequest;
import com.blistra.medicines.dto.MedicineRequest;
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

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class MedicineTodayIntegrationTest extends AbstractIntegrationTest {

    private static final ZoneOffset ZONE = ZoneOffset.ofHoursMinutes(5, 30);
    private static final int OFFSET_MINUTES = 330;
    private static final LocalDate DAY = LocalDate.of(2026, 9, 24); // Thursday
    private static final LocalDate NEXT_DAY = DAY.plusDays(1);

    private static final String MEDICINES_URL = "/api/v1/medicines";
    private static final String TODAY_URL = "/api/v1/medicines/today";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JsonMapper jsonMapper;

    @Autowired
    private UserRepository userRepository;

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
        MedicineRequest request = MedicineRequest.builder().name(name).build();
        MvcResult result = mockMvc.perform(post(MEDICINES_URL)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private UUID createSchedule(String token, UUID medicineId, ScheduleType type,
                                List<String> times, List<DayOfWeek> days,
                                Boolean active, LocalDate start, LocalDate end) throws Exception {
        ScheduleRequest request = ScheduleRequest.builder()
                .scheduleType(type)
                .times(times)
                .daysOfWeek(days)
                .doseAmount(new BigDecimal("1"))
                .doseUnit("tablet")
                .active(active)
                .startDate(start)
                .endDate(end)
                .build();
        MvcResult result = mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/schedules")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();
        return UUID.fromString(jsonMapper.readTree(result.getResponse().getContentAsString()).get("id").asText());
    }

    private MvcResult recordDose(String token, UUID medicineId, DoseStatus status,
                                 OffsetDateTime scheduledAt, UUID scheduleId) throws Exception {
        DoseRequest request = DoseRequest.builder()
                .status(status)
                .scheduledAt(scheduledAt)
                .scheduleId(scheduleId)
                .build();
        return mockMvc.perform(post(MEDICINES_URL + "/" + medicineId + "/doses")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(request)))
                .andReturn();
    }

    private JsonNode getToday(String token, LocalDate date) throws Exception {
        MvcResult result = mockMvc.perform(get(TODAY_URL)
                        .header("Authorization", "Bearer " + token)
                        .param("date", date.toString())
                        .param("offsetMinutes", String.valueOf(OFFSET_MINUTES)))
                .andExpect(status().isOk())
                .andReturn();
        return jsonMapper.readTree(result.getResponse().getContentAsString());
    }

    private OffsetDateTime slot(LocalDate date, String time) {
        return OffsetDateTime.of(date, LocalTime.parse(time), ZONE);
    }

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------

    @Test
    void todayExpandsDailyScheduleIntoPendingSlots() throws Exception {
        String token = register("today-1@example.com");
        UUID med = createMedicine(token, "Vitamin D");
        createSchedule(token, med, ScheduleType.DAILY, List.of("08:00", "20:00"),
                null, true, null, null);

        JsonNode today = getToday(token, NEXT_DAY);

        assertThat(today.path("date").asText()).isEqualTo(NEXT_DAY.toString());
        assertThat(today.path("totalDoses").asInt()).isEqualTo(2);
        assertThat(today.path("takenDoses").asInt()).isZero();
        assertThat(today.path("remainingDoses").asInt()).isEqualTo(2);
        assertThat(today.path("doses").size()).isEqualTo(2);
        assertThat(today.path("doses").get(0).path("status").asText()).isEqualTo("PENDING");
        assertThat(today.path("doses").get(0).path("scheduledAt").asText())
                .isEqualTo(slot(NEXT_DAY, "08:00").toString());
        assertThat(today.path("doses").get(1).path("scheduledAt").asText())
                .isEqualTo(slot(NEXT_DAY, "20:00").toString());
        assertThat(today.path("doses").get(0).path("medicineName").asText()).isEqualTo("Vitamin D");
        assertThat(today.path("doses").get(0).path("doseUnit").asText()).isEqualTo("tablet");
        // Both slots are in the future relative to any run time before NEXT_DAY.
        assertThat(today.path("nextDose").path("scheduledAt").asText())
                .isEqualTo(slot(NEXT_DAY, "08:00").toString());
    }

    @Test
    void recordedTakenMatchesItsSlot() throws Exception {
        String token = register("today-2@example.com");
        UUID med = createMedicine(token, "Vitamin D");
        UUID schedule = createSchedule(token, med, ScheduleType.DAILY, List.of("08:00", "20:00"),
                null, true, null, null);

        // Yesterday's slot is always in the past, so TAKEN validation passes.
        MvcResult recorded = recordDose(token, med, DoseStatus.TAKEN, slot(DAY, "08:00"), schedule);
        assertThat(recorded.getResponse().getStatus()).isEqualTo(201);

        JsonNode today = getToday(token, DAY);
        assertThat(today.path("totalDoses").asInt()).isEqualTo(2);
        assertThat(today.path("takenDoses").asInt()).isEqualTo(1);
        assertThat(today.path("remainingDoses").asInt()).isEqualTo(1);
        assertThat(today.path("doses").get(0).path("status").asText()).isEqualTo("TAKEN");
        assertThat(today.path("doses").get(0).path("takenAt").asText()).isNotEmpty();
        assertThat(today.path("doses").get(1).path("status").asText()).isEqualTo("PENDING");
    }

    @Test
    void duplicateTakeForSameSlotIsRejected() throws Exception {
        String token = register("today-3@example.com");
        UUID med = createMedicine(token, "Vitamin D");
        UUID schedule = createSchedule(token, med, ScheduleType.DAILY, List.of("08:00"),
                null, true, null, null);

        MvcResult first = recordDose(token, med, DoseStatus.TAKEN, slot(DAY, "08:00"), schedule);
        assertThat(first.getResponse().getStatus()).isEqualTo(201);

        MvcResult second = recordDose(token, med, DoseStatus.TAKEN, slot(DAY, "08:00"), schedule);
        assertThat(second.getResponse().getStatus()).isEqualTo(409);
    }

    @Test
    void weeklyScheduleOnlyAppliesOnMatchingWeekday() throws Exception {
        String token = register("today-4@example.com");
        UUID med = createMedicine(token, "Weekly Med");
        // DAY (2026-09-24) is a Thursday.
        createSchedule(token, med, ScheduleType.WEEKLY, List.of("09:00"),
                List.of(DayOfWeek.THURSDAY), true, null, null);

        assertThat(getToday(token, DAY).path("totalDoses").asInt()).isEqualTo(1);
        assertThat(getToday(token, NEXT_DAY).path("totalDoses").asInt()).isZero();
    }

    @Test
    void inactiveSchedulePausedMedicineAndAsNeededGenerateNoSlots() throws Exception {
        String token = register("today-5@example.com");

        UUID paused = createMedicine(token, "Paused Med");
        createSchedule(token, paused, ScheduleType.DAILY, List.of("08:00"), null, true, null, null);
        MedicineRequest pause = MedicineRequest.builder().name("Paused Med").status(MedicineStatus.PAUSED).build();
        mockMvc.perform(put(MEDICINES_URL + "/" + paused)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(jsonMapper.writeValueAsString(pause)))
                .andExpect(status().isOk());

        UUID withInactive = createMedicine(token, "Inactive Schedule Med");
        createSchedule(token, withInactive, ScheduleType.DAILY, List.of("08:00"), null, false, null, null);

        UUID asNeeded = createMedicine(token, "As Needed Med");
        createSchedule(token, asNeeded, ScheduleType.AS_NEEDED, List.of(), null, true, null, null);

        JsonNode today = getToday(token, NEXT_DAY);
        assertThat(today.path("totalDoses").asInt()).isZero();
        assertThat(today.path("doses").size()).isZero();
    }

    @Test
    void scheduleOutsideItsDateWindowGeneratesNoSlots() throws Exception {
        String token = register("today-6@example.com");
        UUID med = createMedicine(token, "Short Course");
        createSchedule(token, med, ScheduleType.DAILY, List.of("08:00"), null, true,
                DAY.minusDays(10), DAY.minusDays(1));

        assertThat(getToday(token, DAY).path("totalDoses").asInt()).isZero();
    }

    @Test
    void missedIsOnlyEverUserRecorded() throws Exception {
        String token = register("today-7@example.com");
        UUID med = createMedicine(token, "Vitamin D");
        UUID schedule = createSchedule(token, med, ScheduleType.DAILY, List.of("08:00", "20:00"),
                null, true, null, null);

        // Nothing is auto-marked: both slots stay PENDING.
        JsonNode before = getToday(token, DAY);
        assertThat(before.path("missedDoses").asInt()).isZero();

        MvcResult recorded = recordDose(token, med, DoseStatus.MISSED, slot(DAY, "08:00"), schedule);
        assertThat(recorded.getResponse().getStatus()).isEqualTo(201);

        JsonNode after = getToday(token, DAY);
        assertThat(after.path("missedDoses").asInt()).isEqualTo(1);
        assertThat(after.path("remainingDoses").asInt()).isEqualTo(1);
        assertThat(after.path("doses").get(0).path("status").asText()).isEqualTo("MISSED");
    }

    @Test
    void emptyDayReturnsZeroTotals() throws Exception {
        String token = register("today-8@example.com");

        JsonNode today = getToday(token, NEXT_DAY);
        assertThat(today.path("totalDoses").asInt()).isZero();
        assertThat(today.path("takenDoses").asInt()).isZero();
        assertThat(today.path("doses").size()).isZero();
        assertThat(today.path("nextDose").isNull()).isTrue();
    }

    @Test
    void todayIsScopedToOwner() throws Exception {
        String alice = register("today-9-alice@example.com");
        String bob = register("today-9-bob@example.com");
        UUID med = createMedicine(alice, "Alice Med");
        UUID schedule = createSchedule(alice, med, ScheduleType.DAILY, List.of("08:00"),
                null, true, null, null);

        JsonNode bobToday = getToday(bob, NEXT_DAY);
        assertThat(bobToday.path("totalDoses").asInt()).isZero();

        // Bob cannot record (or read via) Alice's medicine.
        MvcResult attempt = recordDose(bob, med, DoseStatus.TAKEN, slot(DAY, "08:00"), schedule);
        assertThat(attempt.getResponse().getStatus()).isEqualTo(404);

        mockMvc.perform(get(TODAY_URL)
                        .header("Authorization", "Bearer " + bob))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalDoses").value(0));
    }

    @Test
    void recordWithForeignScheduleIdIsRejected() throws Exception {
        String token = register("today-10@example.com");
        UUID medA = createMedicine(token, "Med A");
        UUID medB = createMedicine(token, "Med B");
        UUID scheduleB = createSchedule(token, medB, ScheduleType.DAILY, List.of("08:00"),
                null, true, null, null);

        MvcResult attempt = recordDose(token, medA, DoseStatus.TAKEN, slot(DAY, "08:00"), scheduleB);
        assertThat(attempt.getResponse().getStatus()).isEqualTo(404);
    }

    @Test
    void unauthenticatedTodayIsRejected() throws Exception {
        mockMvc.perform(get(TODAY_URL))
                .andExpect(status().isUnauthorized());
    }
}
