package com.blistra.dashboard.application;

import com.blistra.common.time.UserTime;
import com.blistra.dashboard.dto.DashboardResponse;
import com.blistra.diet.application.DietSummaryService;
import com.blistra.diet.dto.DietSummaryResponse;
import com.blistra.finance.application.SummaryService;
import com.blistra.finance.dto.SummaryResponse;
import com.blistra.habits.application.HabitService;
import com.blistra.habits.dto.HabitTodayResponse;
import com.blistra.planner.application.PlannerTodayService;
import com.blistra.planner.dto.TodayResponse;
import com.blistra.users.application.CurrentUserProvider;
import com.blistra.users.repository.UserProfileRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Orchestrates the dashboard aggregation across all domain modules.
 *
 * <p>Each module's summary is fetched independently. If one module fails,
 * its section is marked unavailable while others still render.</p>
 */
@Service
@Transactional(readOnly = true)
public class DashboardService {

    private final CurrentUserProvider currentUserProvider;
    private final PlannerTodayService plannerTodayService;
    private final SummaryService financeSummaryService;
    private final DietSummaryService dietSummaryService;
    private final HabitService habitService;
    private final HealthSummaryProvider healthSummaryProvider;
    private final MedicineSummaryProvider medicineSummaryProvider;
    private final WeekSummaryProvider weekSummaryProvider;
    private final UserTime userTime;
    private final UserProfileRepository userProfileRepository;

    public DashboardService(CurrentUserProvider currentUserProvider,
                            PlannerTodayService plannerTodayService,
                            SummaryService financeSummaryService,
                            DietSummaryService dietSummaryService,
                            HabitService habitService,
                             HealthSummaryProvider healthSummaryProvider,
                             MedicineSummaryProvider medicineSummaryProvider,
                             WeekSummaryProvider weekSummaryProvider,
                             UserTime userTime,

                            UserProfileRepository userProfileRepository) {
        this.currentUserProvider = currentUserProvider;
        this.plannerTodayService = plannerTodayService;
        this.financeSummaryService = financeSummaryService;
        this.dietSummaryService = dietSummaryService;
        this.habitService = habitService;
        this.healthSummaryProvider = healthSummaryProvider;
        this.medicineSummaryProvider = medicineSummaryProvider;
        this.weekSummaryProvider = weekSummaryProvider;
        this.userTime = userTime;
        this.userProfileRepository = userProfileRepository;
    }

    public DashboardResponse getDashboard(LocalDate date, int offsetMinutes) {
        var user = currentUserProvider.getCurrentUser();

        // Planner
        DashboardResponse.PlannerSection planner = getPlannerSection();

        // Finance - use current month by default, or the date's month
        DashboardResponse.FinanceSection finance = getFinanceSection(date);

        // Diet
        DashboardResponse.DietSection diet = getDietSection(date, offsetMinutes);

        // Habits
        DashboardResponse.HabitSection habits = getHabitSection();

        // Health
        DashboardResponse.HealthSection health = healthSummaryProvider.getHealthSummary();

        // Medicines
        DashboardResponse.MedicineSection medicines = medicineSummaryProvider.getMedicineSummary(date, offsetMinutes);

        DashboardResponse.WeekSummary week = getWeekSection(date, offsetMinutes);

        return DashboardResponse.builder()
                .date(date)
                .generatedAt(userTime.now())
                .user(userSummary(user))
                .planner(planner)
                .finance(finance)
                .diet(diet)
                .habits(habits)
                .health(health)
                .medicines(medicines)
                .week(week)
                .build();
    }

    private DashboardResponse.WeekSummary getWeekSection(LocalDate date, int offsetMinutes) {
        try {
            return weekSummaryProvider.getWeekSummary(date, offsetMinutes);
        } catch (Exception e) {
            return DashboardResponse.WeekSummary.builder()
                    .unavailable(true)
                    .error("Week summary unavailable")
                    .build();
        }
    }

    private DashboardResponse.UserSummary userSummary(com.blistra.users.domain.User user) {
        String email = user.getEmail();
        // Prefer the real profile display name; fall back to deterministic
        // derivation from the email local part (never fake data).
        String profileName = userProfileRepository.findByUserId(user.getId())
                .map(p -> p.getDisplayName())
                .filter(n -> n != null && !n.isBlank())
                .orElse(null);
        if (profileName != null) {
            String first = profileName.trim().split("\\s+")[0];
            return DashboardResponse.UserSummary.builder()
                    .email(email)
                    .displayName(profileName.trim())
                    .firstName(first)
                    .build();
        }
        String local = email != null && email.contains("@")
                ? email.substring(0, email.indexOf('@'))
                : (email != null ? email : "");
        String cleaned = local.replaceAll("[._\\-+]+", " ").trim();
        String displayName = cleaned.isEmpty() ? "" : Character.toUpperCase(cleaned.charAt(0))
                + (cleaned.length() > 1 ? cleaned.substring(1) : "");
        String firstName = displayName.isEmpty() ? "" : displayName.split("\\s+")[0];
        // Capitalize each word's first letter for multi-word local parts.
        if (!displayName.isEmpty() && displayName.contains(" ")) {
            String[] parts = displayName.split("\\s+");
            StringBuilder sb = new StringBuilder();
            for (String p : parts) {
                if (p.isEmpty()) continue;
                if (sb.length() > 0) sb.append(' ');
                sb.append(Character.toUpperCase(p.charAt(0)));
                if (p.length() > 1) sb.append(p.substring(1));
            }
            displayName = sb.toString();
            firstName = displayName.split("\\s+")[0];
        }
        return DashboardResponse.UserSummary.builder()
                .email(email)
                .displayName(displayName)
                .firstName(firstName)
                .build();
    }

    private DashboardResponse.PlannerSection getPlannerSection() {
        try {
            TodayResponse today = plannerTodayService.getToday();
            return DashboardResponse.PlannerSection.builder()
                    .overdueTasks(mapTasks(today.overdueTasks()))
                    .todayTasks(mapTasks(today.todayTasks()))
                    .todayEvents(mapEvents(today.todayEvents()))
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.PlannerSection.builder()
                    .unavailable(true)
                    .error("Planner summary unavailable")
                    .build();
        }
    }

    private DashboardResponse.FinanceSection getFinanceSection(LocalDate date) {
        try {
            // Default to current month (first day to last day of the month)
            LocalDate from = date.withDayOfMonth(1);
            LocalDate to = date.withDayOfMonth(date.lengthOfMonth());

            SummaryResponse summary = financeSummaryService.summary(from, to);
            SummaryResponse today = financeSummaryService.summary(date, date);

            return DashboardResponse.FinanceSection.builder()
                    .from(summary.from())
                    .to(summary.to())
                    .currencies(mapCurrencySections(summary.currencies()))
                    .today(DashboardResponse.FinancePeriodSummary.builder()
                            .from(today.from())
                            .to(today.to())
                            .currencies(mapCurrencySections(today.currencies()))
                            .build())
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.FinanceSection.builder()
                    .unavailable(true)
                    .error("Finance summary unavailable")
                    .build();
        }
    }

    private DashboardResponse.DietSection getDietSection(LocalDate date, int offsetMinutes) {
        try {
            DietSummaryResponse summary = dietSummaryService.dailySummary(
                    currentUserProvider.getCurrentUser().getId(), date, offsetMinutes);

            return DashboardResponse.DietSection.builder()
                    .date(summary.getDate())
                    .mealCount(summary.getMealCount())
                    .meals(mapMeals(summary.getMeals()))
                    .waterCount(summary.getWaterCount())
                    .water(mapWater(summary.getWater()))
                    .waterTotalMilliliters(summary.getWaterTotalMilliliters() != null
                            ? summary.getWaterTotalMilliliters().toPlainString() : null)
                    .nutrition(mapNutrition(summary.getNutrition()))
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.DietSection.builder()
                    .unavailable(true)
                    .error("Diet summary unavailable")
                    .build();
        }
    }

    private DashboardResponse.HabitSection getHabitSection() {
        try {
            List<HabitTodayResponse> todayHabits = habitService.today();

            long expectedToday = todayHabits.size();
            long completedToday = todayHabits.stream().filter(HabitTodayResponse::isCompletedToday).count();
            long remainingToday = expectedToday - completedToday;

            return DashboardResponse.HabitSection.builder()
                    .activeHabitCount((int) expectedToday)
                    .expectedToday((int) expectedToday)
                    .completedToday((int) completedToday)
                    .remainingToday((int) remainingToday)
                    .todayHabits(mapHabits(todayHabits))
                    .unavailable(false)
                    .build();
        } catch (Exception e) {
            return DashboardResponse.HabitSection.builder()
                    .unavailable(true)
                    .error("Habits summary unavailable")
                    .build();
        }
    }

    private List<DashboardResponse.TaskSummary> mapTasks(List<com.blistra.planner.dto.TaskResponse> tasks) {
        return tasks.stream().map(t -> DashboardResponse.TaskSummary.builder()
                .id(t.getId().toString())
                .title(t.getTitle())
                .listId(t.getTaskListId() != null ? t.getTaskListId().toString() : null)
                .listName(t.getTaskListName())
                .priority(t.getPriority() != null ? t.getPriority().name() : null)
                .status(t.getStatus() != null ? t.getStatus().name() : null)
                .dueAt(t.getDueAt() != null ? t.getDueAt().toString() : null)
                .startAt(t.getStartAt() != null ? t.getStartAt().toString() : null)
                .endAt(t.getEndAt() != null ? t.getEndAt().toString() : null)
                .build()).toList();
    }

    private List<DashboardResponse.EventSummary> mapEvents(List<com.blistra.planner.dto.EventResponse> events) {
        return events.stream().map(e -> DashboardResponse.EventSummary.builder()
                .id(e.getId().toString())
                .title(e.getTitle())
                .startAt(e.getStartAt().toString())
                .endAt(e.getEndAt() != null ? e.getEndAt().toString() : null)
                .build()).toList();
    }

    private List<DashboardResponse.CurrencySection> mapCurrencySections(List<com.blistra.finance.dto.SummaryCurrencySection> sections) {
        return sections.stream().map(s -> DashboardResponse.CurrencySection.builder()
                .currency(s.currency())
                .income(s.income())
                .expense(s.expense())
                .net(s.net())
                .transferIn(s.transferIn())
                .transferOut(s.transferOut())
                .topCategories(mapCategorySpends(s.spendingByCategory()))
                .build()).toList();
    }

    private List<DashboardResponse.CategorySpend> mapCategorySpends(List<com.blistra.finance.dto.SummaryCategorySpend> spends) {
        return spends.stream().map(s -> DashboardResponse.CategorySpend.builder()
                .categoryId(s.categoryId().toString())
                .categoryName(s.categoryName())
                .amount(s.amount())
                .build()).toList();
    }

    private List<DashboardResponse.MealSummary> mapMeals(List<com.blistra.diet.dto.MealResponse> meals) {
        return meals.stream().map(m -> DashboardResponse.MealSummary.builder()
                .id(m.getId().toString())
                .type(m.getMealType() != null ? m.getMealType().name() : null)
                .consumedAt(m.getConsumedAt() != null ? m.getConsumedAt().toString() : null)
                .items(mapItems(m.getItems()))
                .build()).toList();
    }

    private List<DashboardResponse.ItemSummary> mapItems(List<com.blistra.diet.dto.MealItemResponse> items) {
        if (items == null) return List.of();
        return items.stream().map(i -> DashboardResponse.ItemSummary.builder()
                .name(i.getName())
                .caloriesKcal(i.getCaloriesKcal() != null ? i.getCaloriesKcal().toPlainString() : null)
                .proteinG(i.getProteinG() != null ? i.getProteinG().toPlainString() : null)
                .carbohydratesG(i.getCarbohydratesG() != null ? i.getCarbohydratesG().toPlainString() : null)
                .fatG(i.getFatG() != null ? i.getFatG().toPlainString() : null)
                .fiberG(i.getFiberG() != null ? i.getFiberG().toPlainString() : null)
                .build()).toList();
    }

    private List<DashboardResponse.WaterSummary> mapWater(List<com.blistra.diet.dto.WaterResponse> water) {
        if (water == null) return List.of();
        return water.stream().map(w -> DashboardResponse.WaterSummary.builder()
                .id(w.getId().toString())
                .amount(w.getAmount() != null ? w.getAmount().toPlainString() : null)
                .unit(w.getUnit())
                .consumedAt(w.getConsumedAt() != null ? w.getConsumedAt().toString() : null)
                .build()).toList();
    }

    private DashboardResponse.NutritionSummary mapNutrition(com.blistra.diet.dto.NutritionTotalsResponse nutrition) {
        if (nutrition == null) return null;
        return DashboardResponse.NutritionSummary.builder()
                .caloriesKcal(mapMacro(nutrition.getCaloriesKcal()))
                .proteinG(mapMacro(nutrition.getProteinG()))
                .carbohydratesG(mapMacro(nutrition.getCarbohydratesG()))
                .fatG(mapMacro(nutrition.getFatG()))
                .fiberG(mapMacro(nutrition.getFiberG()))
                .build();
    }

    private DashboardResponse.MacroSummary mapMacro(com.blistra.diet.dto.MacroTotalsResponse macro) {
        if (macro == null) return null;
        return DashboardResponse.MacroSummary.builder()
                .total(macro.getTotal() != null ? macro.getTotal().toPlainString() : null)
                .recordedItems(macro.getRecordedItems())
                .build();
    }

    private List<DashboardResponse.HabitSummary> mapHabits(List<HabitTodayResponse> habits) {
        return habits.stream().map(h -> DashboardResponse.HabitSummary.builder()
                .id(h.getId().toString())
                .name(h.getName())
                .type(h.getType() != null ? h.getType().name() : null)
                .completedToday(h.isCompletedToday())
                .targetValue(h.getTargetValue() != null ? h.getTargetValue().toPlainString() : null)
                .targetUnit(h.getTargetUnit())
                .build()).toList();
    }
}