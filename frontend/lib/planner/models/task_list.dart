/// A user-owned task list/category, mirroring {@code TaskListResponse}.
class TaskList {
  TaskList({
    required this.id,
    required this.name,
    required this.taskCount,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final int taskCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TaskList.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];
    return TaskList(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      taskCount: (json['taskCount'] as num?)?.toInt() ?? 0,
      createdAt: createdAtRaw is String ? DateTime.parse(createdAtRaw) : null,
      updatedAt: updatedAtRaw is String ? DateTime.parse(updatedAtRaw) : null,
    );
  }
}