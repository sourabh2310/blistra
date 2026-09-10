package com.blistra.dashboard.dto;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class DashboardResponseSerializationTest {

    private final ObjectMapper mapper = new ObjectMapper().registerModule(new JavaTimeModule());

    @Test
    void dashboardResponseSerializesToJson() throws Exception {
        DashboardResponse response = DashboardResponse.builder()
                .date(LocalDate.now())
                .generatedAt(OffsetDateTime.now())
                .planner(DashboardResponse.PlannerSection.builder()
                        .overdueTasks(List.of())
                        .todayTasks(List.of())
                        .todayEvents(List.of())
                        .unavailable(false)
                        .build())
                .medicines(DashboardResponse.MedicineSection.builder()
                        .activeMedicineCount(2)
                        .dosesToday(List.of())
                        .dosesTakenToday(1)
                        .dosesRemainingToday(1)
                        .unavailable(false)
                        .build())
                .habits(DashboardResponse.HabitSection.builder()
                        .activeHabitCount(3)
                        .expectedToday(2)
                        .completedToday(1)
                        .remainingToday(1)
                        .todayHabits(List.of())
                        .unavailable(false)
                        .build())
                .diet(DashboardResponse.DietSection.builder()
                        .date(LocalDate.now())
                        .mealCount(1)
                        .meals(List.of())
                        .waterCount(2)
                        .water(List.of())
                        .waterTotalMilliliters("500")
                        .nutrition(DashboardResponse.NutritionSummary.builder()
                                .caloriesKcal(DashboardResponse.MacroSummary.builder().total("500").recordedItems(1).build())
                                .build())
                        .unavailable(false)
                        .build())
                .health(DashboardResponse.HealthSection.builder()
                        .latestMeasurements(List.of())
                        .upcomingAppointments(List.of())
                        .unavailable(false)
                        .build())
                .finance(DashboardResponse.FinanceSection.builder()
                        .from(LocalDate.now().withDayOfMonth(1))
                        .to(LocalDate.now().withDayOfMonth(30))
                        .currencies(List.of())
                        .unavailable(false)
                        .build())
                .build();

        String json = mapper.writeValueAsString(response);

        assertThat(json).contains("\"date\"");
        assertThat(json).contains("\"generatedAt\"");
        assertThat(json).contains("\"planner\"");
        assertThat(json).contains("\"medicines\"");
        assertThat(json).contains("\"habits\"");
        assertThat(json).contains("\"diet\"");
        assertThat(json).contains("\"health\"");
        assertThat(json).contains("\"finance\"");
        assertThat(json).contains("\"unavailable\":false");
    }

    @Test
    void dashboardResponseDeserializesFromJson() throws Exception {
        String json = """
                {
                    "date": "2026-09-10",
                    "generatedAt": "2026-09-10T10:30:00Z",
                    "planner": {
                        "overdueTasks": [],
                        "todayTasks": [],
                        "todayEvents": [],
                        "unavailable": false
                    },
                    "medicines": {
                        "activeMedicineCount": 2,
                        "dosesToday": [],
                        "dosesTakenToday": 1,
                        "dosesRemainingToday": 1,
                        "unavailable": false
                    },
                    "habits": {
                        "activeHabitCount": 3,
                        "expectedToday": 2,
                        "completedToday": 1,
                        "remainingToday": 1,
                        "todayHabits": [],
                        "unavailable": false
                    },
                    "diet": {
                        "date": "2026-09-10",
                        "mealCount": 1,
                        "meals": [],
                        "waterCount": 2,
                        "water": [],
                        "waterTotalMilliliters": 500,
                        "nutrition": {
                            "caloriesKcal": {"total": "500", "recordedItems": 1}
                        },
                        "unavailable": false
                    },
                    "health": {
                        "latestMeasurements": [],
                        "upcomingAppointments": [],
                        "unavailable": false
                    },
                    "finance": {
                        "from": "2026-09-01",
                        "to": "2026-09-30",
                        "currencies": [],
                        "unavailable": false
                    }
                }
                """;

        DashboardResponse response = mapper.readValue(json, DashboardResponse.class);

        assertThat(response.getDate()).isEqualTo(LocalDate.of(2026, 9, 10));
        assertThat(response.getPlanner().isUnavailable()).isFalse();
        assertThat(response.getMedicines().getActiveMedicineCount()).isEqualTo(2);
        assertThat(response.getHabits().getCompletedToday()).isEqualTo(1);
        assertThat(response.getDiet().getMealCount()).isEqualTo(1);
        assertThat(response.getHealth().isUnavailable()).isFalse();
        assertThat(response.getFinance().getFrom()).isEqualTo(LocalDate.of(2026, 9, 1));
    }

    @Test
    void sectionUnavailableFlagSerializesCorrectly() throws Exception {
        DashboardResponse.PlannerSection section = DashboardResponse.PlannerSection.builder()
                .unavailable(true)
                .error("Service temporarily unavailable")
                .build();

        String json = mapper.writeValueAsString(section);

        assertThat(json).contains("\"unavailable\":true");
        assertThat(json).contains("\"error\":\"Service temporarily unavailable\"");
    }

    @Test
    void nestedSummaryObjectsSerialize() throws Exception {
        DashboardResponse.DoseSummary dose = DashboardResponse.DoseSummary.builder()
                .id(UUID.randomUUID().toString())
                .medicineId(UUID.randomUUID().toString())
                .medicineName("Test Medicine")
                .scheduleId(UUID.randomUUID().toString())
                .status("TAKEN")
                .scheduledAt(OffsetDateTime.now().toString())
                .takenAt(OffsetDateTime.now().toString())
                .doseAmount("500")
                .doseUnit("mg")
                .build();

        String json = mapper.writeValueAsString(dose);

        assertThat(json).contains("\"medicineName\":\"Test Medicine\"");
        assertThat(json).contains("\"status\":\"TAKEN\"");
        assertThat(json).contains("\"doseAmount\":\"500\"");
    }

    @Test
    void financeCurrencySectionSerializes() throws Exception {
        DashboardResponse.CurrencySection currency = DashboardResponse.CurrencySection.builder()
                .currency("INR")
                .income("10000.00")
                .expense("3000.00")
                .net("7000.00")
                .transferIn("0.00")
                .transferOut("0.00")
                .topCategories(List.of(
                        DashboardResponse.CategorySpend.builder()
                                .categoryId(UUID.randomUUID().toString())
                                .categoryName("Food")
                                .amount("1500.00")
                                .build()))
                .build();

        String json = mapper.writeValueAsString(currency);

        assertThat(json).contains("\"currency\":\"INR\"");
        assertThat(json).contains("\"income\":\"10000.00\"");
        assertThat(json).contains("\"topCategories\"");
    }
}