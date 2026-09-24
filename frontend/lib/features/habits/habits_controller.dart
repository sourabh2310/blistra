/// Application state for the habits feature.
///
/// [HabitsController] owns all habits data currently on screen, exposes it
/// to the UI via notifications, and is the single path through which every
/// mutation reaches the backend. After each successful mutation the affected
/// slices are re-fetched from the backend, which is the source of truth.
library;

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'habits_api.dart';
import 'models.dart';

enum HabitsLoadStatus { idle, loading, ready, error }

class HabitsController extends ChangeNotifier {
  HabitsController({required this.api, this.onMutated});

  final HabitsApi api;

  /// Invoked after a successful habit/schedule/completion mutation so owners
  /// (e.g. the app shell) can refresh dependent state such as the Home
  /// dashboard and Planner's aggregated habits. Never breaks Habits itself.
  final Future<void> Function()? onMutated;

  HabitsLoadStatus _status = HabitsLoadStatus.idle;
  String? _errorMessage;

  List<Habit> _habits = const [];
  List<HabitTodayResponse> _todayHabits = const [];

  HabitsLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  List<Habit> get habits => _habits;
  List<Habit> get activeHabits =>
      _habits.where((Habit h) => h.isActive).toList();
  List<HabitTodayResponse> get todayHabits => _todayHabits;
  List<HabitTodayResponse> get dueToday =>
      _todayHabits.where((HabitTodayResponse h) => !h.completedToday).toList();
  List<HabitTodayResponse> get doneToday =>
      _todayHabits.where((HabitTodayResponse h) => h.completedToday).toList();

  bool get isLoading => _status == HabitsLoadStatus.loading;
  bool get hasHabits => _habits.isNotEmpty;

  Future<void> loadAll() async {
    _status = HabitsLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await Future.wait([
        _loadHabits(),
        _loadTodayHabits(),
      ]);
      _status = HabitsLoadStatus.ready;
    } on ApiException catch (error) {
      _errorMessage = error.toString();
      _status = HabitsLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> refreshToday() async {
    try {
      await _loadTodayHabits();
    } on ApiException catch (error) {
      _errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<Habit> createHabit({
    required String name,
    required HabitType type,
    String? description,
    String? targetValue,
    String? targetUnit,
    int? targetMinutes,
    HabitStatus? status,
  }) async {
    final Habit created = await api.createHabit(
      name: name,
      type: type,
      description: description,
      targetValue: targetValue,
      targetUnit: targetUnit,
      targetMinutes: targetMinutes,
      status: status,
    );
    _habits = [..._habits, created]..sort(_compareNewestFirst);
    notifyListeners();
    await _notifyMutated();
    return created;
  }

  Future<Habit> updateHabit(
    String id, {
    required String name,
    required HabitType type,
    String? description,
    String? targetValue,
    String? targetUnit,
    int? targetMinutes,
    HabitStatus? status,
  }) async {
    final Habit updated = await api.updateHabit(
      id,
      name: name,
      type: type,
      description: description,
      targetValue: targetValue,
      targetUnit: targetUnit,
      targetMinutes: targetMinutes,
      status: status,
    );
    _habits = [
      for (final Habit h in _habits) h.id == id ? updated : h,
    ]..sort(_compareNewestFirst);
    notifyListeners();
    await _notifyMutated();
    return updated;
  }

  Future<void> archiveHabit(String id) async {
    await api.archiveHabit(id);
    await _loadHabits();
    await _loadTodayHabits();
    await _notifyMutated();
  }

  Future<Schedule> upsertSchedule(
    String habitId, {
    required HabitFrequency frequency,
    List<String>? daysOfWeek,
  }) async {
    final Schedule schedule = await api.upsertSchedule(habitId,
        frequency: frequency, daysOfWeek: daysOfWeek);
    await _notifyMutated();
    return schedule;
  }

  Future<Completion> recordCompletion(
    String habitId, {
    required DateTime completedOn,
    String? value,
    int? durationMinutes,
  }) async {
    final Completion completion = await api.recordCompletion(
      habitId,
      completedOn: completedOn,
      value: value,
      durationMinutes: durationMinutes,
    );
    await _loadTodayHabits();
    await _notifyMutated();
    return completion;
  }

  Future<void> removeCompletion(
    String habitId,
    DateTime completedOn,
  ) async {
    await api.removeCompletion(habitId, completedOn);
    await _loadTodayHabits();
    await _notifyMutated();
  }

  Future<HabitStatisticsResponse> fetchStatistics(String habitId) async {
    return api.fetchStatistics(habitId);
  }

  Future<void> _loadHabits() async {
    final PageResult<Habit> result = await api.fetchHabits(size: 200);
    _habits = result.items..sort(_compareNewestFirst);
  }

  Future<void> _loadTodayHabits() async {
    _todayHabits = await api.fetchTodayHabits();
  }

  Future<void> _notifyMutated() async {
    try {
      await onMutated?.call();
    } catch (_) {
      // Dependent refresh (e.g. dashboard) must never break Habits itself.
    }
  }

  static int _compareNewestFirst(Habit a, Habit b) {
    final int byDate = b.createdAt.compareTo(a.createdAt);
    if (byDate != 0) {
      return byDate;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }
}