/// Medicines list page with status filter, pagination, and archive.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../core/api/api_client.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../state/medicine_list_controller.dart';
import 'medicine_form_page.dart';
import 'medicine_detail_page.dart';

class MedicineListPage extends StatefulWidget {
  const MedicineListPage({super.key});

  @override
  State<MedicineListPage> createState() => _MedicineListPageState();
}

class _MedicineListPageState extends State<MedicineListPage> {
  MedicineListController? _controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final apiClient = context.read<ApiClient>();
      final authState = context.read<AuthState>();
      _controller = MedicineListController(
        MedicinesApiClient(
          tokenProvider: () => authState.apiClient.token ?? '',
        ),
      );
      _controller!.refresh();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().logout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.isLoading && controller.medicines.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error != null && controller.medicines.isEmpty) {
            return _ErrorRetry(
              message: controller.error.toString(),
              onRetry: controller.refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: Column(
              children: [
                _StatusFilterChips(controller: controller),
                Expanded(
                  child: controller.medicines.isEmpty
                      ? _EmptyState(onAdd: _pushAdd)
                      : ListView.builder(
                          itemCount: controller.medicines.length +
                              (controller.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == controller.medicines.length) {
                              if (controller.hasMore) {
                                controller.loadMore();
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            return _MedicineTile(
                              medicine: controller.medicines[index],
                              onTap: () => _pushDetail(
                                context,
                                controller.medicines[index].id,
                              ),
                              onArchive: controller.archive,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pushAdd,
        tooltip: 'Add medicine',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _pushAdd() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedicineFormPage()),
      );

  void _pushDetail(BuildContext context, String id) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MedicineDetailPage(medicineId: id)),
      );
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.controller});

  final MedicineListController controller;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      null,
      MedicineStatus.active,
      MedicineStatus.paused,
      MedicineStatus.completed,
      MedicineStatus.archived,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: statuses
            .map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s == null ? 'All' : s.name.toUpperCase()),
                    selected: controller.statusFilter == s,
                    onSelected: (_) => controller.setStatusFilter(s),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  const _MedicineTile({
    required this.medicine,
    required this.onTap,
    required this.onArchive,
  });

  final Medicine medicine;
  final VoidCallback onTap;
  final Future<void> Function(String) onArchive;

  @override
  Widget build(BuildContext context) {
    final isArchived = medicine.status == MedicineStatus.archived;

    return Dismissible(
      key: ValueKey(medicine.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Archive medicine?'),
                content: Text('Archive "${medicine.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Archive'),
                  ),
                ],
              ),
            ) ??
            false;
        if (ok && context.mounted) {
          await onArchive(medicine.id);
        }
        return false;
      },
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: _statusColor(medicine.status)
                .withValues(alpha: 0.15),
            child: Icon(
              _statusIcon(medicine.status),
              color: _statusColor(medicine.status),
            ),
          ),
          title: Text(medicine.name, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (medicine.genericName != null && medicine.genericName!.isNotEmpty)
                Text(medicine.genericName!,
                    style: Theme.of(context).textTheme.bodySmall),
              Text(
                [
                  if (medicine.form != null && medicine.form!.isNotEmpty) medicine.form,
                  if (medicine.strength != null) medicine.strengthLabel,
                  if (medicine.strengthUnit != null && medicine.strengthUnit!.isNotEmpty)
                    medicine.strengthUnit,
                ].where((e) => e != null && e.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          trailing: _StatusChip(status: medicine.status),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No medicines yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first medicine',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Medicine'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load medicines',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MedicineStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.name.toUpperCase(), style: const TextStyle(fontSize: 10)),
      backgroundColor: _statusColor(status).withValues(alpha: 0.15),
      side: BorderSide(color: _statusColor(status)),
      labelStyle: TextStyle(color: _statusColor(status)),
    );
  }
}

Color _statusColor(MedicineStatus status) {
  switch (status) {
    case MedicineStatus.active:
      return Colors.green;
    case MedicineStatus.paused:
      return Colors.orange;
    case MedicineStatus.completed:
      return Colors.blue;
    case MedicineStatus.archived:
      return Colors.grey;
  }
}

IconData _statusIcon(MedicineStatus status) {
  switch (status) {
    case MedicineStatus.active:
      return Icons.check_circle;
    case MedicineStatus.paused:
      return Icons.pause_circle;
    case MedicineStatus.completed:
      return Icons.task_alt;
    case MedicineStatus.archived:
      return Icons.archive;
  }
}