package com.blistra.dashboard.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * Complete dashboard aggregation for the authenticated user.
 *
 * <p>Each section is populated by its owning domain module. A section may be
 * {@code null} or contain an {@code unavailable: true} flag if that module's
 * summary could not be computed (e.g., transient error). This allows partial
 * dashboard rendering instead of total failure.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class DashboardResponse {

    @Schema(description = "User-local date this dashboard represents")
    private LocalDate date;

    @Schema(description = "Server timestamp when the aggregation was generated")
    private OffsetDateTime generatedAt;

    @Schema(description = "Authenticated user identity for header personalization")
    private UserSummary user;

    @Schema(description = "Planner tasks and events for today")
    private PlannerSection planner;

    @Schema(description = "Medicine schedules and dose status for today")
    private MedicineSection medicines;

    @Schema(description = "Habit progress for today")
    private HabitSection habits;

    @Schema(description = "Meals, water, and nutrition for today")
    private DietSection diet;

    @Schema(description = "Latest health measurements and upcoming appointments")
    private HealthSection health;

    @Schema(description = "Account balances and period income/expense")
    private FinanceSection finance;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class UserSummary {
        private String email;
        private String displayName;
        private String firstName;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class PlannerSection {
        private List<TaskSummary> overdueTasks;
        private List<TaskSummary> todayTasks;
        private List<EventSummary> todayEvents;
        private boolean unavailable;
        private String error;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class TaskSummary {
        private String id;
        private String title;
        private String listId;
        private String listName;
        private String priority;
        private String status;
        private String dueAt;
        private String startAt;
        private String endAt;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class EventSummary {
        private String id;
        private String title;
        private String startAt;
        private String endAt;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class MedicineSection {
        private int activeMedicineCount;
        private List<DoseSummary> dosesToday;
        private int dosesTakenToday;
        private int dosesRemainingToday;
        private boolean unavailable;
        private String error;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class DoseSummary {
        private String id;
        private String medicineId;
        private String medicineName;
        private String scheduleId;
        private String status;
        private String scheduledAt;
        private String takenAt;
        private String doseAmount;
        private String doseUnit;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class HabitSection {
        private int activeHabitCount;
        private int expectedToday;
        private int completedToday;
        private int remainingToday;
        private List<HabitSummary> todayHabits;
        private boolean unavailable;
        private String error;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class HabitSummary {
        private String id;
        private String name;
        private String type;
        private boolean completedToday;
        private String targetValue;
        private String targetUnit;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class DietSection {
        private LocalDate date;
        private long mealCount;
        private List<MealSummary> meals;
        private long waterCount;
        private List<WaterSummary> water;
        private String waterTotalMilliliters;
        private NutritionSummary nutrition;
        private boolean unavailable;
        private String error;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class MealSummary {
        private String id;
        private String type;
        private String consumedAt;
        private List<ItemSummary> items;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class ItemSummary {
        private String name;
        private String caloriesKcal;
        private String proteinG;
        private String carbohydratesG;
        private String fatG;
        private String fiberG;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class WaterSummary {
        private String id;
        private String amount;
        private String unit;
        private String consumedAt;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class NutritionSummary {
        private MacroSummary caloriesKcal;
        private MacroSummary proteinG;
        private MacroSummary carbohydratesG;
        private MacroSummary fatG;
        private MacroSummary fiberG;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class MacroSummary {
        private String total;
        private long recordedItems;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class HealthSection {
        private List<MeasurementSummary> latestMeasurements;
        private List<AppointmentSummary> upcomingAppointments;
        private boolean unavailable;
        private String error;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class MeasurementSummary {
        private String type;
        private String value;
        private String valueDiastolic;
        private String unit;
        private String measuredAt;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class AppointmentSummary {
        private String id;
        private String title;
        private String scheduledAt;
        private String location;
        private String status;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class FinanceSection {
        private LocalDate from;
        private LocalDate to;
        private List<CurrencySection> currencies;
        private boolean unavailable;
        private String error;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class CurrencySection {
        private String currency;
        private String income;
        private String expense;
        private String net;
        private String transferIn;
        private String transferOut;
        private List<CategorySpend> topCategories;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class CategorySpend {
        private String categoryId;
        private String categoryName;
        private String amount;
    }
}