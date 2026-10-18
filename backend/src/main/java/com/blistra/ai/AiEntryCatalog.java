package com.blistra.ai;

import com.blistra.common.exception.BadRequestException;
import com.blistra.users.application.CurrentUserProvider;
import jakarta.validation.Validator;
import jakarta.validation.constraints.*;
import org.springframework.context.ApplicationContext;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.util.*;

/** Explicit command allowlist. Model output can never choose a class, method or URL. */
@Component
public class AiEntryCatalog {
    public record Field(String name, String label, String type, boolean required, List<String> choices,
                        List<Field> fields, Field item, Integer maxLength, String help, String reference) {}
    public record Entry(String key, String label, String module, List<Field> fields, String effect) {}
    private record Command(Entry entry, Class<?> dto, Object service, Method method, String parent,
                           java.util.function.Function<Object, Object> custom) {}
    public record GroupInput(@NotBlank @Size(max=100) String name,
                             @NotBlank @Pattern(regexp="^[A-Z]{3}$", message="Use a three-letter currency code such as INR.") String currency) {}
    private final Map<String, Command> commands = new LinkedHashMap<>();
    private final JsonMapper mapper;
    private final Validator validator;
    private final CurrentUserProvider users;
    private final ApplicationContext context;
    private final org.springframework.jdbc.core.JdbcTemplate jdbc;

    public AiEntryCatalog(ApplicationContext context, JsonMapper mapper, Validator validator, CurrentUserProvider users) {
        this.mapper = mapper; this.validator = validator; this.users = users; this.context = context;
        jdbc = context.getBean(org.springframework.jdbc.core.JdbcTemplate.class);
        add(context, "task", "Task", "Planner", "planner", "PlannerTaskService", "TaskCreateRequest", null);
        add(context, "task_list", "Task list", "Planner", "planner", "PlannerListService", "TaskListCreateRequest", null);
        add(context, "event", "Event", "Planner", "planner", "PlannerEventService", "EventCreateRequest", null);
        add(context, "measurement", "Health measurement", "Health", "health", "HealthMeasurementService", "MeasurementRequest", null);
        add(context, "activity", "Activity", "Health", "health", "ActivityService", "ActivityRequest", null);
        add(context, "sleep", "Sleep record", "Health", "health", "SleepRecordService", "SleepRecordRequest", null);
        add(context, "symptom", "Symptom log", "Health", "health", "HealthLogService", "HealthLogRequest", null);
        add(context, "health_event", "Health event", "Health", "health", "HealthEventService", "HealthEventRequest", null);
        add(context, "appointment", "Appointment", "Health", "health", "AppointmentService", "AppointmentRequest", null);
        add(context, "medicine", "Medicine", "Medicines", "medicines", "MedicineService", "MedicineRequest", null);
        add(context, "medicine_schedule", "Medicine schedule", "Medicines", "medicines", "MedicationScheduleService", "ScheduleRequest", "medicineId");
        add(context, "dose", "Dose record", "Medicines", "medicines", "DoseService", "DoseRequest", "medicineId");
        add(context, "refill", "Medicine refill", "Medicines", "medicines", "RefillService", "RefillRequest", "medicineId");
        add(context, "meal", "Meal and food items", "Diet", "diet", "MealService", "CreateMealRequest", "_owner");
        add(context, "meal_item", "Food item in a meal", "Diet", "diet", "MealService", "CreateMealItemRequest", "mealId");
        add(context, "water", "Water intake", "Diet", "diet", "WaterService", "WaterRequest", "_owner");
        add(context, "habit", "Habit", "Habits", "habits", "HabitService", "HabitRequest", null);
        add(context, "habit_completion", "Habit progress", "Habits", "habits", "HabitCompletionService", "CompletionRequest", "habitId");
        add(context, "habit_schedule", "Habit schedule", "Habits", "habits", "HabitScheduleService", "ScheduleRequest", "habitId");
        add(context, "expense", "Expense (personal or shared)", "Finance", "finance", "ExpenseService", "ExpenseRequest", null);
        add(context, "account", "Finance account", "Finance", "finance", "AccountService", "AccountRequest", null);
        add(context, "category", "Finance category", "Finance", "finance", "CategoryService", "CategoryRequest", null);
        add(context, "transaction", "Income or expense transaction", "Finance", "finance", "TransactionService", "TransactionRequest", null);
        add(context, "transfer", "Transfer", "Finance", "finance", "TransferService", "TransferRequest", null);
        add(context, "settlement", "Settlement proposal", "Finance", "finance", "SettlementService", "SettlementRequest", null);
        add(context, "reminder", "General reminder", "Reminders", "notifications", "ReminderService", "ReminderRequest", null);
        List<Field> groupFields = new ArrayList<>();
        for (var f : GroupInput.class.getDeclaredFields()) groupFields.add(field(f.getName(), f.getGenericType(), true, f));
        commands.put("trip_group", new Command(new Entry("trip_group", "Trip group", "Finance", groupFields,
                "Creates a trip group owned by you. No other people are invited automatically."), GroupInput.class,
                null, null, null, value -> { var g = (GroupInput) value;
                    return context.getBean(com.blistra.finance.application.FinanceGroupService.class).create(g.name(), g.currency()); }));
    }

    private void add(ApplicationContext ctx, String key, String label, String module, String pkg,
                     String serviceName, String dtoName, String parent) {
        try {
            Class<?> dto = Class.forName("com.blistra." + pkg + ".dto." + dtoName);
            Class<?> serviceType = Class.forName("com.blistra." + pkg + ".application." + serviceName);
            String methodName = key.equals("dose") || key.equals("habit_completion") ? "record"
                    : key.equals("habit_schedule") ? "upsert" : key.equals("meal_item") ? "addItem" : "create";
            Method method = key.equals("meal_item") ? serviceType.getMethod(methodName, UUID.class, UUID.class, dto)
                    : parent == null ? serviceType.getMethod(methodName, dto) : serviceType.getMethod(methodName, UUID.class, dto);
            List<Field> fields = new ArrayList<>();
            if (parent != null && !parent.equals("_owner")) fields.add(field(parent, UUID.class, true, null));
            for (var f : dto.getDeclaredFields()) {
                if (!Modifier.isStatic(f.getModifiers()) && !f.isSynthetic()) {
                    boolean required = f.isAnnotationPresent(NotNull.class) || f.isAnnotationPresent(NotBlank.class)
                            || f.isAnnotationPresent(NotEmpty.class) || f.getType().isPrimitive();
                    fields.add(field(f.getName(), f.getGenericType(), required, f));
                }
            }
            String effect = "Adds one " + label.toLowerCase(Locale.ROOT) + " in " + module
                    + ". Optional fields left blank use this module's existing defaults.";
            if (key.equals("settlement")) effect += " This proposes a settlement; the other participant must still confirm it.";
            if (key.equals("expense")) effect += " Participants create a shared expense; leave them empty for a personal expense.";
            if (key.equals("reminder")) effect += " Device delivery still depends on permissions and reminder sync.";
            if (key.equals("habit_schedule")) effect = "Creates or REPLACES the selected habit's existing schedule. Review the recurrence before approving.";
            commands.put(key, new Command(new Entry(key, label, module, List.copyOf(fields), effect), dto,
                    ctx.getBean(serviceType), method, parent, null));
        } catch (ReflectiveOperationException e) { throw new IllegalStateException("Invalid AI entry registration: " + key, e); }
    }

    private Field field(String name, Type generic, boolean required, java.lang.reflect.Field source) {
        Class<?> type = generic instanceof Class<?> c ? c : (Class<?>) ((ParameterizedType) generic).getRawType();
        String kind = "text";
        List<String> choices = List.of(); List<Field> children = List.of(); Field item = null;
        if (type.isEnum()) { kind = "choice"; choices = Arrays.stream(type.getEnumConstants()).map(Object::toString).toList(); }
        else if (Collection.class.isAssignableFrom(type)) {
            kind = "list";
            item = field("item", ((ParameterizedType) generic).getActualTypeArguments()[0], true, null);
            if (name.equals("times")) item = new Field("item", "Time", "time", true, List.of(), List.of(), null, null, "", "");
        } else if (type == boolean.class || type == Boolean.class) kind = "boolean";
        else if (type == int.class || type == Integer.class || type == Long.class || type == long.class) kind = "integer";
        else if (Number.class.isAssignableFrom(type)) kind = "number";
        else if (type == UUID.class) kind = "reference";
        else if (type == java.time.LocalDate.class) kind = "date";
        else if (type == java.time.LocalTime.class) kind = "time";
        else if (type == java.time.OffsetDateTime.class) kind = "datetime";
        else if (type != String.class) {
            kind = "object"; List<Field> nested = new ArrayList<>();
            for (var f : type.getDeclaredFields()) if (!Modifier.isStatic(f.getModifiers()) && !f.isSynthetic())
                nested.add(field(f.getName(), f.getGenericType(), f.isAnnotationPresent(NotNull.class)
                        || f.isAnnotationPresent(NotBlank.class) || f.isAnnotationPresent(NotEmpty.class) || f.getType().isPrimitive(), f));
            children = List.copyOf(nested);
        }
        Integer max = source != null && source.isAnnotationPresent(Size.class) ? source.getAnnotation(Size.class).max() : null;
        var schema = source == null ? null : source.getAnnotation(io.swagger.v3.oas.annotations.media.Schema.class);
        return new Field(name, label(name), kind, required, choices, children, item,
                max == null || max == Integer.MAX_VALUE ? null : max,
                schema == null ? "" : schema.description(), reference(name));
    }

    private String reference(String name) {
        return switch (name) {
            case "medicineId" -> "/api/v1/medicines";
            case "scheduleId" -> "/api/v1/medicines/{medicineId}/schedules";
            case "habitId" -> "/api/v1/habits";
            case "mealId" -> "/api/v1/diet/meals";
            case "taskListId" -> "/api/v1/planner/lists";
            case "accountId", "fromAccountId", "toAccountId", "sourceAccountId", "destinationAccountId" -> "/api/v1/finance/accounts";
            case "categoryId" -> "/api/v1/finance/categories";
            case "friendId", "paidBy", "userId" -> "/api/v1/finance/friends";
            case "groupId" -> "/api/v1/finance/groups";
            default -> "";
        };
    }

    public static String label(String name) {
        String text = name.replaceAll("([a-z])([A-Z])", "$1 $2").replaceAll(" Id$", "").replace('_', ' ');
        return Character.toUpperCase(text.charAt(0)) + text.substring(1);
    }
    public List<Entry> entries() { return commands.values().stream().map(Command::entry).toList(); }
    public Entry entry(String key) { return command(key).entry(); }
    private Command command(String key) {
        var result = commands.get(key);
        if (result == null) throw new BadRequestException("This entry type is not supported by Blistra AI.");
        return result;
    }

    public Map<String, String> errors(String key, Map<String, Object> data) {
        var cmd = command(key); Map<String, String> errors = new LinkedHashMap<>();
        checkFields(cmd.entry.fields(), data, "", errors);
        Map<String, Object> dtoData = new LinkedHashMap<>(data);
        if (cmd.parent != null && !cmd.parent.equals("_owner")) dtoData.remove(cmd.parent);
        try {
            Object dto = mapper.convertValue(dtoData, cmd.dto);
            for (var error : validator.validate(dto)) errors.putIfAbsent(error.getPropertyPath().toString(), error.getMessage());
            if (errors.isEmpty()) {
                try { preflight(key, dto, data, errors); }
                catch (com.blistra.common.exception.BadRequestException | com.blistra.common.exception.InvalidRequestException
                       | com.blistra.common.exception.ResourceNotFoundException | com.blistra.common.exception.InvalidStateException e) { errors.put("entry", e.getMessage()); }
            }
        } catch (RuntimeException e) {
            errors.putIfAbsent("entry", "Check field formats, required values and selections before approval.");
        }
        return errors;
    }

    private void preflight(String key, Object dto, Map<String, Object> data, Map<String, String> errors) {
            if (dto instanceof com.blistra.health.dto.MeasurementRequest measurement)
                context.getBean(com.blistra.health.application.MeasurementValidator.class).validate(measurement);
            for (String field : List.of("amount", "openingBalance")) if (data.get(field) != null && List.of("expense", "settlement", "transaction", "transfer", "account").contains(key)) {
                if (!data.get(field).toString().matches("^\\d{1,15}(?:\\.\\d{1,4})?$")) { errors.put(field, "Enter a decimal amount with at most 15 whole digits and 4 decimal places."); continue; }
                var amount = com.blistra.finance.domain.Money.parse(data.get(field).toString());
                if (amount.signum() < 0 || field.equals("amount") && amount.signum() == 0)
                    errors.put(field, "Enter a " + (field.equals("amount") ? "positive" : "non-negative") + " amount.");
            }
            if (data.get("currency") != null && !com.blistra.finance.domain.Money.isCurrencyCode(data.get("currency").toString())) errors.put("currency", "Choose a valid three-letter currency code.");
            range(data, "startAt", "endAt", errors);
            range(data, "startedAt", "endedAt", errors);
            if (key.equals("sleep")) {
                var request = (com.blistra.health.dto.SleepRecordRequest) dto;
                if (java.time.Duration.between(request.getStartedAt(), request.getEndedAt()).toMinutes() > 36 * 60) errors.put("endedAt", "Sleep duration cannot exceed 36 hours.");
            }
            if (key.equals("task") && data.get("dueTime") != null && data.get("dueDate") == null) errors.put("dueDate", "Supply the date for this due time.");
            if (key.equals("reminder")) {
                var r = (com.blistra.notifications.dto.ReminderRequest) dto;
                if (r.getType() != com.blistra.notifications.domain.ReminderType.GENERAL) errors.put("type", "Only GENERAL reminders can be created directly.");
                if (r.getSourceId() != null) errors.put("sourceId", "Leave the source unset for a general reminder.");
                try { java.time.ZoneId.of(r.getTimezone()); } catch (java.time.DateTimeException e) { errors.put("timezone", "Choose a valid timezone such as Asia/Kolkata."); }
                if (!r.getScheduledAt().isAfter(java.time.OffsetDateTime.now())) errors.put("scheduledAt", "Choose a future reminder time.");
            }
            if (key.equals("dose")) {
                var r = (com.blistra.medicines.dto.DoseRequest) dto;
                if (r.getStatus() != com.blistra.medicines.domain.DoseStatus.TAKEN && r.getTakenAt() != null) errors.put("takenAt", "Only TAKEN doses have a taken time.");
            }
            UUID owner = users.getCurrentUser().getId();
            // Fixed existence checks only. No model-chosen SQL, identifiers, tables or owner.
            Map<String, String> ownedTables = Map.of("medicineId", "medicines", "habitId", "habits", "mealId", "meals",
                    "taskListId", "planner_task_list", "accountId", "finance_accounts", "sourceAccountId", "finance_accounts",
                    "destinationAccountId", "finance_accounts", "categoryId", "finance_categories");
            for (var reference : ownedTables.entrySet()) if (data.get(reference.getKey()) != null) {
                Integer count = jdbc.queryForObject("SELECT count(*) FROM " + reference.getValue() + " WHERE id=? AND user_id=?", Integer.class, uuid(data, reference.getKey()), owner);
                if (count == null || count == 0) errors.put(reference.getKey(), "Select an existing " + label(reference.getKey()).toLowerCase(Locale.ROOT) + " that belongs to you.");
            }
            if (data.get("groupId") != null) {
                Integer count = jdbc.queryForObject("SELECT count(*) FROM finance_group_members WHERE group_id=? AND user_id=? AND status='ACCEPTED'", Integer.class, uuid(data, "groupId"), owner);
                if (count == null || count == 0) errors.put("groupId", "Select a group you have joined.");
            }
            if (data.get("scheduleId") != null && data.get("medicineId") != null) {
                Integer count = jdbc.queryForObject("SELECT count(*) FROM medication_schedules s JOIN medicines m ON m.id=s.medicine_id WHERE s.id=? AND m.id=? AND m.user_id=?", Integer.class,
                        uuid(data, "scheduleId"), uuid(data, "medicineId"), owner);
                if (count == null || count == 0) errors.put("scheduleId", "Select a schedule belonging to this medicine.");
            }
            if (key.equals("habit_completion") && data.get("habitId") != null) {
                var types = jdbc.queryForList("SELECT type FROM habits WHERE id=? AND user_id=?", String.class, uuid(data, "habitId"), owner);
                if (!types.isEmpty()) {
                    if (types.getFirst().equals("COUNT") && data.get("value") == null) errors.put("value", "Supply the recorded count for this habit.");
                    if (types.getFirst().equals("DURATION") && data.get("durationMinutes") == null) errors.put("durationMinutes", "Supply the recorded minutes for this habit.");
                }
            }
    }
    private UUID uuid(Map<String, Object> data, String name) { return UUID.fromString(data.get(name).toString()); }
    private void range(Map<String, Object> data, String start, String end, Map<String, String> errors) {
        if (data.get(end) != null && (data.get(start) == null || !java.time.OffsetDateTime.parse(data.get(end).toString()).isAfter(java.time.OffsetDateTime.parse(data.get(start).toString()))))
            errors.put(end, "End time must be after the start time.");
    }

    private void checkFields(List<Field> fields, Map<String, Object> data, String prefix, Map<String, String> errors) {
        Set<String> names = new HashSet<>();
        for (var f : fields) {
            names.add(f.name()); Object value = data.get(f.name()); String path = prefix + f.name();
            if (value == null || value instanceof String s && s.isBlank()) {
                if (f.required()) errors.put(path, f.label() + " is required.");
                continue;
            }
            if (f.type.equals("reference")) {
                try { UUID.fromString(value.toString()); } catch (RuntimeException ex) { errors.put(path, "Select " + f.label().toLowerCase(Locale.ROOT) + " from your existing records."); }
            }
            try {
                switch (f.type) {
                    case "date" -> java.time.LocalDate.parse(value.toString());
                    case "time" -> java.time.LocalTime.parse(value.toString());
                    case "datetime" -> java.time.OffsetDateTime.parse(value.toString());
                    case "integer" -> { new BigDecimal(value.toString()).toBigIntegerExact(); }
                    case "number" -> new BigDecimal(value.toString());
                    case "boolean" -> { if (!(value instanceof Boolean)) throw new IllegalArgumentException(); }
                    default -> { }
                }
            } catch (RuntimeException ex) { errors.put(path, "Check " + f.label().toLowerCase(Locale.ROOT) + ": a valid " + f.type + " is required."); }
            if (f.type.equals("object") && !(value instanceof Map)) errors.put(path, "Enter the individual fields for " + f.label() + ".");
            if (f.type.equals("list") && !(value instanceof List)) errors.put(path, "Add individual items for " + f.label() + ".");
            if (f.type.equals("choice") && !f.choices.contains(value.toString())) errors.put(path, "Choose a supported " + f.label().toLowerCase(Locale.ROOT) + ".");
            if (f.type.equals("object") && value instanceof Map<?, ?> map) checkFields(f.fields, stringMap(map), path + ".", errors);
            if (f.type.equals("list") && value instanceof List<?> list) {
                if (list.size() > 50) errors.put(path, "At most 50 items are allowed.");
                for (int i = 0; i < Math.min(list.size(), 50); i++) {
                    Object part = list.get(i);
                    if (part == null) errors.put(path + "[" + i + "]", "An item cannot be empty.");
                    else if (f.item.type.equals("object") && part instanceof Map<?, ?> map)
                        checkFields(f.item.fields, stringMap(map), path + "[" + i + "].", errors);
                }
            }
        }
        for (String name : data.keySet()) if (!names.contains(name)) errors.put(prefix + name, "Unknown field. Remove it before approval.");
    }
    private static Map<String, Object> stringMap(Map<?, ?> source) {
        Map<String, Object> result = new LinkedHashMap<>(); source.forEach((k, v) -> result.put(k.toString(), v)); return result;
    }

    public Object execute(String key, Map<String, Object> data) {
        var cmd = command(key);
        if (!errors(key, data).isEmpty()) throw new BadRequestException("Complete and validate the entry before approving it.");
        var dtoData = new LinkedHashMap<>(data);
        UUID parent = null;
        if (cmd.parent != null) parent = cmd.parent.equals("_owner") ? users.getCurrentUser().getId()
                : UUID.fromString(dtoData.remove(cmd.parent).toString());
        Object dto = mapper.convertValue(dtoData, cmd.dto);
        if (cmd.custom != null) return cmd.custom.apply(dto);
        try {
            if (key.equals("meal_item")) return cmd.method.invoke(cmd.service, users.getCurrentUser().getId(), parent, dto);
            return cmd.parent == null ? cmd.method.invoke(cmd.service, dto) : cmd.method.invoke(cmd.service, parent, dto);
        } catch (InvocationTargetException e) {
            if (e.getCause() instanceof RuntimeException cause) throw cause;
            throw new IllegalStateException("Entry service failed", e.getCause());
        } catch (ReflectiveOperationException e) { throw new IllegalStateException("Invalid registered entry command", e); }
    }
}
