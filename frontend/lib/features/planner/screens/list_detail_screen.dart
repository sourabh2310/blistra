import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../widgets/status_views.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';
import 'task_list_form_screen.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({
    super.key,
    required this.planner,
    required this.listId,
  });

  final PlannerController planner;
  final String listId;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  TaskList? _list;
  List<PlannerTask> _items = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.planner.loadTaskList(widget.listId),
        widget.planner.loadTasksForList(widget.listId),
      ]);
      if (!mounted) return;
      setState(() {
        _list = results[0] as TaskList;
        _items = results[1] as List<PlannerTask>;
      });
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't load this list.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editList() async {
    final list = _list;
    if (list == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskListFormScreen(planner: widget.planner, list: list),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _addItem() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(
          planner: widget.planner,
          initialListId: widget.listId,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteList() async {
    final list = _list;
    if (list == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this list?',
      message: 'Tasks in this list will be unassigned, not deleted.',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.planner.deleteTaskList(list.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't delete this list.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(
        title: const Text('List details'),
        actions: [
          TextButton(onPressed: list == null ? null : _editList, child: const Text('Edit')),
        ],
      ),
      body: _loading && list == null
          ? const SkeletonLoader(rows: 5)
          : _error != null && list == null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : list == null
                  ? const SizedBox.shrink()
                  : _body(context, list),
    );
  }

  Widget _body(BuildContext context, TaskList list) {
    final completed = _items.where((task) => task.status == TaskStatus.completed).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(list.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (list.description?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(list.description!),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('$completed / ${_items.length} completed', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: _items.isEmpty ? 0 : completed / _items.length, minHeight: 8, borderRadius: BorderRadius.circular(AppRadius.pill)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: 'Items', icon: Icons.checklist_rtl),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add item'),
          ),
        ),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text('No items in this list yet.'),
          )
        else
          for (final task in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ListTaskRow(
                task: task,
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(planner: widget.planner, taskId: task.id),
                    ),
                  );
                  _load();
                },
                onToggle: () async {
                  try {
                    if (task.status.isActive) {
                      await widget.planner.completeTask(task.id);
                    } else {
                      await widget.planner.reopenTask(task.id);
                    }
                    await _load();
                  } catch (_) {
                    if (context.mounted) showAppMessage(context, "Couldn't update this item.", error: true);
                  }
                },
              ),
            ),
        TextButton.icon(
          onPressed: _deleteList,
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete list'),
        ),
      ],
    );
  }
}

class _ListTaskRow extends StatelessWidget {
  const _ListTaskRow({required this.task, required this.onTap, required this.onToggle});

  final PlannerTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.completed;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: done ? 'Reopen item' : 'Complete item',
            onPressed: onToggle,
            icon: Icon(done ? Icons.check_box : Icons.check_box_outline_blank),
            color: done ? Theme.of(context).colorScheme.primary : null,
          ),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
