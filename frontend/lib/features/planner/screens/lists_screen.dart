import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import '../models/task_list.dart';
import '../widgets/status_views.dart';
import 'task_list_form_screen.dart';

/// Lists tab: checklists/collections, distinct from Tasks.
///
/// A list groups related items (shopping, travel, moving) — it is not a
/// scheduled event. The backend genuinely supports lists
/// (`GET /api/v1/planner/lists`), so this tab is real, not a placeholder.
/// Content-only widget with an inline "+ Create list" CTA.
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  static const _teal = Color(0xFF0C6B6B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planner = AppScope.of(context).planner;
      if (planner.taskLists.isEmpty) {
        planner.loadTaskLists();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        return RefreshIndicator(
          color: _teal,
          onRefresh: planner.loadTaskLists,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context, planner)),
              _bodySliver(context, planner),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, dynamic planner) {
    final lists = _visibleLists(planner);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lists',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828))),
                Text(
                  lists.isEmpty
                      ? 'Checklists, not schedule'
                      : '${lists.length} list${lists.length == 1 ? '' : 's'}',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openForm(context, planner),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create list'),
          ),
        ],
      ),
    );
  }

  Widget _bodySliver(BuildContext context, dynamic planner) {
    if (planner.loading && (planner.taskLists as List).isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }
    if (planner.error != null && (planner.taskLists as List).isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorRetry(
            message: planner.error as String,
            onRetry: planner.loadTaskLists),
      );
    }
    final lists = _visibleLists(planner);
    if (lists.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(context, planner));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding:
              EdgeInsets.fromLTRB(16, index == 0 ? 12 : 8, 16, 0),
          child: _ListCard(
            list: lists[index],
            onOpen: () =>
                _openForm(context, planner, list: lists[index]),
            onDelete: () =>
                _confirmDelete(context, planner, lists[index]),
          ),
        ),
        childCount: lists.length,
      ),
    );
  }

  List<TaskList> _visibleLists(dynamic planner) {
    final all = List<TaskList>.from(planner.taskLists as List<TaskList>);
    final q = (planner.searchQuery as String).trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            (l.description?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Widget _emptyState(BuildContext context, dynamic planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFF1EAFE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_outlined,
                  size: 30, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 12),
            const Text('No lists yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Create a checklist for things you want to keep organized.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085))),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () => _openForm(context, planner),
              icon: const Icon(Icons.add),
              label: const Text('Create list'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    dynamic planner, {
    TaskList? list,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskListFormScreen(planner: planner, list: list),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(list == null ? 'List created' : 'List updated')),
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, dynamic planner, TaskList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${list.name}"?'),
        content: const Text(
            'Tasks in this list will be unassigned, not deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) {
      planner.deleteTaskList(list.id);
    }
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard(
      {required this.list, required this.onOpen, required this.onDelete});

  final TaskList list;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF1EAFE),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${list.taskCount}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C3AED)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  if (list.description?.isNotEmpty == true)
                    Text(list.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF667085))),
                  const SizedBox(height: 2),
                  Text(
                    '${list.taskCount} task${list.taskCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF0C6B6B)),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onOpen();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
