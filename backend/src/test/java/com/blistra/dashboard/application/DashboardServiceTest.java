package com.blistra.dashboard.application;

import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.diet.domain.MealType;
import com.blistra.diet.dto.DietSummaryResponse;
import com.blistra.diet.dto.MacroTotalsResponse;
import com.blistra.diet.dto.MealResponse;
import com.blistra.diet.dto.NutritionTotalsResponse;
import com.blistra.diet.dto.WaterResponse;
import com.blistra.finance.dto.SummaryCategorySpend;
import com.blistra.finance.dto.SummaryCurrencySection;
import com.blistra.finance.dto.SummaryResponse;
import com.blistra.habits.domain.HabitType;
import com.blistra.habits.dto.HabitTodayResponse;
import com.blistra.habits.dto.ScheduleResponse;
import com.blistra.planner.dto.EventResponse;
import com.blistra.planner.dto.TaskResponse;
import com.blistra.planner.dto.TodayResponse;
import com.blistra.users.domain.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DashboardServiceTest {

    @Mock
    private com.blistra.planner.application.PlannerTodayService plannerTodayService;

    @Mock
    private com.blistra.finance.application.SummaryService financeSummaryService;

    @Mock
    private com.blistra.diet.application.DietSummaryService dietSummaryService;

    @Mock
    private com.blistra.habits.application.HabitService habitService;

    @Mock
    private HealthSummaryProvider healthSummaryProvider;

    @Mock
    private MedicineSummaryProvider medicineSummaryProvider;

    @Mock
    private com.blistra.users.application.CurrentUserProvider currentUserProvider;

    private DashboardService dashboardService;
    private User testUser;

    @BeforeEach
    void setUp() {
        dashboardService = new DashboardService(
                currentUserProvider,
                plannerTodayService,
                financeSummaryService,
                dietSummaryService,
                habitService,
                healthSummaryProvider,
                medicineSummaryProvider
        );

        testUser = new User();
        testUser.setId(UUID.randomUUID());
        testUser.setEmail("test@example.com");
    }

    @Test
    void getDashboardReturnsAggregatedResponse() {
        LocalDate date = LocalDate.now();
        int offsetMinutes = 330;

        when(currentUserProvider.getCurrentUser()).thenReturn(testUser);

        // Planner
        lenient().when(plannerTodayService.getToday()).thenReturn(new TodayResponse(
                List.of(),
                List.of(),
                List.of()
        ));

        // Finance
        lenient().when(financeSummaryService.summary(any(), any()))
                .thenReturn(new SummaryResponse(date.withDayOfMonth(1), date.withDayOfMonth(date.lengthOfMonth()), List.of()));

        // Diet
        lenient().when(dietSummaryService.dailySummary(any(), any(), anyInt()))
                .thenReturn(DietSummaryResponse.builder()
                        .date(date)
                        .offsetMinutes(offsetMinutes)
                        .mealCount(0)
                        .meals(List.of())
                        .waterCount(0)
                        .water(List.of())
                        .waterTotalMilliliters(null)
                        .nutrition(NutritionTotalsResponse.builder().build())
                        .build());

        // Habits
        lenient().when(habitService.today()).thenReturn(List.of());

        // Health
        lenient().when(healthSummaryProvider.getHealthSummary())
                .thenReturn(DashboardResponse.HealthSection.builder()
                        .latestMeasurements(List.of())
                        .upcomingAppointments(List.of())
                        .unavailable(false)
                        .build());

        // Medicines
        lenient().when(medicineSummaryProvider.getMedicineSummary(anyInt()))
                .thenReturn(DashboardResponse.MedicineSection.builder()
                        .activeMedicineCount(0)
                        .dosesToday(List.of())
                        .dosesTakenToday(0)
                        .dosesRemainingToday(0)
                        .unavailable(false)
                        .build());

        DashboardResponse response = dashboardService.getDashboard(date, offsetMinutes);

        assertThat(response).isNotNull();
        assertThat(response.getDate()).isEqualTo(date);
        assertThat(response.getGeneratedAt()).isNotNull();
        assertThat(response.getPlanner()).isNotNull();
        assertThat(response.getFinance()).isNotNull();
        assertThat(response.getDiet()).isNotNull();
        assertThat(response.getHabits()).isNotNull();
        assertThat(response.getHealth()).isNotNull();
        assertThat(response.getMedicines()).isNotNull();
    }

    @Test
    void getDashboardHandlesPlannerFailureGracefully() {
        LocalDate date = LocalDate.now();
        int offsetMinutes = 0;

        when(currentUserProvider.getCurrentUser()).thenReturn(testUser);
        when(plannerTodayService.getToday()).thenThrow(new RuntimeException("DB down"));

        lenient().when(financeSummaryService.summary(any(), any()))
                .thenReturn(new SummaryResponse(date.withDayOfMonth(1), date.withDayOfMonth(date.lengthOfMonth()), List.of()));
        lenient().when(dietSummaryService.dailySummary(any(), any(), anyInt()))
                .thenReturn(DietSummaryResponse.builder()
                        .date(date)
                        .offsetMinutes(offsetMinutes)
                        .mealCount(0)
                        .meals(List.of())
                        .waterCount(0)
                        .water(List.of())
                        .waterTotalMilliliters(null)
                        .nutrition(NutritionTotalsResponse.builder().build())
                        .build());
        lenient().when(habitService.today()).thenReturn(List.of());
        lenient().when(healthSummaryProvider.getHealthSummary())
                .thenReturn(DashboardResponse.HealthSection.builder()
                        .latestMeasurements(List.of())
                        .upcomingAppointments(List.of())
                        .unavailable(false)
                        .build());
        lenient().when(medicineSummaryProvider.getMedicineSummary(anyInt()))
                .thenReturn(DashboardResponse.MedicineSection.builder()
                        .activeMedicineCount(0)
                        .dosesToday(List.of())
                        .dosesTakenToday(0)
                        .dosesRemainingToday(0)
                        .unavailable(false)
                        .build());

        DashboardResponse response = dashboardService.getDashboard(date, offsetMinutes);

        assertThat(response).isNotNull();
        assertThat(response.getPlanner().isUnavailable()).isTrue();
        assertThat(response.getPlanner().getError()).isEqualTo("Planner summary unavailable");
        // Other sections should still be available
        assertThat(response.getFinance().isUnavailable()).isFalse();
    }

    @Test
    void getDashboardMapsPlannerDataCorrectly() {
        LocalDate date = LocalDate.now();
        int offsetMinutes = 0;

        UUID taskId = UUID.randomUUID();
        UUID eventId = UUID.randomUUID();

        TaskResponse task = TaskResponse.builder()
                .id(taskId)
                .title("Test Task")
                .taskListId(UUID.randomUUID())
                .taskListName("Personal")
                .priority(com.blistra.planner.domain.TaskPriority.HIGH)
                .status(com.blistra.planner.domain.TaskStatus.TODO)
                .dueAt(OffsetDateTime.now())
                .build();

        EventResponse event = EventResponse.builder()
                .id(eventId)
                .title("Test Event")
                .startAt(OffsetDateTime.now())
                .endAt(OffsetDateTime.now().plusHours(1))
                .build();

        when(currentUserProvider.getCurrentUser()).thenReturn(testUser);
        when(plannerTodayService.getToday()).thenReturn(new TodayResponse(
                List.of(task),
                List.of(),
                List.of(event)
        ));

        lenient().when(financeSummaryService.summary(any(), any()))
                .thenReturn(new SummaryResponse(date.withDayOfMonth(1), date.withDayOfMonth(date.lengthOfMonth()), List.of()));
        lenient().when(dietSummaryService.dailySummary(any(), any(), anyInt()))
                .thenReturn(DietSummaryResponse.builder()
                        .date(date)
                        .offsetMinutes(offsetMinutes)
                        .mealCount(0)
                        .meals(List.of())
                        .waterCount(0)
                        .water(List.of())
                        .waterTotalMilliliters(null)
                        .nutrition(NutritionTotalsResponse.builder().build())
                        .build());
        lenient().when(habitService.today()).thenReturn(List.of());
        lenient().when(healthSummaryProvider.getHealthSummary())
                .thenReturn(DashboardResponse.HealthSection.builder()
                        .latestMeasurements(List.of())
                        .upcomingAppointments(List.of())
                        .unavailable(false)
                        .build());
        lenient().when(medicineSummaryProvider.getMedicineSummary(anyInt()))
                .thenReturn(DashboardResponse.MedicineSection.builder()
                        .activeMedicineCount(0)
                        .dosesToday(List.of())
                        .dosesTakenToday(0)
                        .dosesRemainingToday(0)
                        .unavailable(false)
                        .build());

        DashboardResponse response = dashboardService.getDashboard(date, offsetMinutes);

        assertThat(response.getPlanner().getOverdueTasks()).hasSize(1);
        assertThat(response.getPlanner().getOverdueTasks().get(0).getId()).isEqualTo(taskId.toString());
        assertThat(response.getPlanner().getOverdueTasks().get(0).getTitle()).isEqualTo("Test Task");
        assertThat(response.getPlanner().getTodayEvents()).hasSize(1);
        assertThat(response.getPlanner().getTodayEvents().get(0).getId()).isEqualTo(eventId.toString());
    }

    @Test
    void getDashboardMapsFinanceDataCorrectly() {
        LocalDate date = LocalDate.now();
        int offsetMinutes = 0;

        when(currentUserProvider.getCurrentUser()).thenReturn(testUser);

        lenient().when(plannerTodayService.getToday()).thenReturn(new TodayResponse(List.of(), List.of(), List.of()));
        when(financeSummaryService.summary(any(), any()))
                .thenReturn(new SummaryResponse(
                        date.withDayOfMonth(1),
                        date.withDayOfMonth(date.lengthOfMonth()),
                        List.of(new SummaryCurrencySection(
                                "INR",
                                "10000.00",
                                "3000.00",
                                "7000.00",
                                "0.00",
                                "0.00",
                                List.of(new SummaryCategorySpend(UUID.randomUUID(), "Food", "1500.00"))
                        ))
                ));
        lenient().when(dietSummaryService.dailySummary(any(), any(), anyInt()))
                .thenReturn(DietSummaryResponse.builder()
                        .date(date)
                        .offsetMinutes(offsetMinutes)
                        .mealCount(0)
                        .meals(List.of())
                        .waterCount(0)
                        .water(List.of())
                        .waterTotalMilliliters(null)
                        .nutrition(NutritionTotalsResponse.builder().build())
                        .build());
        lenient().when(habitService.today()).thenReturn(List.of());
        lenient().when(healthSummaryProvider.getHealthSummary())
                .thenReturn(DashboardResponse.HealthSection.builder()
                        .latestMeasurements(List.of())
                        .upcomingAppointments(List.of())
                        .unavailable(false)
                        .build());
        lenient().when(medicineSummaryProvider.getMedicineSummary(anyInt()))
                .thenReturn(DashboardResponse.MedicineSection.builder()
                        .activeMedicineCount(0)
                        .dosesToday(List.of())
                        .dosesTakenToday(0)
                        .dosesRemainingToday(0)
                        .unavailable(false)
                        .build());

        DashboardResponse response = dashboardService.getDashboard(date, offsetMinutes);

        assertThat(response.getFinance().getCurrencies()).hasSize(1);
        assertThat(response.getFinance().getCurrencies().get(0).getCurrency()).isEqualTo("INR");
        assertThat(response.getFinance().getCurrencies().get(0).getIncome()).isEqualTo("10000.00");
        assertThat(response.getFinance().getCurrencies().get(0).getExpense()).isEqualTo("3000.00");
        assertThat(response.getFinance().getCurrencies().get(0).getNet()).isEqualTo("7000.00");
        assertThat(response.getFinance().getCurrencies().get(0).getTopCategories()).hasSize(1);
    }

    @Test
    void getDashboardMapsDietDataCorrectly() {
        LocalDate date = LocalDate.now();
        int offsetMinutes = 330;

        when(currentUserProvider.getCurrentUser()).thenReturn(testUser);

        lenient().when(plannerTodayService.getToday()).thenReturn(new TodayResponse(List.of(), List.of(), List.of()));
        lenient().when(financeSummaryService.summary(any(), any()))
                .thenReturn(new SummaryResponse(date.withDayOfMonth(1), date.withDayOfMonth(date.lengthOfMonth()), List.of()));
        when(dietSummaryService.dailySummary(any(), any(), anyInt()))
                .thenReturn(DietSummaryResponse.builder()
                        .date(date)
                        .offsetMinutes(offsetMinutes)
                        .mealCount(1)
                        .meals(List.of(MealResponse.builder()
                                .id(UUID.randomUUID())
                                .mealType(MealType.LUNCH)
                                .consumedAt(OffsetDateTime.now())
                                .items(List.of())
                                .build()))
                        .waterCount(2)
                        .water(List.of(WaterResponse.builder()
                                .id(UUID.randomUUID())
                                .amount(BigDecimal.valueOf(250))
                                .unit("ml")
                                .consumedAt(OffsetDateTime.now())
                                .build()))
                        .waterTotalMilliliters(BigDecimal.valueOf(500))
                        .nutrition(NutritionTotalsResponse.builder()
                                .caloriesKcal(MacroTotalsResponse.builder().total(BigDecimal.valueOf(500)).recordedItems(1).build())
                                .build())
                        .build());
        lenient().when(habitService.today()).thenReturn(List.of());
        lenient().when(healthSummaryProvider.getHealthSummary())
                .thenReturn(DashboardResponse.HealthSection.builder()
                        .latestMeasurements(List.of())
                        .upcomingAppointments(List.of())
                        .unavailable(false)
                        .build());
        lenient().when(medicineSummaryProvider.getMedicineSummary(anyInt()))
                .thenReturn(DashboardResponse.MedicineSection.builder()
                        .activeMedicineCount(0)
                        .dosesToday(List.of())
                        .dosesTakenToday(0)
                        .dosesRemainingToday(0)
                        .unavailable(false)
                        .build());

        DashboardResponse response = dashboardService.getDashboard(date, offsetMinutes);

        assertThat(response.getDiet().getMealCount()).isEqualTo(1);
        assertThat(response.getDiet().getWaterCount()).isEqualTo(2);
        assertThat(response.getDiet().getWaterTotalMilliliters()).isEqualTo("500");
        assertThat(response.getDiet().getNutrition().getCaloriesKcal().getTotal()).isEqualTo("500");
    }

    @Test
    void getDashboardMapsHabitsDataCorrectly() {
        LocalDate date = LocalDate.now();
        int offsetMinutes = 0;

        UUID habitId = UUID.randomUUID();

        HabitTodayResponse habit = HabitTodayResponse.builder()
                .id(habitId)
                .name("Morning Run")
                .type(HabitType.BOOLEAN)
                .completedToday(true)
                .targetValue(BigDecimal.ONE)
                .targetUnit("session")
                .build();

        when(currentUserProvider.getCurrentUser()).thenReturn(testUser);

        lenient().when(plannerTodayService.getToday()).thenReturn(new TodayResponse(List.of(), List.of(), List.of()));
        lenient().when(financeSummaryService.summary(any(), any()))
                .thenReturn(new SummaryResponse(date.withDayOfMonth(1), date.withDayOfMonth(date.lengthOfMonth()), List.of()));
        lenient().when(dietSummaryService.dailySummary(any(), any(), anyInt()))
                .thenReturn(DietSummaryResponse.builder()
                        .date(date)
                        .offsetMinutes(offsetMinutes)
                        .mealCount(0)
                        .meals(List.of())
                        .waterCount(0)
                        .water(List.of())
                        .waterTotalMilliliters(null)
                        .nutrition(NutritionTotalsResponse.builder().build())
                        .build());
        when(habitService.today()).thenReturn(List.of(habit));
        lenient().when(healthSummaryProvider.getHealthSummary())
                .thenReturn(DashboardResponse.HealthSection.builder()
                        .latestMeasurements(List.of())
                        .upcomingAppointments(List.of())
                        .unavailable(false)
                        .build());
        lenient().when(medicineSummaryProvider.getMedicineSummary(anyInt()))
                .thenReturn(DashboardResponse.MedicineSection.builder()
                        .activeMedicineCount(0)
                        .dosesToday(List.of())
                        .dosesTakenToday(0)
                        .dosesRemainingToday(0)
                        .unavailable(false)
                        .build());

        DashboardResponse response = dashboardService.getDashboard(date, offsetMinutes);

        assertThat(response.getHabits().getActiveHabitCount()).isEqualTo(1);
        assertThat(response.getHabits().getExpectedToday()).isEqualTo(1);
        assertThat(response.getHabits().getCompletedToday()).isEqualTo(1);
        assertThat(response.getHabits().getRemainingToday()).isEqualTo(0);
        assertThat(response.getHabits().getTodayHabits()).hasSize(1);
        assertThat(response.getHabits().getTodayHabits().get(0).getId()).isEqualTo(habitId.toString());
        assertThat(response.getHabits().getTodayHabits().get(0).isCompletedToday()).isTrue();
    }
}