import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../features/app_scope.dart';
import '../models/task_list.dart';
import '../planner_controller.dart';
import '../widgets/status_views.dart';
import 'list_detail_screen.dart';
import 'task_list_form_screen.dart';

/// Planner "Lists" tab: every task list with its task count.
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) => RefreshIndicator(
        onRefresh: planner.loadTaskLists,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 110),
          children: _body(context, planner),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.taskLists.isEmpty) {
      return const [SkeletonLoader(rows: 4, rowHeight: 64)];
    }
    if (planner.error != null && planner.taskLists.isEmpty) {
      return [
        ErrorRetry(
          message: "Couldn't load your lists.",
          onRetry: planner.loadTaskLists,
        ),
      ];
    }
    final lists = _visibleLists(planner);
    final searching = planner.searchQuery.trim().isNotEmpty;
    final total = lists.fold<int>(0, (sum, list) => sum + list.taskCount);
    return [
      SectionHeader(
        title: lists.isEmpty
            ? 'Lists'
            : '${lists.length} ${lists.length == 1 ? 'list' : 'lists'} · $total ${total == 1 ? 'task' : 'tasks'}',
        actionLabel: '+ Create list',
        onAction: () => _openForm(context, planner),
      ),
      PagePad(
        lists.isEmpty
            ? EmptyCard(
                message: searching
                    ? 'No matching lists. Try a different Planner search.'
                    : 'Use lists for shopping, packing, projects and other collections.',
                action: searching ? null : 'Create list',
                onAction: searching ? null : () => _openForm(context, planner),
              )
            : GlassList(children: [
                for (final list in lists) _ListRow(list: list, planner: planner),
              ]),
      ),
    ];
  }

  List<TaskList> _visibleLists(PlannerController planner) {
    final query = planner.searchQuery.trim().toLowerCase();
    if (query.isEmpty) return List<TaskList>.from(planner.taskLists);
    return planner.taskLists.where((list) {
      return list.name.toLowerCase().contains(query) ||
          (list.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _openForm(BuildContext context, PlannerController planner, {TaskList? list}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskListFormScreen(planner: planner, list: list),
      ),
    );
    if (saved == true && context.mounted) {
      showAppMessage(context, list == null ? 'List created' : 'List updated');
    }
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.list, required this.planner});

  final TaskList list;
  final PlannerController planner;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final count = '${list.taskCount} assigned ${list.taskCount == 1 ? 'task' : 'tasks'}';
    return GlassRow(
      leading: IconWell(Icons.checklist_rtl_rounded, color: colors.accentText),
      title: list.name,
      subtitle: list.description?.isNotEmpty == true ? list.description! : count,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${list.taskCount}', style: BlistraText.serif(17, colors.text)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 18, color: colors.muted),
        ],
      ),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ListDetailScreen(planner: planner, listId: list.id),
        ),
      ),
    );
  }
}
