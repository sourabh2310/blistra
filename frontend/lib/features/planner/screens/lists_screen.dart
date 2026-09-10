import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import '../models/task_list.dart';
import '../widgets/status_views.dart';
import 'task_list_form_screen.dart';

/// The Lists tab: shows the user's task lists with their task counts.
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
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
        return Scaffold(
          body: _buildBody(context, planner),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(context, planner),
            tooltip: 'New list',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, dynamic planner) {
    if (planner.loading && planner.taskLists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (planner.error != null && planner.taskLists.isEmpty) {
      return ErrorRetry(message: planner.error!, onRetry: planner.loadTaskLists);
    }
    if (planner.taskLists.isEmpty) {
      return RefreshIndicator(
        onRefresh: planner.loadTaskLists,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.label,
              message: 'No lists yet.\nCreate one to organise your tasks.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: planner.loadTaskLists,
      child: ListView.separated(
        itemCount: planner.taskLists.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final list = planner.taskLists[index];
          return ListTile(
            onTap: () => _openForm(context, planner, list: list),
            leading: CircleAvatar(child: Text('${list.taskCount}')),
            title: Text(list.name),
            subtitle: list.description == null || list.description!.isEmpty
                ? null
                : Text(list.description!, overflow: TextOverflow.ellipsis),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openForm(context, planner, list: list);
                } else if (value == 'delete') {
                  _confirmDelete(context, planner, list);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          );
        },
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
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(list == null ? 'List created' : 'List updated')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, dynamic planner, TaskList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${list.name}"?'),
        content: const Text('Tasks in this list will be unassigned, not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) {
      planner.deleteTaskList(list.id);
    }
  }
}