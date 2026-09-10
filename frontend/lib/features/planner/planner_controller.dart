import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'models/planner_event.dart';
import 'models/task.dart';
import 'models/task_list.dart';
import 'models/task_priority.dart';
import 'models/task_view.dart';
import 'models/today_view.dart';
import 'planner_api.dart';

/// App-facing state for the Planner module. Exposes loading/error state plus
/// tasks, task lists, events and the today view, and screens call the JSON-api
/// through this single place so the whole app stays consistent after each
/// mutation.
class PlannerController extends ChangeNotifier {
  PlannerController(this._api);

  final PlannerApi _api;

  bool _loading = false;
  bool _mutating = false;
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

  bool get loading => _loading;

  bool get mutating => _mutating;

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

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  Future<void> loadTasks({TaskView? view}) async {
    final requested = view ?? _taskView;
    _taskView = requested;
    await _run(() async {
      final page = await _api.listTasks(
        view: requested,
        taskListId: _taskListFilter,
        priority: _priorityFilter,
        size: 50,
      );
      _tasks = page.content;
      _totalTasks = page.totalElements;
    });
  }

  Future<void> setTaskView(TaskView view) async {
    if (view == _taskView) {
      return;
    }
    await loadTasks(view: view);
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

  Future<void> createTask({
    required String title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? dueTime,
    String? taskListId,
  }) async {
    await _api.createTask(
      title: title,
      description: description,
      status: status,
      priority: priority,
      dueDate: dueDate,
      dueTime: dueTime,
      taskListId: taskListId,
    );
    await _refreshTasksAndMeta();
  }

  Future<void> updateTask(
    String taskId, {
    required String title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? dueTime,
    String? taskListId,
  }) async {
    await _api.updateTask(
      taskId,
      title: title,
      description: description,
      status: status,
      priority: priority,
      dueDate: dueDate,
      dueTime: dueTime,
      taskListId: taskListId,
    );
    await _refreshTasksAndMeta();
  }

  Future<void> completeTask(String taskId) async {
    await _api.completeTask(taskId);
    await _refreshTasksAndMeta();
  }

  Future<void> reopenTask(String taskId) async {
    await _api.reopenTask(taskId);
    await _refreshTasksAndMeta();
  }

  Future<void> cancelTask(String taskId) async {
    await _api.cancelTask(taskId);
    await _refreshTasksAndMeta();
  }

  Future<void> deleteTask(String taskId) async {
    await _api.deleteTask(taskId);
    await _refreshTasksAndMeta();
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

  Future<void> createTaskList({required String name, String? description}) async {
    await _api.createTaskList(name: name, description: description);
    await loadTaskLists();
    await loadTasks();
  }

  Future<void> updateTaskList(
    String listId, {
    required String name,
    String? description,
  }) async {
    await _api.updateTaskList(listId, name: name, description: description);
    await loadTaskLists();
    await loadTasks();
  }

  Future<void> deleteTaskList(String listId) async {
    await _api.deleteTaskList(listId);
    if (_taskListFilter == listId) {
      _taskListFilter = null;
    }
    await loadTaskLists();
    await loadTasks();
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  Future<void> loadEvents() async {
    await _run(() async {
      final page = await _api.listEvents(size: 50);
      _events = page.content;
      _totalEvents = page.totalElements;
    });
  }

  Future<void> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startAt,
    required DateTime endAt,
    EventStatus? status,
  }) async {
    await _api.createEvent(
      title: title,
      description: description,
      location: location,
      startAt: startAt,
      endAt: endAt,
      status: status,
    );
    await _refreshEventsToday();
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
    await _api.updateEvent(
      eventId,
      title: title,
      description: description,
      location: location,
      startAt: startAt,
      endAt: endAt,
      status: status,
    );
    await _refreshEventsToday();
  }

  Future<void> deleteEvent(String eventId) async {
    await _api.deleteEvent(eventId);
    await _refreshEventsToday();
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

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  Future<void> _refreshTasksAndMeta() async {
    await _run(() async {
      final page = await _api.listTasks(
        view: _taskView,
        taskListId: _taskListFilter,
        priority: _priorityFilter,
        size: 50,
      );
      _tasks = page.content;
      _totalTasks = page.totalElements;
      if (_listsLoaded) {
        _taskLists = await _api.listTaskLists();
      }
      if (_today != null) {
        _today = await _api.today();
      }
    });
  }

  Future<void> _refreshEventsToday() async {
    await _run(() async {
      final page = await _api.listEvents(size: 50);
      _events = page.content;
      _totalEvents = page.totalElements;
      if (_today != null) {
        _today = await _api.today();
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
    }
    _loading = false;
    notifyListeners();
  }
}