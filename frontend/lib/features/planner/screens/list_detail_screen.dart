import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../widgets/planner_parts.dart';
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
  final Set<String> _busy = {};

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

  Future<void> _toggle(PlannerTask task) async {
    setState(() => _busy.add(task.id));
    try {
      if (task.status.isActive) {
        await widget.planner.completeTask(task.id);
      } else {
        await widget.planner.reopenTask(task.id);
      }
      await _load();
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't update this item.", error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(task.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      bottomNavigationBar: list == null ? null : StickyActionBar(label: 'Add item', onPressed: _addItem),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BlistraPageHeader(
              eyebrow: 'List',
              title: list?.name ?? 'List details',
              subtitle: list?.description?.isNotEmpty == true ? list!.description : null,
              showAvatar: false,
              actions: [
                GlassIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit list',
                  onTap: list == null ? null : _editList,
                ),
                PopupMenuButton<int>(
                  tooltip: 'More list actions',
                  enabled: list != null,
                  onSelected: (_) => _deleteList(),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 0,
                      child: Text('Delete list', style: TextStyle(color: BlistraColors.resolve(context).danger)),
                    ),
                  ],
                  child: const IgnorePointer(
                    child: GlassIconButton(icon: Icons.more_horiz, tooltip: null, onTap: null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && list == null)
              const SkeletonLoader(rows: 5, rowHeight: 56)
            else if (_error != null && list == null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (list != null)
              ..._body(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final completed = _items.where((task) => task.status == TaskStatus.completed).length;
    final total = _items.length;
    final left = total - completed;
    return [
      PagePad(
        StatusCard(
          caption: 'Progress',
          title: '$completed / $total completed',
          subtitle: total == 0 ? 'No items yet' : '$left ${left == 1 ? 'item' : 'items'} left',
          leading: ProgressRing(
            progress: total == 0 ? 0 : completed / total,
            size: 56,
            stroke: 6,
            child: Text(
              total == 0 ? '0%' : '${(completed * 100 / total).round()}%',
              style: BlistraText.serif(13, colors.text),
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      SectionHeader(title: 'Items', actionLabel: '${_items.length}'),
      PagePad(
        _items.isEmpty
            ? const EmptyCard(message: 'No items in this list yet.')
            : GlassList(children: [
                for (final task in _items)
                  GlassRow(
                    leading: CheckCircle(
                      checked: task.status == TaskStatus.completed,
                      urgent: task.overdue && task.status.isActive,
                      busy: _busy.contains(task.id),
                      semanticLabel: task.status == TaskStatus.completed ? 'Reopen item' : 'Complete item',
                      onTap: () => _toggle(task),
                    ),
                    title: task.title,
                    subtitle: task.status == TaskStatus.cancelled ? 'Cancelled' : null,
                    done: !task.status.isActive,
                    trailing: task.status.isActive ? PriorityPill(task.priority) : null,
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(planner: widget.planner, taskId: task.id),
                        ),
                      );
                      _load();
                    },
                  ),
              ]),
      ),
    ];
  }
}
