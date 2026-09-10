import '../core/api_client.dart';
import 'models/page_response.dart';
import 'models/planner_event.dart';
import 'models/task.dart';
import 'models/task_list.dart';
import 'models/task_priority.dart';
import 'models/task_view.dart';
import 'models/today_view.dart';

/// Typed client for the Planner API surface
/// ({@code /api/v1/planner/...}).
class PlannerApi {
  PlannerApi(this._api);

  final ApiClient _api;

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  Future<PageResponse<PlannerTask>> listTasks({
    TaskView view = TaskView.all,
    String? taskListId,
    TaskPriority? priority,
    int page = 0,
    int size = 20,
  }) async {
    final data = await _api.get('/api/v1/planner/tasks', query: {
      'view': view.wireName,
      'page': '$page',
      'size': '$size',
      if (taskListId != null) 'taskListId': taskListId,
      if (priority != null) 'priority': priority.wireName,
    });
    return PageResponse.fromJson(
        data as Map<String, dynamic>, PlannerTask.fromJson);
  }

  Future<PlannerTask> createTask({
    required String title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? dueTime,
    String? taskListId,
  }) async {
    final data = await _api.post('/api/v1/planner/tasks', body: {
      'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status.wireName,
      if (priority != null) 'priority': priority.wireName,
      if (dueDate != null) 'dueDate': _date(dueDate),
      if (dueTime != null) 'dueTime': _time(dueTime),
      if (taskListId != null) 'taskListId': taskListId,
    });
    return PlannerTask.fromJson(data as Map<String, dynamic>);
  }

  Future<PlannerTask> updateTask(
    String taskId, {
    required String title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? dueTime,
    String? taskListId,
  }) async {
    final data = await _api.put('/api/v1/planner/tasks/$taskId', body: {
      'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status.wireName,
      if (priority != null) 'priority': priority.wireName,
      if (dueDate != null) 'dueDate': _date(dueDate),
      if (dueTime != null) 'dueTime': _time(dueTime),
      if (taskListId != null) 'taskListId': taskListId,
    });
    return PlannerTask.fromJson(data as Map<String, dynamic>);
  }

  Future<PlannerTask> completeTask(String taskId) async {
    final data = await _api.post('/api/v1/planner/tasks/$taskId/complete');
    return PlannerTask.fromJson(data as Map<String, dynamic>);
  }

  Future<PlannerTask> reopenTask(String taskId) async {
    final data = await _api.post('/api/v1/planner/tasks/$taskId/reopen');
    return PlannerTask.fromJson(data as Map<String, dynamic>);
  }

  Future<PlannerTask> cancelTask(String taskId) async {
    final data = await _api.post('/api/v1/planner/tasks/$taskId/cancel');
    return PlannerTask.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTask(String taskId) async {
    await _api.delete('/api/v1/planner/tasks/$taskId');
  }

  // ---------------------------------------------------------------------------
  // Task lists
  // ---------------------------------------------------------------------------

  Future<List<TaskList>> listTaskLists() async {
    final data = await _api.get('/api/v1/planner/lists');
    return [
      if (data is List)
        for (final item in data)
          if (item is Map<String, dynamic>) TaskList.fromJson(item),
    ];
  }

  Future<TaskList> createTaskList({
    required String name,
    String? description,
  }) async {
    final data = await _api.post('/api/v1/planner/lists', body: {
      'name': name,
      if (description != null) 'description': description,
    });
    return TaskList.fromJson(data as Map<String, dynamic>);
  }

  Future<TaskList> updateTaskList(
    String listId, {
    required String name,
    String? description,
  }) async {
    final data = await _api.put('/api/v1/planner/lists/$listId', body: {
      'name': name,
      if (description != null) 'description': description,
    });
    return TaskList.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTaskList(String listId) async {
    await _api.delete('/api/v1/planner/lists/$listId');
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  Future<PageResponse<PlannerEvent>> listEvents({
    int page = 0,
    int size = 20,
  }) async {
    final data = await _api.get('/api/v1/planner/events', query: {
      'page': '$page',
      'size': '$size',
    });
    return PageResponse.fromJson(
        data as Map<String, dynamic>, PlannerEvent.fromJson);
  }

  Future<PlannerEvent> createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startAt,
    required DateTime endAt,
    EventStatus? status,
  }) async {
    final data = await _api.post('/api/v1/planner/events', body: {
      'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      if (status != null) 'status': status.wireName,
    });
    return PlannerEvent.fromJson(data as Map<String, dynamic>);
  }

  Future<PlannerEvent> updateEvent(
    String eventId, {
    required String title,
    String? description,
    String? location,
    required DateTime startAt,
    required DateTime endAt,
    EventStatus? status,
  }) async {
    final data = await _api.put('/api/v1/planner/events/$eventId', body: {
      'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      if (status != null) 'status': status.wireName,
    });
    return PlannerEvent.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String eventId) async {
    await _api.delete('/api/v1/planner/events/$eventId');
  }

  // ---------------------------------------------------------------------------
  // Today
  // ---------------------------------------------------------------------------

  Future<TodayView> today() async {
    final data = await _api.get('/api/v1/planner/today');
    return TodayView.fromJson(data as Map<String, dynamic>);
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}