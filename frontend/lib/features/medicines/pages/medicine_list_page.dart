/// Medicines list page with status filter, pagination, and archive.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';

import '../../../core/auth/auth_state.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/today_doses.dart';
import '../state/medicine_list_controller.dart';
import '../state/medicine_today_controller.dart';
import '../util/home_refresh.dart';
import 'medicine_form_page.dart';
import 'medicine_detail_page.dart';

class MedicineListPage extends StatefulWidget {
  const MedicineListPage({super.key});

  @override
  State<MedicineListPage> createState() => _MedicineListPageState();
}

class _MedicineListPageState extends State<MedicineListPage> {
  MedicineListController? _controller;
  MedicineTodayController? _today;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final authState = context.read<AuthState>();
      final api = MedicinesApiClient(
        tokenProvider: () => authState.apiClient.token ?? '',
        onUnauthorized: () => authState.handleUnauthorized(),
      );
      _controller = MedicineListController(api);
      _today = MedicineTodayController(api);
      _controller!.refresh();
      _today!.refresh();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _today?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final today = _today;
    if (controller == null || today == null) {
      // Initialized in didChangeDependencies; show a controlled loading
      // state instead of crashing on a null controller.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // No account actions here: sign-out lives in Profile.
      appBar: AppBar(
        title: const Text('Medicines'),
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
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _TodaySection(today: today),
                _StatusFilterChips(controller: controller),
                if (controller.medicines.isEmpty)
                  _EmptyState(onAdd: _pushAdd)
                else
                  ...controller.medicines.map(
                    (medicine) => _MedicineTile(
                      medicine: medicine,
                      onTap: () => _pushDetail(context, medicine.id),
                      onArchive: _archive,
                    ),
                  ),
                if (controller.hasMore)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _LoadMore(
                        onVisible: controller.loadMore,
                      ),
                    ),
                  ),
                // Space for the FAB.
                const SizedBox(height: 80),
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

  Future<void> _refreshAll() async {
    final controller = _controller;
    final today = _today;
    if (controller == null || today == null) return;
    await Future.wait([
      controller.refresh(),
      today.refresh(),
    ]);
  }

  Future<void> _archive(String id) async {
    final controller = _controller;
    final today = _today;
    if (controller == null || today == null) return;
    await controller.archive(id);
    if (!mounted) return;
    await today.refresh();
    if (!mounted) return;
    await refreshHomeDashboard(context);
  }

  void _pushAdd() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedicineFormPage()),
      ).then((_) => _afterMutation());

  void _pushDetail(BuildContext context, String id) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MedicineDetailPage(medicineId: id)),
      ).then((_) => _afterMutation());

  Future<void> _afterMutation() async {
    if (!mounted) return;
    await _refreshAll();
    if (!mounted) return;
    await refreshHomeDashboard(context);
  }
}

class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.onVisible});

  final Future<void> Function() onVisible;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator();
  }
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

/// Today's expected doses for all active medicines, expanded server-side.
///
/// Shows the completed/total summary, the next scheduled dose, and one row
/// per occurrence with an explicit Take action for due slots. Viewing never
/// records; only tapping Take does, through the backend.
class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.today});

  final MedicineTodayController today;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: today,
      builder: (context, _) {
        final MedicineToday? data = today.today;
        if (today.isLoading && data == null) {
          return const Card(
            margin: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (today.error != null && data == null) {
          return Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Could not load today\'s doses.'),
                  const SizedBox(height: 8),
                  Text(today.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: today.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final MedicineToday current = data ?? MedicineToday.empty(DateTime.now());
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (current.isEmpty)
                  const Text('No medicines scheduled today')
                else ...[
                  _SummaryLine(today: current),
                  const SizedBox(height: 4),
                  if (current.allCompleted)
                    const _AllDoneBanner()
                  else
                    for (final dose in current.doses)
                      _DoseRow(
                        dose: dose,
                        today: today,
                      ),
                  const SizedBox(height: 8),
                  _NextDoseLine(today: current),
                ],
                if (today.recordError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    today.recordError.toString(),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.today});

  final MedicineToday today;

  @override
  Widget build(BuildContext context) {
    final double progress =
        today.totalDoses == 0 ? 0 : today.takenDoses / today.totalDoses;
    return Row(
      children: [
        Expanded(
          child: Text(
            '${today.takenDoses} / ${today.totalDoses} doses completed',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(value: progress),
        ),
      ],
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'All doses completed ✓',
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({required this.dose, required this.today});

  final ExpectedDose dose;
  final MedicineTodayController today;

  @override
  Widget build(BuildContext context) {
    final bool future = dose.scheduledAt.isAfter(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              DateFormat('HH:mm').format(dose.scheduledAt),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dose.medicineName,
                    style: Theme.of(context).textTheme.bodyMedium),
                if (dose.doseLabel.isNotEmpty)
                  Text(dose.doseLabel,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          _DoseStatusChip(dose: dose, future: future),
          if (dose.isPending && !future) ...[
            const SizedBox(width: 8),
            _TakeButton(dose: dose, today: today),
          ],
        ],
      ),
    );
  }
}

class _DoseStatusChip extends StatelessWidget {
  const _DoseStatusChip({required this.dose, required this.future});

  final ExpectedDose dose;
  final bool future;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (dose.status) {
      DoseStatus.taken => ('✓ Taken', Colors.green),
      DoseStatus.missed => ('Missed', Colors.red),
      DoseStatus.skipped => ('Skipped', Colors.orange),
      null => future ? ('Upcoming', Colors.grey) : ('Due', Colors.orange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _TakeButton extends StatelessWidget {
  const _TakeButton({required this.dose, required this.today});

  final ExpectedDose dose;
  final MedicineTodayController today;

  @override
  Widget build(BuildContext context) {
    final bool recording = today.isRecording(dose);
    return FilledButton(
      onPressed: recording
          ? null
          : () async {
              final bool ok = await today.takeDose(dose);
              if (!context.mounted) return;
              if (ok) {
                await refreshHomeDashboard(context);
              } else if (today.recordError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(today.recordError.toString())),
                );
              }
            },
      child: recording
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Take'),
    );
  }
}

class _NextDoseLine extends StatelessWidget {
  const _NextDoseLine({required this.today});

  final MedicineToday today;

  @override
  Widget build(BuildContext context) {
    final ExpectedDose? next = today.nextDose;
    if (next == null) {
      return Text('No upcoming doses',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline));
    }
    final String when = DateFormat('h:mm a').format(next.scheduledAt);
    final String amount =
        next.doseLabel.isEmpty ? '' : '\n${next.doseLabel}';
    return Text('Next\n${next.medicineName}$amount\n$when',
        style: Theme.of(context).textTheme.bodyMedium);
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