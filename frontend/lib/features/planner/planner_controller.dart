import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'models/event_status.dart';
import 'models/planner_event.dart';
import 'models/schedule_view.dart';
import 'models/task.dart';
import 'models/task_list.dart';
import 'models/task_priority.dart';
import 'models/task_reminder_mode.dart';
import 'models/task_status.dart';
import 'models/task_view.dart';
import 'models/today_view.dart';
import 'planner_api.dart';

/// App-facing state for the Planner module. Exposes loading/error state plus
/// tasks, task lists, events and the today view, and screens call the JSON-api
/// through this single place so the whole app stays consistent after each
/// mutation.
class PlannerController extends ChangeNotifier {
  PlannerController(
    this._api, {
    this.onRemindersChanged,
    this.onDashboardChanged,
  });

  final PlannerApi _api;
  final Future<void> Function()? onRemindersChanged;
  final Future<void> Function()? onDashboardChanged;

  int _loadingCount = 0;
  int _mutationCount = 0;
  String? _error;

  TaskView _taskView = TaskView.all;
  String? _taskListFilter;
  TaskPriority? _priorityFilter;

  List<PlannerTask> _tasks = [];
  int _totalTasks = 0;

  List<TaskList> _taskLists = [];
  bool _listsLoaded = false;

  List<PlannerEvent> _events = [];
  int _totalEvents = 0;

  TodayView? _today;

  // --- Date-navigable schedule (Planner page 02) ---------------------------
  DateTime _selectedDate = _day(DateTime.now());
  ScheduleScope _scope = ScheduleScope.day;
  ScheduleView? _schedule;
  bool _scheduleLoading = false;
  String? _scheduleError;
  int _scheduleRequest = 0;
  String _searchQuery = '';

  bool get loading => _loadingCount > 0;

  bool get mutating => _mutationCount > 0;

  String? get error => _error;

  TaskView get taskView => _taskView;

  String? get taskListFilter => _taskListFilter;

  TaskPriority? get priorityFilter => _priorityFilter;

  List<PlannerTask> get tasks => _tasks;

  int get totalTasks => _totalTasks;

  List<TaskList> get taskLists => _taskLists;

  List<PlannerEvent> get events => _events;

  int get totalEvents => _totalEvents;

  TodayView? get today => _today;

  DateTime get selectedDate => _selectedDate;
  ScheduleScope get scope => _scope;
  ScheduleView? get schedule => _schedule;
  bool get scheduleLoading => _scheduleLoading;
  String? get scheduleError => _scheduleError;
  String get searchQuery => _searchQuery;

  bool get isTodaySelected {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _selectedDate == today;
  }

  /// Schedule items ordered by start time (events and time-blocked tasks by
  /// startAt, untimed tasks by dueAt).
  List<PlannerEvent> get scheduleEventsOrdered {
    final events = List<PlannerEvent>.from(_schedule?.events ?? const []);
    events.sort((a, b) => a.startAt.compareTo(b.startAt));
    return _applyEventQuery(events);
  }

  List<PlannerTask> get scheduleTasksOrdered {
    final tasks = List<PlannerTask>.from(_schedule?.tasks ?? const []);
    tasks.sort((a, b) {
      final da = a.startAt ?? a.dueAt;
      final db = b.startAt ?? b.dueAt;
      if (da == null && db == null) return a.title.compareTo(b.title);
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return _applyTaskQuery(tasks);
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  Future<void> loadTasks({TaskView? view}) async {
    final requested = view ?? _taskView;
    _taskView = requested;
    await _run(() async {
      final result = await _fetchTasks(
        view: requested,
        taskListId: _taskListFilter,
        priority: _priorityFilter,
      );
      _tasks = result.tasks;
      _totalTasks = result.total;
    });
  }

  void selectTaskView(TaskView view) {
    if (_taskView == view) return;
    _taskView = view;
    notifyListeners();
  }

  Future<void> setTaskView(TaskView view) async {
    if (view == _taskView) {
      return;
    }
    selectTaskView(view);
    await loadTasks();
  }

  Future<void> setTaskListFilter(String? listId) async {
    if (listId == _taskListFilter) {
      return;
    }
    _taskListFilter = listId;
    await loadTasks();
  }

  Future<void> setPriorityFilter(TaskPriority? priority) async {
    if (priority == _priorityFilter) {
      return;
    }
    _priorityFilter = priority;
    await loadTasks();
  }

  Future<PlannerTask> loadTask(String taskId) => _api.getTask(taskId);

  Future<List<PlannerTask>> loadTasksForList(String listId) async {
    final result = await _fetchTasks(
      view: TaskView.all,
      taskListId: listId,
    );
    return result.tasks;
  }

  Future<void> createTask({
    required String title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? dueTime,
    DateTime? startAt,
    DateTime? endAt,
    TaskReminderMode? reminderMode,
    String? taskListId,
  }) async {
    await _runMutation(() => _api.createTask(
      title: title,
      description: description,
      status: status,
      priority: priority,
      dueDate: dueDate,
      dueTime: dueTime,
      startAt: startAt,
      endAt: endAt,
      reminderMode: reminderMode,
      taskListId: taskListId,
    ));
    await _refreshTasksAndMeta();
    await _syncTaskReminders();
    await _refreshDashboardQuiet();
  }

  Future<void> updateTask(
    String taskId, {
    required String title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? dueTime,
    DateTime? startAt,
    DateTime? endAt,
    TaskReminderMode? reminderMode,
    String? taskListId,
  }) async {
    await _runMutation(() => _api.updateTask(
      taskId,
      title: title,
      description: description,
      status: status,
      priority: priority,
      dueDate: dueDate,
      dueTime: dueTime,
      startAt: startAt,
      endAt: endAt,
      reminderMode: reminderMode,
      taskListId: taskListId,
    ));
    await _refreshTasksAndMeta();
    await _syncTaskReminders();
    await _refreshDashboardQuiet();
  }

  Future<void> completeTask(String taskId) async {
    await _runMutation(() => _api.completeTask(taskId));
    await _refreshTasksAndMeta();
    await _syncTaskReminders();
    await _refreshDashboardQuiet();
  }

  Future<void> reopenTask(String taskId) async {
    await _runMutation(() => _api.reopenTask(taskId));
    await _refreshTasksAndMeta();
    await _syncTaskReminders();
    await _refreshDashboardQuiet();
  }

  Future<void> cancelTask(String taskId) async {
    await _runMutation(() => _api.cancelTask(taskId));
    await _refreshTasksAndMeta();
    await _syncTaskReminders();
    await _refreshDashboardQuiet();
  }

  Future<void> deleteTask(String taskId) async {
    await _runMutation(() => _api.deleteTask(taskId));
    await _refreshTasksAndMeta();
    await _syncTaskReminders();
    await _refreshDashboardQuiet();
  }

  // ---------------------------------------------------------------------------
  // Task lists
  // ---------------------------------------------------------------------------

  Future<void> loadTaskLists() async {
    await _run(() async {
      _taskLists = await _api.listTaskLists();
      _listsLoaded = true;
    });
  }

  Future<TaskList> loadTaskList(String listId) => _api.getTaskList(listId);

  Future<void> createTaskList({required String name, String? description}) async {
    await _runMutation(() => _api.createTaskList(name: name, description: description));
    await _refreshListViews();
  }

  Future<void> updateTaskList(
    String listId, {
    required String name,
    String? description,
  }) async {
    await _runMutation(
      () => _api.updateTaskList(listId, name: name, description: description),
    );
    await _refreshListViews();
  }

  Future<void> deleteTaskList(String listId) async {
    await _runMutation(() => _api.deleteTaskList(listId));
    if (_taskListFilter == listId) {
      _taskListFilter = null;
    }
    await _refreshListViews();
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  Future<void> loadEvents() async {
    await _run(() async {
      final result = await _fetchEvents();
      _events = result.events;
      _totalEvents = result.total;
    });
  }

  Future<PlannerEvent> loadEvent(String eventId) => _api.getEvent(eventId);

  Future<void> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startAt,
    required DateTime endAt,
    EventStatus? status,
  }) async {
    await _runMutation(() => _api.createEvent(
      title: title,
      description: description,
      location: location,
      startAt: startAt,
      endAt: endAt,
      status: status,
    ));
    await _refreshEventsToday();
    await _refreshDashboardQuiet();
  }

  Future<void> updateEvent(
    String eventId, {
    required String title,
    String? description,
    String? location,
    required DateTime startAt,
    required DateTime endAt,
    EventStatus? status,
  }) async {
    await _runMutation(() => _api.updateEvent(
      eventId,
      title: title,
      description: description,
      location: location,
      startAt: startAt,
      endAt: endAt,
      status: status,
    ));
    await _refreshEventsToday();
    await _refreshDashboardQuiet();
  }

  Future<void> deleteEvent(String eventId) async {
    await _runMutation(() => _api.deleteEvent(eventId));
    await _refreshEventsToday();
    await _refreshDashboardQuiet();
  }

  Future<PlannerEvent> completeEvent(String eventId) async {
    final updated = await _runMutation(() => _api.completeEvent(eventId));
    await _refreshEventsToday();
    await _refreshDashboardQuiet();
    return updated;
  }

  Future<PlannerEvent> cancelEvent(String eventId) async {
    final updated = await _runMutation(() => _api.cancelEvent(eventId));
    await _refreshEventsToday();
    await _refreshDashboardQuiet();
    return updated;
  }

  Future<PlannerEvent> reopenEvent(String eventId) async {
    final updated = await _runMutation(() => _api.reopenEvent(eventId));
    await _refreshEventsToday();
    await _refreshDashboardQuiet();
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Today
  // ---------------------------------------------------------------------------

  Future<void> loadToday() async {
    await _run(() async {
      _today = await _api.today();
    });
  }

  // ---------------------------------------------------------------------------
  // Date-navigable schedule
  // ---------------------------------------------------------------------------

  Future<void> loadSchedule() async {
    final request = ++_scheduleRequest;
    final date = _selectedDate;
    final days = _scope.days;
    _scheduleLoading = true;
    _scheduleError = null;
    notifyListeners();
    try {
      final schedule = await _api.schedule(date: date, days: days);
      if (request != _scheduleRequest) return;
      _schedule = schedule;
    } on ApiException catch (e) {
      if (request == _scheduleRequest) _scheduleError = e.message;
    } catch (_) {
      if (request == _scheduleRequest) {
        _scheduleError = 'Something went wrong. Please try again.';
      }
    } finally {
      if (request == _scheduleRequest) {
        _scheduleLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectDate(DateTime date) async {
    var day = _day(date);
    if (_scope == ScheduleScope.week) {
      day = day.subtract(Duration(days: day.weekday - 1));
    }
    if (day == _selectedDate) return;
    _selectedDate = day;
    notifyListeners();
    await loadSchedule();
  }

  Future<void> goToToday() async {
    final now = DateTime.now();
    var day = _day(now);
    if (_scope == ScheduleScope.week) {
      day = day.subtract(Duration(days: day.weekday - 1));
    }
    _selectedDate = day;
    notifyListeners();
    await loadSchedule();
  }

  Future<void> previousDay() async {
    final step = _scope == ScheduleScope.week ? 7 : 1;
    _selectedDate = _selectedDate.subtract(Duration(days: step));
    notifyListeners();
    await loadSchedule();
  }

  Future<void> nextDay() async {
    final step = _scope == ScheduleScope.week ? 7 : 1;
    _selectedDate = _selectedDate.add(Duration(days: step));
    notifyListeners();
    await loadSchedule();
  }

  Future<void> setScope(ScheduleScope scope) async {
    if (scope == _scope) return;
    _scope = scope;
    if (scope == ScheduleScope.week) {
      // Snap week windows to Monday so the strip is stable.
      final weekday = _selectedDate.weekday;
      _selectedDate = _selectedDate.subtract(Duration(days: weekday - 1));
    }
    notifyListeners();
    await loadSchedule();
  }

  void setSearchQuery(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    notifyListeners();
  }

  List<PlannerEvent> _applyEventQuery(List<PlannerEvent> events) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return events;
    return events.where((e) {
      return e.title.toLowerCase().contains(q) ||
          (e.description?.toLowerCase().contains(q) ?? false) ||
          (e.location?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<PlannerTask> _applyTaskQuery(List<PlannerTask> tasks) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return tasks;
    return tasks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          (t.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ---------------------------------------------------------------------------

  Future<void> _syncTaskReminders() async {
    try {
      await onRemindersChanged?.call();
    } catch (_) {
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  Future<({List<PlannerTask> tasks, int total})> _fetchTasks({
    required TaskView view,
    String? taskListId,
    TaskPriority? priority,
  }) async {
    final tasks = <PlannerTask>[];
    var page = 0;
    var total = 0;
    var last = false;
    do {
      final result = await _api.listTasks(
        view: view,
        taskListId: taskListId,
        priority: priority,
        page: page,
        size: 50,
      );
      tasks.addAll(result.content);
      total = result.totalElements;
      last = result.last || result.content.isEmpty;
      page++;
    } while (!last && page < 100);
    return (tasks: tasks, total: total);
  }

  Future<({List<PlannerEvent> events, int total})> _fetchEvents() async {
    final events = <PlannerEvent>[];
    var page = 0;
    var total = 0;
    var last = false;
    do {
      final result = await _api.listEvents(page: page, size: 50);
      events.addAll(result.content);
      total = result.totalElements;
      last = result.last || result.content.isEmpty;
      page++;
    } while (!last && page < 100);
    return (events: events, total: total);
  }

  Future<void> _refreshTasksAndMeta() async {
    await _run(() async {
      final result = await _fetchTasks(
        view: _taskView,
        taskListId: _taskListFilter,
        priority: _priorityFilter,
      );
      _tasks = result.tasks;
      _totalTasks = result.total;
      if (_listsLoaded) {
        _taskLists = await _api.listTaskLists();
      }
      _today = await _api.today();
      if (_schedule != null) {
        _schedule = await _api.schedule(
          date: _selectedDate,
          days: _scope.days,
        );
        _scheduleError = null;
      }
    });
  }

  Future<void> _refreshEventsToday() async {
    await _run(() async {
      final result = await _fetchEvents();
      _events = result.events;
      _totalEvents = result.total;
      _today = await _api.today();
      // Keep the date-navigable schedule in sync without extra callers.
      try {
        _schedule = await _api.schedule(
          date: _selectedDate,
          days: _scope.days,
        );
        _scheduleError = null;
      } on ApiException catch (e) {
        _scheduleError = e.message;
      }
    });
  }

  Future<void> _refreshListViews() async {
    await _run(() async {
      _taskLists = await _api.listTaskLists();
      _listsLoaded = true;
      final result = await _fetchTasks(
        view: _taskView,
        taskListId: _taskListFilter,
        priority: _priorityFilter,
      );
      _tasks = result.tasks;
      _totalTasks = result.total;
      _today = await _api.today();
      if (_schedule != null) {
        _schedule = await _api.schedule(
          date: _selectedDate,
          days: _scope.days,
        );
        _scheduleError = null;
      }
    });
    await _refreshDashboardQuiet();
  }

  Future<void> _refreshDashboardQuiet() async {
    try {
      await onDashboardChanged?.call();
    } catch (_) {
    }
  }

  Future<T> _runMutation<T>(Future<T> Function() action) async {
    _mutationCount++;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } catch (_) {
      _error = "Couldn't save this Planner item. Try again.";
      rethrow;
    } finally {
      _mutationCount--;
      notifyListeners();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _error = null;
    _loadingCount++;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    }
    _loadingCount--;
    notifyListeners();
  }
}