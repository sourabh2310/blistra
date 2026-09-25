import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../../../features/app_scope.dart';
import '../models/task_list.dart';
import '../planner_controller.dart';
import '../widgets/status_views.dart';
import 'list_detail_screen.dart';
import 'task_list_form_screen.dart';

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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context, planner)),
            ..._body(context, planner),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, PlannerController planner) {
    final lists = _visibleLists(planner);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Collections and checklists', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text('${lists.length} ${lists.length == 1 ? 'list' : 'lists'}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _openForm(context, planner),
            icon: const Icon(Icons.playlist_add),
            label: const Text('Create list'),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.taskLists.isEmpty) {
      return const [SliverToBoxAdapter(child: SkeletonLoader(rows: 4, rowHeight: 78))];
    }
    if (planner.error != null && planner.taskLists.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorRetry(
            message: "Couldn't load your lists.",
            onRetry: planner.loadTaskLists,
          ),
        ),
      ];
    }
    final lists = _visibleLists(planner);
    if (lists.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _emptyState(
            title: planner.searchQuery.trim().isNotEmpty ? 'No matching lists' : 'Create your first list',
            message: planner.searchQuery.trim().isNotEmpty
                ? 'Try a different Planner search.'
                : 'Use lists for shopping, packing, projects and other collections.',
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: lists.length,
        itemBuilder: (context, index) {
          final list = lists[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _ListCard(
              list: list,
              onOpen: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ListDetailScreen(planner: planner, listId: list.id),
                  ),
                );
              },
            ),
          );
        },
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

  Widget _emptyState({required String title, required String message}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: AppCard(
        child: Column(
          children: [
            Icon(Icons.checklist_rtl, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => _openForm(context, AppScope.of(context).planner),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Create list'),
            ),
          ],
        ),
      ),
    );
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

class _ListCard extends StatelessWidget {
  const _ListCard({required this.list, required this.onOpen});

  final TaskList list;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${list.taskCount}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(list.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (list.description?.isNotEmpty == true)
                  Text(list.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Text('${list.taskCount} assigned ${list.taskCount == 1 ? 'task' : 'tasks'}'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
