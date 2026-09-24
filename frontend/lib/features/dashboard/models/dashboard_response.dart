
/// Complete dashboard aggregation for the authenticated user.
class DashboardResponse {
  DashboardResponse({
    required this.date,
    required this.generatedAt,
    this.user,
    this.planner,
    this.medicines,
    this.habits,
    this.diet,
    this.health,
    this.finance,
  });

  final DateTime date;
  final DateTime generatedAt;
  final DashboardUser? user;
  final PlannerSection? planner;
  final MedicineSection? medicines;
  final HabitSection? habits;
  final DietSection? diet;
  final HealthSection? health;
  final FinanceSection? finance;

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      date: DateTime.parse(json['date'] as String),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      planner: json['planner'] != null
          ? PlannerSection.fromJson(json['planner'] as Map<String, dynamic>)
          : null,
      medicines: json['medicines'] != null
          ? MedicineSection.fromJson(json['medicines'] as Map<String, dynamic>)
          : null,
      habits: json['habits'] != null
          ? HabitSection.fromJson(json['habits'] as Map<String, dynamic>)
          : null,
      diet: json['diet'] != null
          ? DietSection.fromJson(json['diet'] as Map<String, dynamic>)
          : null,
      health: json['health'] != null
          ? HealthSection.fromJson(json['health'] as Map<String, dynamic>)
          : null,
      finance: json['finance'] != null
          ? FinanceSection.fromJson(json['finance'] as Map<String, dynamic>)
          : null,
      user: json['user'] != null
          ? DashboardUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'generatedAt': generatedAt.toIso8601String(),
      if (user != null) 'user': user!.toJson(),
      if (planner != null) 'planner': planner!.toJson(),
      if (medicines != null) 'medicines': medicines!.toJson(),
      if (habits != null) 'habits': habits!.toJson(),
      if (diet != null) 'diet': diet!.toJson(),
      if (health != null) 'health': health!.toJson(),
      if (finance != null) 'finance': finance!.toJson(),
    };
  }
}

/// Planner section with overdue tasks, today's tasks, and today's events.
class PlannerSection {
  PlannerSection({
    required this.overdueTasks,
    required this.todayTasks,
    required this.todayEvents,
    required this.unavailable,
    this.error,
  });

  final List<TaskSummary> overdueTasks;
  final List<TaskSummary> todayTasks;
  final List<EventSummary> todayEvents;
  final bool unavailable;
  final String? error;

  factory PlannerSection.fromJson(Map<String, dynamic> json) {
    return PlannerSection(
      overdueTasks: _listFromJson(json['overdueTasks'], TaskSummary.fromJson),
      todayTasks: _listFromJson(json['todayTasks'], TaskSummary.fromJson),
      todayEvents: _listFromJson(json['todayEvents'], EventSummary.fromJson),
      unavailable: json['unavailable'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overdueTasks': overdueTasks.map((e) => e.toJson()).toList(),
      'todayTasks': todayTasks.map((e) => e.toJson()).toList(),
      'todayEvents': todayEvents.map((e) => e.toJson()).toList(),
      'unavailable': unavailable,
      if (error != null) 'error': error,
    };
  }
}

/// Medicine section with active medicines and today's doses.
class MedicineSection {
  MedicineSection({
    required this.activeMedicineCount,
    required this.dosesToday,
    required this.dosesTakenToday,
    required this.dosesRemainingToday,
    required this.unavailable,
    this.error,
  });

  final int activeMedicineCount;
  final List<DoseSummary> dosesToday;
  final int dosesTakenToday;
  final int dosesRemainingToday;
  final bool unavailable;
  final String? error;

  factory MedicineSection.fromJson(Map<String, dynamic> json) {
    return MedicineSection(
      activeMedicineCount: json['activeMedicineCount'] as int? ?? 0,
      dosesToday: _listFromJson(json['dosesToday'], DoseSummary.fromJson),
      dosesTakenToday: json['dosesTakenToday'] as int? ?? 0,
      dosesRemainingToday: json['dosesRemainingToday'] as int? ?? 0,
      unavailable: json['unavailable'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeMedicineCount': activeMedicineCount,
      'dosesToday': dosesToday.map((e) => e.toJson()).toList(),
      'dosesTakenToday': dosesTakenToday,
      'dosesRemainingToday': dosesRemainingToday,
      'unavailable': unavailable,
      if (error != null) 'error': error,
    };
  }
}

/// Habit section with today's habits and completion stats.
class HabitSection {
  HabitSection({
    required this.activeHabitCount,
    required this.expectedToday,
    required this.completedToday,
    required this.remainingToday,
    required this.todayHabits,
    required this.unavailable,
    this.error,
  });

  final int activeHabitCount;
  final int expectedToday;
  final int completedToday;
  final int remainingToday;
  final List<HabitSummary> todayHabits;
  final bool unavailable;
  final String? error;

  factory HabitSection.fromJson(Map<String, dynamic> json) {
    return HabitSection(
      activeHabitCount: json['activeHabitCount'] as int? ?? 0,
      expectedToday: json['expectedToday'] as int? ?? 0,
      completedToday: json['completedToday'] as int? ?? 0,
      remainingToday: json['remainingToday'] as int? ?? 0,
      todayHabits: _listFromJson(json['todayHabits'], HabitSummary.fromJson),
      unavailable: json['unavailable'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeHabitCount': activeHabitCount,
      'expectedToday': expectedToday,
      'completedToday': completedToday,
      'remainingToday': remainingToday,
      'todayHabits': todayHabits.map((e) => e.toJson()).toList(),
      'unavailable': unavailable,
      if (error != null) 'error': error,
    };
  }
}

/// Diet section with meals, water, and nutrition.
class DietSection {
  DietSection({
    required this.date,
    required this.mealCount,
    required this.meals,
    required this.waterCount,
    required this.water,
    this.waterTotalMilliliters,
    this.nutrition,
    required this.unavailable,
    this.error,
  });

  final DateTime date;
  final int mealCount;
  final List<MealSummary> meals;
  final int waterCount;
  final List<WaterSummary> water;
  final String? waterTotalMilliliters;
  final NutritionSummary? nutrition;
  final bool unavailable;
  final String? error;

  factory DietSection.fromJson(Map<String, dynamic> json) {
    return DietSection(
      date: DateTime.parse(json['date'] as String),
      mealCount: json['mealCount'] as int? ?? 0,
      meals: _listFromJson(json['meals'], MealSummary.fromJson),
      waterCount: json['waterCount'] as int? ?? 0,
      water: _listFromJson(json['water'], WaterSummary.fromJson),
      waterTotalMilliliters: json['waterTotalMilliliters'] as String?,
      nutrition: json['nutrition'] != null
          ? NutritionSummary.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
      unavailable: json['unavailable'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'mealCount': mealCount,
      'meals': meals.map((e) => e.toJson()).toList(),
      'waterCount': waterCount,
      'water': water.map((e) => e.toJson()).toList(),
      if (waterTotalMilliliters != null) 'waterTotalMilliliters': waterTotalMilliliters,
      if (nutrition != null) 'nutrition': nutrition!.toJson(),
      'unavailable': unavailable,
      if (error != null) 'error': error,
    };
  }
}

/// Health section with latest measurements and upcoming appointments.
class HealthSection {
  HealthSection({
    required this.latestMeasurements,
    required this.upcomingAppointments,
    required this.unavailable,
    this.error,
  });

  final List<MeasurementSummary> latestMeasurements;
  final List<AppointmentSummary> upcomingAppointments;
  final bool unavailable;
  final String? error;

  factory HealthSection.fromJson(Map<String, dynamic> json) {
    return HealthSection(
      latestMeasurements:
          _listFromJson(json['latestMeasurements'], MeasurementSummary.fromJson),
      upcomingAppointments:
          _listFromJson(json['upcomingAppointments'], AppointmentSummary.fromJson),
      unavailable: json['unavailable'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latestMeasurements':
          latestMeasurements.map((e) => e.toJson()).toList(),
      'upcomingAppointments':
          upcomingAppointments.map((e) => e.toJson()).toList(),
      'unavailable': unavailable,
      if (error != null) 'error': error,
    };
  }
}

/// Finance section with currency-wise income/expense.
class FinanceSection {
  FinanceSection({
    required this.from,
    required this.to,
    required this.currencies,
    required this.unavailable,
    this.error,
  });

  final DateTime from;
  final DateTime to;
  final List<CurrencySection> currencies;
  final bool unavailable;
  final String? error;

  factory FinanceSection.fromJson(Map<String, dynamic> json) {
    return FinanceSection(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      currencies: _listFromJson(json['currencies'], CurrencySection.fromJson),
      unavailable: json['unavailable'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from.toIso8601String().split('T')[0],
      'to': to.toIso8601String().split('T')[0],
      'currencies': currencies.map((e) => e.toJson()).toList(),
      'unavailable': unavailable,
      if (error != null) 'error': error,
    };
  }
}

// ============================================================================
// Nested summary models
// ============================================================================

class TaskSummary {
  TaskSummary({
    required this.id,
    required this.title,
    this.listId,
    this.listName,
    this.priority,
    this.status,
    this.dueAt,
  });

  final String id;
  final String title;
  final String? listId;
  final String? listName;
  final String? priority;
  final String? status;
  final String? dueAt;

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      listId: json['listId'] as String?,
      listName: json['listName'] as String?,
      priority: json['priority'] as String?,
      status: json['status'] as String?,
      dueAt: json['dueAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (listId != null) 'listId': listId,
        if (listName != null) 'listName': listName,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        if (dueAt != null) 'dueAt': dueAt,
      };
}

class EventSummary {
  EventSummary({
    required this.id,
    required this.title,
    required this.startAt,
    this.endAt,
  });

  final String id;
  final String title;
  final String startAt;
  final String? endAt;

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    return EventSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      startAt: json['startAt'] as String,
      endAt: json['endAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startAt': startAt,
        if (endAt != null) 'endAt': endAt,
      };
}

class DoseSummary {
  DoseSummary({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    this.scheduleId,
    required this.status,
    required this.scheduledAt,
    this.takenAt,
    this.doseAmount,
    this.doseUnit,
  });

  final String id;
  final String medicineId;
  final String medicineName;
  final String? scheduleId;
  final String status;
  final String scheduledAt;
  final String? takenAt;
  final String? doseAmount;
  final String? doseUnit;

  factory DoseSummary.fromJson(Map<String, dynamic> json) {
    return DoseSummary(
      id: json['id'] as String,
      medicineId: json['medicineId'] as String,
      medicineName: json['medicineName'] as String,
      scheduleId: json['scheduleId'] as String?,
      status: json['status'] as String,
      scheduledAt: json['scheduledAt'] as String,
      takenAt: json['takenAt'] as String?,
      doseAmount: json['doseAmount'] as String?,
      doseUnit: json['doseUnit'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineId': medicineId,
        'medicineName': medicineName,
        if (scheduleId != null) 'scheduleId': scheduleId,
        'status': status,
        'scheduledAt': scheduledAt,
        if (takenAt != null) 'takenAt': takenAt,
        if (doseAmount != null) 'doseAmount': doseAmount,
        if (doseUnit != null) 'doseUnit': doseUnit,
      };
}

class HabitSummary {
  HabitSummary({
    required this.id,
    required this.name,
    this.type,
    required this.completedToday,
    this.targetValue,
    this.targetUnit,
  });

  final String id;
  final String name;
  final String? type;
  final bool completedToday;
  final String? targetValue;
  final String? targetUnit;

  factory HabitSummary.fromJson(Map<String, dynamic> json) {
    return HabitSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      completedToday: json['completedToday'] as bool? ?? false,
      targetValue: json['targetValue'] as String?,
      targetUnit: json['targetUnit'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (type != null) 'type': type,
        'completedToday': completedToday,
        if (targetValue != null) 'targetValue': targetValue,
        if (targetUnit != null) 'targetUnit': targetUnit,
      };
}

class MealSummary {
  MealSummary({
    required this.id,
    this.type,
    this.consumedAt,
    required this.items,
  });

  final String id;
  final String? type;
  final String? consumedAt;
  final List<ItemSummary> items;

  factory MealSummary.fromJson(Map<String, dynamic> json) {
    return MealSummary(
      id: json['id'] as String,
      type: json['type'] as String?,
      consumedAt: json['consumedAt'] as String?,
      items: _listFromJson(json['items'], ItemSummary.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (type != null) 'type': type,
        if (consumedAt != null) 'consumedAt': consumedAt,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class ItemSummary {
  ItemSummary({
    required this.name,
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
    this.fiberG,
  });

  final String name;
  final String? caloriesKcal;
  final String? proteinG;
  final String? carbohydratesG;
  final String? fatG;
  final String? fiberG;

  factory ItemSummary.fromJson(Map<String, dynamic> json) {
    return ItemSummary(
      name: json['name'] as String,
      caloriesKcal: json['caloriesKcal'] as String?,
      proteinG: json['proteinG'] as String?,
      carbohydratesG: json['carbohydratesG'] as String?,
      fatG: json['fatG'] as String?,
      fiberG: json['fiberG'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (caloriesKcal != null) 'caloriesKcal': caloriesKcal,
        if (proteinG != null) 'proteinG': proteinG,
        if (carbohydratesG != null) 'carbohydratesG': carbohydratesG,
        if (fatG != null) 'fatG': fatG,
        if (fiberG != null) 'fiberG': fiberG,
      };
}

class WaterSummary {
  WaterSummary({
    required this.id,
    this.amount,
    this.unit,
    this.consumedAt,
  });

  final String id;
  final String? amount;
  final String? unit;
  final String? consumedAt;

  factory WaterSummary.fromJson(Map<String, dynamic> json) {
    return WaterSummary(
      id: json['id'] as String,
      amount: json['amount'] as String?,
      unit: json['unit'] as String?,
      consumedAt: json['consumedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (amount != null) 'amount': amount,
        if (unit != null) 'unit': unit,
        if (consumedAt != null) 'consumedAt': consumedAt,
      };
}

class NutritionSummary {
  NutritionSummary({
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
    this.fiberG,
  });

  final MacroSummary? caloriesKcal;
  final MacroSummary? proteinG;
  final MacroSummary? carbohydratesG;
  final MacroSummary? fatG;
  final MacroSummary? fiberG;

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    return NutritionSummary(
      caloriesKcal: json['caloriesKcal'] != null
          ? MacroSummary.fromJson(json['caloriesKcal'] as Map<String, dynamic>)
          : null,
      proteinG: json['proteinG'] != null
          ? MacroSummary.fromJson(json['proteinG'] as Map<String, dynamic>)
          : null,
      carbohydratesG: json['carbohydratesG'] != null
          ? MacroSummary.fromJson(json['carbohydratesG'] as Map<String, dynamic>)
          : null,
      fatG: json['fatG'] != null
          ? MacroSummary.fromJson(json['fatG'] as Map<String, dynamic>)
          : null,
      fiberG: json['fiberG'] != null
          ? MacroSummary.fromJson(json['fiberG'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (caloriesKcal != null) 'caloriesKcal': caloriesKcal!.toJson(),
        if (proteinG != null) 'proteinG': proteinG!.toJson(),
        if (carbohydratesG != null) 'carbohydratesG': carbohydratesG!.toJson(),
        if (fatG != null) 'fatG': fatG!.toJson(),
        if (fiberG != null) 'fiberG': fiberG!.toJson(),
      };
}

class MacroSummary {
  MacroSummary({
    this.total,
    this.recordedItems = 0,
  });

  final String? total;
  final int recordedItems;

  factory MacroSummary.fromJson(Map<String, dynamic> json) {
    return MacroSummary(
      total: json['total'] as String?,
      recordedItems: json['recordedItems'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (total != null) 'total': total,
        'recordedItems': recordedItems,
      };
}

class MeasurementSummary {
  MeasurementSummary({
    required this.type,
    this.value,
    this.valueDiastolic,
    this.unit,
    this.measuredAt,
  });

  final String type;
  final String? value;
  final String? valueDiastolic;
  final String? unit;
  final String? measuredAt;

  factory MeasurementSummary.fromJson(Map<String, dynamic> json) {
    return MeasurementSummary(
      type: json['type'] as String,
      value: json['value'] as String?,
      valueDiastolic: json['valueDiastolic'] as String?,
      unit: json['unit'] as String?,
      measuredAt: json['measuredAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (value != null) 'value': value,
        if (valueDiastolic != null) 'valueDiastolic': valueDiastolic,
        if (unit != null) 'unit': unit,
        if (measuredAt != null) 'measuredAt': measuredAt,
      };
}

class AppointmentSummary {
  AppointmentSummary({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.location,
    this.status,
  });

  final String id;
  final String title;
  final String scheduledAt;
  final String? location;
  final String? status;

  factory AppointmentSummary.fromJson(Map<String, dynamic> json) {
    return AppointmentSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      scheduledAt: json['scheduledAt'] as String,
      location: json['location'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scheduledAt': scheduledAt,
        if (location != null) 'location': location,
        if (status != null) 'status': status,
      };
}

class CurrencySection {
  CurrencySection({
    required this.currency,
    required this.income,
    required this.expense,
    required this.net,
    required this.transferIn,
    required this.transferOut,
    required this.topCategories,
  });

  final String currency;
  final String income;
  final String expense;
  final String net;
  final String transferIn;
  final String transferOut;
  final List<CategorySpend> topCategories;

  factory CurrencySection.fromJson(Map<String, dynamic> json) {
    return CurrencySection(
      currency: json['currency'] as String,
      income: json['income'] as String,
      expense: json['expense'] as String,
      net: json['net'] as String,
      transferIn: json['transferIn'] as String,
      transferOut: json['transferOut'] as String,
      topCategories:
          _listFromJson(json['topCategories'], CategorySpend.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'income': income,
        'expense': expense,
        'net': net,
        'transferIn': transferIn,
        'transferOut': transferOut,
        'topCategories': topCategories.map((e) => e.toJson()).toList(),
      };
}

class CategorySpend {
  CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  final String categoryId;
  final String categoryName;
  final String amount;

  factory CategorySpend.fromJson(Map<String, dynamic> json) {
    return CategorySpend(
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      amount: json['amount'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'amount': amount,
      };
}

class DashboardUser {
  DashboardUser({this.email, this.displayName, this.firstName});

  final String? email;
  final String? displayName;
  final String? firstName;

  factory DashboardUser.fromJson(Map<String, dynamic> json) {
    return DashboardUser(
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      firstName: json['firstName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (firstName != null) 'firstName': firstName,
      };
}

// ─── Pure Home helpers (no widgets): greeting, identity, day progress ───────

/// Time-of-day greeting per product spec (local hour).
/// 05:00–11:59 morning, 12:00–16:59 afternoon, 17:00–20:59 evening,
/// otherwise night (21:00–04:59).
String greetingForHour(int hour) {
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 21) return 'Good evening';
  return 'Good night';
}

/// Resolve the header name exclusively from authenticated user data.
/// Prefers backend firstName, then displayName, then the email local part.
/// Returns 'there' when nothing usable exists (never a hardcoded persona).
String resolveDisplayName({DashboardUser? user, String email = ''}) {
  final first = user?.firstName?.trim() ?? '';
  if (first.isNotEmpty) return first;
  final display = user?.displayName?.trim() ?? '';
  if (display.isNotEmpty) return display.split(RegExp(r'\s+')).first;
  final raw = (user?.email ?? email).trim();
  final local = raw.contains('@') ? raw.split('@').first : raw;
  final cleaned = local.replaceAll(RegExp(r'[._\-+]+'), ' ').trim();
  if (cleaned.isEmpty) return 'there';
  final words = cleaned.split(RegExp(r'\s+'));
  final firstWord = words.first;
  return firstWord[0].toUpperCase() + firstWord.substring(1);
}

/// Initials for the avatar, derived from the resolved display name.
String initialsForName(String name) {
  final clean = name.trim();
  if (clean.isEmpty || clean == 'there') return '';
  final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  final word = parts.first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (word.isEmpty) return '';
  if (word.length >= 2) return word.substring(0, 2).toUpperCase();
  return word.toUpperCase();
}

/// Deterministic day-at-a-glance status text for a completion ratio.
String dayStatusText(double pct) {
  if (pct >= 1.0) return "You're all caught up";
  if (pct >= 0.75) return "You're almost there";
  if (pct >= 0.5) return "You're making good progress";
  if (pct > 0.0) return "Let's keep moving";
  return "Let's get your day started";
}

/// Aggregated day progress across planner tasks, medicine doses and habits.
class DayProgress {
  DayProgress({
    required this.total,
    required this.completed,
    required this.attention,
  });

  final int total;
  final int completed;
  final int attention;

  double? get pct => total == 0 ? null : (completed / total).clamp(0.0, 1.0);
  bool get isEmpty => total == 0;

  String get label =>
      isEmpty ? 'No priorities yet' : '$completed of $total priorities completed';

  String get status => pct == null ? "You're all caught up" : dayStatusText(pct!);
}

/// Compute day progress purely from a dashboard payload (no fallbacks).
DayProgress computeDayProgress(DashboardResponse? dashboard, {DateTime? now}) {
  if (dashboard == null) return DayProgress(total: 0, completed: 0, attention: 0);
  final current = now ?? DateTime.now();

  int plannerTotal = 0;
  int plannerDone = 0;
  int overdue = 0;
  final planner = dashboard.planner;
  if (planner != null && !planner.unavailable) {
    final actionable = [...planner.todayTasks, ...planner.overdueTasks].where((t) {
      final s = (t.status ?? '').toUpperCase();
      return s != 'COMPLETED' && s != 'CANCELLED';
    }).toList();
    final done = [...planner.todayTasks, ...planner.overdueTasks].where((t) {
      return (t.status ?? '').toUpperCase() == 'COMPLETED';
    }).length;
    plannerTotal = actionable.length + done;
    plannerDone = done;
    overdue = planner.overdueTasks.where((t) {
      final s = (t.status ?? '').toUpperCase();
      return s != 'COMPLETED' && s != 'CANCELLED';
    }).length;
  }

  int medTotal = 0;
  int medDone = 0;
  int medOverdue = 0;
  final meds = dashboard.medicines;
  if (meds != null && !meds.unavailable) {
    medTotal = meds.dosesToday.length;
    medDone = meds.dosesToday
        .where((d) => d.status.toUpperCase() == 'TAKEN')
        .length;
    medOverdue = meds.dosesToday.where((d) {
      final s = d.status.toUpperCase();
      if (s == 'TAKEN' || s == 'CANCELLED' || s == 'SKIPPED') return false;
      final at = DateTime.tryParse(d.scheduledAt);
      return at != null && at.isBefore(current);
    }).length;
  }

  int habitTotal = 0;
  int habitDone = 0;
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    habitTotal = habits.expectedToday;
    habitDone = habits.completedToday.clamp(0, habits.expectedToday);
  }

  final total = plannerTotal + medTotal + habitTotal;
  final completed = plannerDone + medDone + habitDone;
  final attention = overdue + medOverdue + (habitTotal - habitDone);
  return DayProgress(total: total, completed: completed, attention: attention);
}

// Helper
List<T> _listFromJson<T>(Object? json, T Function(Map<String, dynamic>) fromJson) {
  if (json is! List) return [];
  return json
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList();
}