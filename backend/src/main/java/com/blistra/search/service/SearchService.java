package com.blistra.search.service;

import com.blistra.diet.domain.Meal;
import com.blistra.diet.domain.MealItem;
import com.blistra.diet.domain.DietProfile;
import com.blistra.diet.domain.WaterIntake;
import com.blistra.diet.repository.MealRepository;
import com.blistra.diet.repository.MealItemRepository;
import com.blistra.diet.repository.DietProfileRepository;
import com.blistra.diet.repository.WaterIntakeRepository;
import com.blistra.health.domain.HealthActivity;
import com.blistra.health.domain.HealthAppointment;
import com.blistra.health.domain.HealthEvent;
import com.blistra.health.domain.HealthMeasurement;
import com.blistra.health.domain.HealthSleepRecord;
import com.blistra.health.domain.HealthSymptomLog;
import com.blistra.health.repository.HealthActivityRepository;
import com.blistra.health.repository.HealthAppointmentRepository;
import com.blistra.health.repository.HealthEventRepository;
import com.blistra.health.repository.HealthMeasurementRepository;
import com.blistra.health.repository.HealthSleepRecordRepository;
import com.blistra.health.repository.HealthSymptomLogRepository;
import com.blistra.medicines.domain.Medicine;
import com.blistra.medicines.repository.MedicineRepository;
import com.blistra.planner.domain.PlannerEvent;
import com.blistra.planner.domain.Task;
import com.blistra.planner.domain.TaskList;
import com.blistra.planner.repository.PlannerEventRepository;
import com.blistra.planner.repository.TaskRepository;
import com.blistra.planner.repository.TaskListRepository;
import com.blistra.search.dto.SearchResponse;
import com.blistra.search.dto.SearchResult;
import com.blistra.users.application.CurrentUserProvider;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
public class SearchService {

    private static final int MAX_PAGE_SIZE = 50;
    private static final int MIN_QUERY_LENGTH = 2;

    private final CurrentUserProvider currentUserProvider;
    private final TaskRepository taskRepository;
    private final TaskListRepository taskListRepository;
    private final PlannerEventRepository plannerEventRepository;
    private final MedicineRepository medicineRepository;
    private final HealthEventRepository healthEventRepository;
    private final HealthAppointmentRepository healthAppointmentRepository;
    private final HealthSymptomLogRepository healthSymptomLogRepository;
    private final HealthActivityRepository healthActivityRepository;
    private final HealthMeasurementRepository healthMeasurementRepository;
    private final HealthSleepRecordRepository healthSleepRecordRepository;
    private final MealRepository mealRepository;
    private final MealItemRepository mealItemRepository;
    private final DietProfileRepository dietProfileRepository;
    private final WaterIntakeRepository waterIntakeRepository;

    public SearchService(CurrentUserProvider currentUserProvider,
                         TaskRepository taskRepository,
                         TaskListRepository taskListRepository,
                         PlannerEventRepository plannerEventRepository,
                         MedicineRepository medicineRepository,
                         HealthEventRepository healthEventRepository,
                         HealthAppointmentRepository healthAppointmentRepository,
                         HealthSymptomLogRepository healthSymptomLogRepository,
                         HealthActivityRepository healthActivityRepository,
                         HealthMeasurementRepository healthMeasurementRepository,
                         HealthSleepRecordRepository healthSleepRecordRepository,
                         MealRepository mealRepository,
                         MealItemRepository mealItemRepository,
                         DietProfileRepository dietProfileRepository,
                         WaterIntakeRepository waterIntakeRepository) {
        this.currentUserProvider = currentUserProvider;
        this.taskRepository = taskRepository;
        this.taskListRepository = taskListRepository;
        this.plannerEventRepository = plannerEventRepository;
        this.medicineRepository = medicineRepository;
        this.healthEventRepository = healthEventRepository;
        this.healthAppointmentRepository = healthAppointmentRepository;
        this.healthSymptomLogRepository = healthSymptomLogRepository;
        this.healthActivityRepository = healthActivityRepository;
        this.healthMeasurementRepository = healthMeasurementRepository;
        this.healthSleepRecordRepository = healthSleepRecordRepository;
        this.mealRepository = mealRepository;
        this.mealItemRepository = mealItemRepository;
        this.dietProfileRepository = dietProfileRepository;
        this.waterIntakeRepository = waterIntakeRepository;
    }

    @Transactional(readOnly = true)
    public SearchResponse search(String query, String type, OffsetDateTime from, OffsetDateTime to, int page, int size) {
        if (query == null || query.trim().length() < MIN_QUERY_LENGTH) {
            return SearchResponse.builder()
                    .results(List.of())
                    .page(page)
                    .size(size)
                    .totalElements(0)
                    .totalPages(0)
                    .last(true)
                    .build();
        }

        if (size > MAX_PAGE_SIZE) {
            size = MAX_PAGE_SIZE;
        }

        UUID userId = currentUserProvider.getCurrentUser().getId();
        String searchTerm = "%" + query.trim().toLowerCase() + "%";

        List<SearchResult> allResults = new ArrayList<>();

        if (type == null || type.equalsIgnoreCase("PLANNER")) {
            allResults.addAll(searchPlannerTasks(userId, searchTerm));
            allResults.addAll(searchPlannerTaskLists(userId, searchTerm));
            allResults.addAll(searchPlannerEvents(userId, searchTerm));
        }

        if (type == null || type.equalsIgnoreCase("MEDICINES")) {
            allResults.addAll(searchMedicines(userId, searchTerm));
        }

        if (type == null || type.equalsIgnoreCase("HEALTH")) {
            allResults.addAll(searchHealthEvents(userId, searchTerm));
            allResults.addAll(searchHealthAppointments(userId, searchTerm));
            allResults.addAll(searchHealthSymptomLogs(userId, searchTerm));
            allResults.addAll(searchHealthActivities(userId, searchTerm));
            allResults.addAll(searchHealthMeasurements(userId, searchTerm));
            allResults.addAll(searchHealthSleepRecords(userId, searchTerm));
        }

        if (type == null || type.equalsIgnoreCase("DIET")) {
            allResults.addAll(searchMeals(userId, searchTerm));
            allResults.addAll(searchMealItems(userId, searchTerm));
            allResults.addAll(searchDietProfiles(userId, searchTerm));
            allResults.addAll(searchWaterIntake(userId, searchTerm));
        }

        allResults.sort(Comparator.comparing(SearchResult::getTimestamp).reversed());

        int totalElements = allResults.size();
        int totalPages = (int) Math.ceil((double) totalElements / size);
        int fromIndex = page * size;
        int toIndex = Math.min(fromIndex + size, totalElements);

        List<SearchResult> pageResults = fromIndex < totalElements
                ? allResults.subList(fromIndex, toIndex)
                : List.of();

        return SearchResponse.builder()
                .results(pageResults)
                .page(page)
                .size(size)
                .totalElements(totalElements)
                .totalPages(totalPages)
                .last(page >= totalPages - 1)
                .build();
    }

    private List<SearchResult> searchPlannerTasks(UUID userId, String searchTerm) {
        Page<Task> tasks = taskRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt")));
        List<SearchResult> results = new ArrayList<>();
        for (Task task : tasks.getContent()) {
            results.add(SearchResult.builder()
                    .type("TASK")
                    .module("PLANNER")
                    .id(task.getId())
                    .title(task.getTitle())
                    .subtitle(task.getDescription() != null ? task.getDescription() : (task.getList() != null ? task.getList().getName() : ""))
                    .timestamp(task.getCreatedAt() != null ? task.getCreatedAt().atOffset(java.time.ZoneOffset.UTC) : OffsetDateTime.now())
                    .route("planner/task/" + task.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchPlannerTaskLists(UUID userId, String searchTerm) {
        Page<TaskList> lists = taskListRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt")));
        List<SearchResult> results = new ArrayList<>();
        for (TaskList list : lists.getContent()) {
            results.add(SearchResult.builder()
                    .type("TASK_LIST")
                    .module("PLANNER")
                    .id(list.getId())
                    .title(list.getName())
                    .subtitle(list.getDescription())
                    .timestamp(list.getCreatedAt() != null ? list.getCreatedAt().atOffset(java.time.ZoneOffset.UTC) : OffsetDateTime.now())
                    .route("planner/list/" + list.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchPlannerEvents(UUID userId, String searchTerm) {
        Page<PlannerEvent> events = plannerEventRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "startAt")));
        List<SearchResult> results = new ArrayList<>();
        for (PlannerEvent event : events.getContent()) {
            results.add(SearchResult.builder()
                    .type("PLANNER_EVENT")
                    .module("PLANNER")
                    .id(event.getId())
                    .title(event.getTitle())
                    .subtitle(event.getLocation() != null ? event.getLocation() : event.getDescription())
                    .timestamp(event.getStartAt())
                    .route("planner/event/" + event.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchMedicines(UUID userId, String searchTerm) {
        Page<Medicine> medicines = medicineRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt")));
        List<SearchResult> results = new ArrayList<>();
        for (Medicine med : medicines.getContent()) {
            String subtitle = med.getGenericName() != null ? med.getGenericName() : "";
            if (med.getStrength() != null) {
                subtitle += (subtitle.isEmpty() ? "" : " ") + med.getStrength() + (med.getStrengthUnit() != null ? " " + med.getStrengthUnit() : "");
            }
            results.add(SearchResult.builder()
                    .type("MEDICINE")
                    .module("MEDICINES")
                    .id(med.getId())
                    .title(med.getName())
                    .subtitle(subtitle.isEmpty() ? med.getNotes() : subtitle)
                    .timestamp(med.getCreatedAt() != null ? med.getCreatedAt().atOffset(java.time.ZoneOffset.UTC) : OffsetDateTime.now())
                    .route("medicines/" + med.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchHealthEvents(UUID userId, String searchTerm) {
        Page<HealthEvent> events = healthEventRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "occurredAt")));
        List<SearchResult> results = new ArrayList<>();
        for (HealthEvent event : events.getContent()) {
            results.add(SearchResult.builder()
                    .type("HEALTH_EVENT")
                    .module("HEALTH")
                    .id(event.getId())
                    .title(event.getTitle())
                    .subtitle(event.getType() != null ? event.getType().name() : "")
                    .timestamp(event.getOccurredAt())
                    .route("health/event/" + event.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchHealthAppointments(UUID userId, String searchTerm) {
        Page<HealthAppointment> appts = healthAppointmentRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "scheduledAt")));
        List<SearchResult> results = new ArrayList<>();
        for (HealthAppointment appt : appts.getContent()) {
            results.add(SearchResult.builder()
                    .type("HEALTH_APPOINTMENT")
                    .module("HEALTH")
                    .id(appt.getId())
                    .title(appt.getTitle())
                    .subtitle(appt.getLocation() != null ? appt.getLocation() : appt.getStatus().name())
                    .timestamp(appt.getScheduledAt())
                    .route("health/appointment/" + appt.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchHealthSymptomLogs(UUID userId, String searchTerm) {
        Page<HealthSymptomLog> logs = healthSymptomLogRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "observedAt")));
        List<SearchResult> results = new ArrayList<>();
        for (HealthSymptomLog log : logs.getContent()) {
            results.add(SearchResult.builder()
                    .type("SYMPTOM_LOG")
                    .module("HEALTH")
                    .id(log.getId())
                    .title(log.getTitle())
                    .subtitle(log.getSeverity() != null ? log.getSeverity().name() : "")
                    .timestamp(log.getObservedAt())
                    .route("health/symptom/" + log.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchHealthActivities(UUID userId, String searchTerm) {
        Page<HealthActivity> activities = healthActivityRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "performedAt")));
        List<SearchResult> results = new ArrayList<>();
        for (HealthActivity act : activities.getContent()) {
            results.add(SearchResult.builder()
                    .type("HEALTH_ACTIVITY")
                    .module("HEALTH")
                    .id(act.getId())
                    .title(act.getType() != null ? act.getType().name() : "Activity")
                    .subtitle(act.getDurationMinutes() + " min" + (act.getDistanceKm() != null ? " · " + act.getDistanceKm() + " km" : ""))
                    .timestamp(act.getPerformedAt())
                    .route("health/activity/" + act.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchHealthMeasurements(UUID userId, String searchTerm) {
        Page<HealthMeasurement> measurements = healthMeasurementRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "measuredAt")));
        List<SearchResult> results = new ArrayList<>();
        for (HealthMeasurement m : measurements.getContent()) {
            results.add(SearchResult.builder()
                    .type("HEALTH_MEASUREMENT")
                    .module("HEALTH")
                    .id(m.getId())
                    .title(m.getType() != null ? m.getType().name() : "Measurement")
                    .subtitle(m.getValue() + " " + m.getUnit() + (m.getValueDiastolic() != null ? " / " + m.getValueDiastolic() : ""))
                    .timestamp(m.getMeasuredAt())
                    .route("health/measurement/" + m.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchHealthSleepRecords(UUID userId, String searchTerm) {
        Page<HealthSleepRecord> records = healthSleepRecordRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "startedAt")));
        List<SearchResult> results = new ArrayList<>();
        for (HealthSleepRecord rec : records.getContent()) {
            results.add(SearchResult.builder()
                    .type("SLEEP_RECORD")
                    .module("HEALTH")
                    .id(rec.getId())
                    .title("Sleep")
                    .subtitle(rec.getRating() != null ? "Rating: " + rec.getRating() + "/5" : "")
                    .timestamp(rec.getStartedAt())
                    .route("health/sleep/" + rec.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchMeals(UUID userId, String searchTerm) {
        Page<Meal> meals = mealRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "consumedAt")));
        List<SearchResult> results = new ArrayList<>();
        for (Meal meal : meals.getContent()) {
            results.add(SearchResult.builder()
                    .type("MEAL")
                    .module("DIET")
                    .id(meal.getId())
                    .title(meal.getTitle())
                    .subtitle(meal.getMealType() != null ? meal.getMealType().name() : "")
                    .timestamp(meal.getConsumedAt())
                    .route("diet/meal/" + meal.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchMealItems(UUID userId, String searchTerm) {
        Page<MealItem> items = mealItemRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt")));
        List<SearchResult> results = new ArrayList<>();
        for (MealItem item : items.getContent()) {
            results.add(SearchResult.builder()
                    .type("MEAL_ITEM")
                    .module("DIET")
                    .id(item.getId())
                    .title(item.getName())
                    .subtitle(item.getQuantity() != null ? item.getQuantity() + " " + item.getUnit() : "")
                    .timestamp(item.getCreatedAt() != null ? item.getCreatedAt().atOffset(java.time.ZoneOffset.UTC) : OffsetDateTime.now())
                    .route("diet/meal/" + item.getMeal().getId() + "/item/" + item.getId())
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchDietProfiles(UUID userId, String searchTerm) {
        var profiles = dietProfileRepository.searchByText(userId, searchTerm);
        List<SearchResult> results = new ArrayList<>();
        for (DietProfile profile : profiles) {
            results.add(SearchResult.builder()
                    .type("DIET_PROFILE")
                    .module("DIET")
                    .id(profile.getId())
                    .title("Diet Profile")
                    .subtitle(profile.getDietaryPreference() != null ? profile.getDietaryPreference().name() : "")
                    .timestamp(profile.getCreatedAt() != null ? profile.getCreatedAt().atOffset(java.time.ZoneOffset.UTC) : OffsetDateTime.now())
                    .route("diet/profile")
                    .build());
        }
        return results;
    }

    private List<SearchResult> searchWaterIntake(UUID userId, String searchTerm) {
        Page<WaterIntake> intake = waterIntakeRepository.searchByText(userId, searchTerm, PageRequest.of(0, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "consumedAt")));
        List<SearchResult> results = new ArrayList<>();
        for (WaterIntake w : intake.getContent()) {
            results.add(SearchResult.builder()
                    .type("WATER_INTAKE")
                    .module("DIET")
                    .id(w.getId())
                    .title("Water Intake")
                    .subtitle(w.getAmount() + " " + w.getUnit())
                    .timestamp(w.getConsumedAt())
                    .route("diet/water/" + w.getId())
                    .build());
        }
        return results;
    }
}