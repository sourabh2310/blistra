/// Medicine detail page with schedules, doses, refills, and quick dose recording.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../data/medicines_api_client.dart';
import '../models/dose_record.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/refill.dart';
import '../models/schedule.dart';
import '../models/today_doses.dart';
import '../state/medicine_detail_controller.dart';
import '../util/home_refresh.dart';
import 'dose_history_page.dart';
import 'medicine_form_page.dart';
import 'refill_form_page.dart';
import 'schedule_form_page.dart';

class MedicineDetailPage extends StatefulWidget {
  const MedicineDetailPage({super.key, required this.medicineId});

  final String medicineId;

  @override
  State<MedicineDetailPage> createState() => _MedicineDetailPageState();
}

class _MedicineDetailPageState extends State<MedicineDetailPage> {
  MedicineDetailController? _controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final authState = context.read<AuthState>();
      _controller = MedicineDetailController(
        MedicinesApiClient(
          tokenProvider: () => authState.apiClient.token ?? '',
          onUnauthorized: () => authState.handleUnauthorized(),
        ),
        medicineId: widget.medicineId,
      );
      _controller!.load();
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
        title: ListenableBuilder(
          listenable: controller,
          builder: (_, _) => Text(controller.medicine?.name ?? 'Medicine'),
        ),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (_, _) {
              if (controller.medicine == null) return const SizedBox();
              return PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _pushEdit();
                      break;
                    case 'archive':
                      _confirmArchive();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'archive',
                    enabled: controller.medicine?.status != MedicineStatus.archived,
                    child: const Text('Archive'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.error != null) {
            return _ErrorRetry(
              message: controller.error.toString(),
              onRetry: controller.load,
            );
          }
          final med = controller.medicine!;

          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MedicineHeader(medicine: med),
                const SizedBox(height: 24),
                _RecordDoseCard(
                  onRecord: (status) async {
                    await controller.recordDose(
                      status: status,
                      scheduledAt: DateTime.now(),
                    );
                    if (context.mounted) {
                      await refreshHomeDashboard(context);
                    }
                  },
                  isLoading: controller.isRecordingDose,
                  error: controller.doseError,
                ),
                const SizedBox(height: 24),
                if (controller.todaysDoses.isNotEmpty) ...[
                  Text("Today's doses",
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...controller.todaysDoses.map(
                    (d) => _TodayDoseTile(
                      dose: d,
                      isRecording: controller.isRecordingDose,
                      onTake: () => _takeSlot(d),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (controller.recentDoses.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Recent Doses',
                    actionLabel: 'View all',
                    onAction: () => _pushDoseHistory(),
                  ),
                  ...controller.recentDoses.take(5).map(
                        (d) => _DoseTile(
                          dose: d,
                          onEdit: () => _editDose(d),
                          onDelete: () => _deleteDose(d),
                        ),
                      ),
                  const SizedBox(height: 24),
                ],
                _SectionHeader(
                  title: 'Schedules',
                  actionLabel: 'Add',
                  onAction: () => _pushAddSchedule(),
                ),
                if (controller.schedules.isEmpty)
                  _EmptySectionMessage(
                    message: 'No schedules yet. Tap "Add" to create one.',
                  )
                else
                  ...controller.schedules.map(
                    (s) => _ScheduleTile(
                      schedule: s,
                      onEdit: () => _pushEditSchedule(s),
                      onDelete: () => _deleteSchedule(s),
                    ),
                  ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Refills',
                  actionLabel: 'Add',
                  onAction: () => _pushAddRefill(),
                ),
                if (controller.refills.isEmpty)
                  _EmptySectionMessage(
                    message: 'No refill records yet. Tap "Add" to create one.',
                  )
                else
                  ...controller.refills.map(
                    (r) => _RefillTile(
                      refill: r,
                      onEdit: () => _pushEditRefill(r),
                      onDelete: () => _deleteRefill(r),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pushEdit() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicineFormPage(medicine: _controller!.medicine!),
        ),
      ).then((_) async {
        await _controller!.load();
        if (mounted) {
          await refreshHomeDashboard(context);
        }
      });

  Future<void> _takeSlot(ExpectedDose dose) async {
    if (!dose.isPending || dose.scheduledAt.isAfter(DateTime.now())) {
      return;
    }
    await _controller!.recordDose(
      status: DoseStatus.taken,
      scheduledAt: dose.scheduledAt,
      scheduleId: dose.scheduleId,
    );
    if (mounted) {
      await refreshHomeDashboard(context);
    }
  }

  void _confirmArchive() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Archive medicine?'),
            content: Text('Archive "${_controller!.medicine!.name}"?'),
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
    if (ok && mounted) {
      await _controller!.archive();
      if (!mounted) return;
      await refreshHomeDashboard(context);
    }
  }

  void _pushDoseHistory() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoseHistoryPage(medicineId: widget.medicineId),
        ),
      );

  void _pushAddSchedule() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduleFormPage(medicineId: widget.medicineId),
        ),
      ).then((_) => _controller!.reloadSchedules());

  void _pushEditSchedule(Schedule s) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduleFormPage(medicineId: widget.medicineId, schedule: s),
        ),
      ).then((_) => _controller!.reloadSchedules());

  Future<void> _deleteSchedule(Schedule s) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete schedule?'),
            content: const Text('This will not affect existing dose records.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok && mounted) {
      await _controller!.deleteSchedule(s.id);
    }
  }

  void _pushAddRefill() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RefillFormPage(medicineId: widget.medicineId),
        ),
      ).then((_) => _controller!.reloadRefills());

  void _pushEditRefill(Refill r) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RefillFormPage(medicineId: widget.medicineId, refill: r),
        ),
      ).then((_) => _controller!.reloadRefills());

  Future<void> _deleteRefill(Refill r) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete refill record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok && mounted) {
      await _controller!.deleteRefill(r.id);
    }
  }

  Future<void> _editDose(DoseRecord dose) async {
    final status = await showDialog<DoseStatus>(
          context: context,
          builder: (_) => _DoseStatusDialog(initialStatus: dose.status),
        );
    if (status != null && mounted) {
      await _controller!.updateDose(dose.id, status);
      if (!mounted) return;
      await refreshHomeDashboard(context);
    }
  }

  Future<void> _deleteDose(DoseRecord dose) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete dose record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok && mounted) {
      await _controller!.deleteDose(dose.id);
      if (!mounted) return;
      await refreshHomeDashboard(context);
    }
  }
}

class _MedicineHeader extends StatelessWidget {
  const _MedicineHeader({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(medicine.status).withValues(alpha: 0.15),
                  child: Icon(
                    _statusIcon(medicine.status),
                    color: _statusColor(medicine.status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(medicine.name, style: Theme.of(context).textTheme.headlineSmall),
                      if (medicine.genericName != null && medicine.genericName!.isNotEmpty)
                        Text(medicine.genericName!,
                            style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                _StatusChip(status: medicine.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (medicine.form != null && medicine.form!.isNotEmpty)
                  _InfoChip(label: 'Form', value: medicine.form!),
                if (medicine.strength != null)
                  _InfoChip(label: 'Strength', value: medicine.strengthLabel),
                if (medicine.strengthUnit != null && medicine.strengthUnit!.isNotEmpty)
                  _InfoChip(label: 'Unit', value: medicine.strengthUnit!),
                if (medicine.startDate != null)
                  _InfoChip(label: 'Start', value: _fmtDate(medicine.startDate!)),
                if (medicine.endDate != null)
                  _InfoChip(label: 'End', value: _fmtDate(medicine.endDate!)),
              ],
            ),
            if (medicine.notes != null && medicine.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(medicine.notes!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// One expected dose for today with an explicit Take action for due slots.
class _TodayDoseTile extends StatelessWidget {
  const _TodayDoseTile({
    required this.dose,
    required this.isRecording,
    required this.onTake,
  });

  final ExpectedDose dose;
  final bool isRecording;
  final Future<void> Function() onTake;

  @override
  Widget build(BuildContext context) {
    final bool future = dose.scheduledAt.isAfter(DateTime.now());
    final String time =
        '${dose.scheduledAt.hour.toString().padLeft(2, '0')}:${dose.scheduledAt.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: dose.isPending
            ? const Icon(Icons.schedule_outlined, color: Colors.grey)
            : Icon(
                _doseStatusIcon(dose.status!),
                color: _doseStatusColor(dose.status!),
              ),
        title: Text(time),
        subtitle: Text(
          dose.isPending
              ? (future ? 'Upcoming' : 'Due')
              : _doseStatusLabel(dose.status!),
        ),
        trailing: dose.isPending && !future
            ? FilledButton(
                onPressed: isRecording ? null : onTake,
                child: const Text('Take'),
              )
            : null,
      ),
    );
  }
}

class _RecordDoseCard extends StatelessWidget {
  const _RecordDoseCard({
    required this.onRecord,
    required this.isLoading,
    this.error,
  });

  final Function(DoseStatus) onRecord;
  final bool isLoading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record Dose', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => onRecord(DoseStatus.taken),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('Taken'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => onRecord(DoseStatus.missed),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                    label: const Text('Missed'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => onRecord(DoseStatus.skipped),
                    icon: const Icon(Icons.help_outline, color: Colors.white),
                    label: const Text('Skipped'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({
    required this.dose,
    required this.onEdit,
    required this.onDelete,
  });

  final DoseRecord dose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _doseStatusIcon(dose.status),
          color: _doseStatusColor(dose.status),
        ),
        title: Text(_doseStatusLabel(dose.status)),
        subtitle: Text(_fmtDateTime(dose.scheduledAt)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit status')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  final Schedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_scheduleIcon(schedule.scheduleType)),
        ),
        title: Text(scheduleTypeLabel(schedule.scheduleType)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Times: ${schedule.times.join(", ")}'),
            if (schedule.daysOfWeek != null && schedule.daysOfWeek!.isNotEmpty)
              Text('Days: ${schedule.daysOfWeek!.map(_dayLabel).join(", ")}'),
            if (schedule.doseAmount != null)
              Text('Dose: ${schedule.doseLabel}'),
            Text('${scheduleRangeLabel(schedule)} · ${schedule.active ? "Active" : "Inactive"}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  String _dayLabel(int index) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return index >= 1 && index <= 7 ? days[index - 1] : '?';
  }
}

class _RefillTile extends StatelessWidget {
  const _RefillTile({
    required this.refill,
    required this.onEdit,
    required this.onDelete,
  });

  final Refill refill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.local_pharmacy)),
        title: Text(refillDateLabel(refill.refillDate)),
        subtitle: Text('Qty: ${refill.quantityLabel} · Remaining: ${refill.remainingLabel}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
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
            Text('Failed to load', style: Theme.of(context).textTheme.titleLarge),
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

class _DoseStatusDialog extends StatefulWidget {
  const _DoseStatusDialog({required this.initialStatus});

  final DoseStatus initialStatus;

  @override
  State<_DoseStatusDialog> createState() => _DoseStatusDialogState();
}

class _DoseStatusDialogState extends State<_DoseStatusDialog> {
  late DoseStatus _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change dose status'),
      content: RadioGroup<DoseStatus>(
        groupValue: _selected,
        onChanged: (v) {
          if (v != null) setState(() => _selected = v);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: DoseStatus.values
              .map(
                (s) => RadioListTile<DoseStatus>(
                  title: Text(s.name.toUpperCase()),
                  value: s,
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
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

Color _doseStatusColor(DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return Colors.green;
    case DoseStatus.missed:
      return Colors.red;
    case DoseStatus.skipped:
      return Colors.orange;
  }
}

IconData _doseStatusIcon(DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return Icons.check_circle;
    case DoseStatus.missed:
      return Icons.remove_circle_outline;
    case DoseStatus.skipped:
      return Icons.help_outline;
  }
}

String _doseStatusLabel(DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return 'Taken';
    case DoseStatus.missed:
      return 'Missed';
    case DoseStatus.skipped:
      return 'Skipped';
  }
}

IconData _scheduleIcon(ScheduleType type) {
  switch (type) {
    case ScheduleType.daily:
      return Icons.repeat;
    case ScheduleType.weekly:
      return Icons.calendar_view_week;
    case ScheduleType.customDays:
      return Icons.calendar_today;
    case ScheduleType.asNeeded:
      return Icons.aspect_ratio;
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}