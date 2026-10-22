/// Medicine detail page with schedules, doses, refills, and quick dose recording.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../data/medicines_api_client.dart';
import '../models/dose_record.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/refill.dart';
import '../models/schedule.dart';
import '../models/today_doses.dart';
import '../state/medicine_detail_controller.dart';
import '../util/home_refresh.dart';
import '../util/insights.dart';
import '../widgets/medicine_widgets.dart';
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

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final med = controller.medicine;
        final ready = !controller.isLoading && controller.error == null && med != null;
        return Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: ready
              ? StickyActionBar(label: 'Record a refill', onPressed: _pushAddRefill)
              : null,
          body: SafeArea(
            bottom: false,
            child: _body(controller),
          ),
        );
      },
    );
  }

  Widget _body(MedicineDetailController controller) {
    if (controller.isLoading) {
      return Column(
        children: [
          _DetailHeader(medicine: null, onEdit: null, onMenu: null),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (controller.error != null) {
      return ListView(
        children: [
          _DetailHeader(medicine: null, onEdit: null, onMenu: null),
          const SizedBox(height: 16),
          PagePad(UnavailableCard(name: 'This medicine', onRetry: controller.load)),
        ],
      );
    }
    final med = controller.medicine!;
    final colors = BlistraColors.resolve(context);

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _DetailHeader(
            medicine: med,
            subtitle: _subtitle(med, controller.schedules),
            onEdit: _pushEdit,
            onMenu: (value) {
              if (value == 'archive') _confirmArchive();
              if (value == 'history') _pushDoseHistory();
            },
          ),
          if (_stats(controller) case final stats when stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            StatStrip(stats: stats),
          ],
          if (controller.todaysDoses.isNotEmpty) ...[
            const MedSection(title: 'Today'),
            PagePad(
              GlassList(
                children: [
                  for (final d in controller.todaysDoses)
                    _TodayDoseRow(
                      dose: d,
                      isRecording: controller.isRecordingDose,
                      onTake: () => _takeSlot(d),
                    ),
                ],
              ),
            ),
          ],
          const MedSection(title: 'Log a dose now'),
          PagePad(
            _RecordDoseCard(
              onRecord: (status) async {
                await controller.recordDose(
                  status: status,
                  scheduledAt: DateTime.now(),
                );
                if (mounted) {
                  await refreshHomeDashboard(context);
                }
              },
              isLoading: controller.isRecordingDose,
              error: controller.doseError,
            ),
          ),
          MedSection(title: 'Schedule', actionLabel: 'Add ›', onAction: _pushAddSchedule),
          PagePad(
            controller.schedules.isEmpty
                ? EmptyCard(
                    message: 'No schedules yet.',
                    action: 'Add',
                    onAction: _pushAddSchedule,
                  )
                : GlassList(
                    children: [
                      for (final s in controller.schedules)
                        _ScheduleRow(
                          schedule: s,
                          onEdit: () => _pushEditSchedule(s),
                          onDelete: () => _deleteSchedule(s),
                        ),
                    ],
                  ),
          ),
          MedSection(
            title: 'Recent doses',
            actionLabel: 'History ›',
            onAction: _pushDoseHistory,
          ),
          PagePad(
            controller.recentDoses.isEmpty
                ? const EmptyCard(message: 'No doses recorded yet.')
                : GlassList(
                    children: [
                      for (final d in controller.recentDoses.take(5))
                        DoseRecordRow(
                          dose: d,
                          onEdit: () => _editDose(d),
                          onDelete: () => _deleteDose(d),
                        ),
                    ],
                  ),
          ),
          MedSection(title: 'Refills', actionLabel: 'Add ›', onAction: _pushAddRefill),
          PagePad(
            controller.refills.isEmpty
                ? const EmptyCard(message: 'No refill records yet.')
                : GlassList(
                    children: [
                      for (final r in controller.refills)
                        _RefillRow(
                          refill: r,
                          onEdit: () => _pushEditRefill(r),
                          onDelete: () => _deleteRefill(r),
                        ),
                    ],
                  ),
          ),
          if (_details(med) case final rows when rows.isNotEmpty) ...[
            const MedSection(title: 'Details'),
            PagePad(
              GlassList(
                children: [
                  for (final (label, value) in rows)
                    GlassRow(
                      title: value,
                      subtitle: label,
                      subtitleColor: colors.muted,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Tablet · twice daily · since 3 Jan".
  String _subtitle(Medicine med, List<Schedule> schedules) {
    final summary = scheduleSummary(schedules);
    return [
      if (med.genericName?.isNotEmpty ?? false) med.genericName!,
      if (med.form?.isNotEmpty ?? false) med.form!,
      if (summary.isNotEmpty) summary.toLowerCase(),
      if (med.startDate != null) 'since ${DateFormat('d MMM').format(med.startDate!)}',
    ].join(' · ');
  }

  List<StatData> _stats(MedicineDetailController controller) {
    final colors = BlistraColors.resolve(context);
    final doses = controller.recentDoses;
    final adherence = adherenceOf(doses);
    final latest = latestRefill(controller.refills);
    final streak = takenStreak(doses);
    return [
      if (adherence != null)
        StatData(
          label: 'Adherence',
          value: '${(adherence * 100).round()}',
          unit: '%',
          sub: 'Last ${doses.length} ${doses.length == 1 ? 'dose' : 'doses'}',
          progress: adherence,
          color: colors.data[0],
        ),
      if (latest?.remainingQuantity != null)
        StatData(
          label: 'Stock',
          value: latest!.remainingLabel,
          unit: 'left',
          sub: 'of ${latest.quantityLabel} · ${DateFormat('d MMM').format(latest.refillDate)}',
          badge: isLowStock(latest) ? 'LOW' : null,
          icon: Icons.inventory_2_outlined,
        ),
      if (doses.isNotEmpty)
        StatData(
          label: 'Streak',
          value: '$streak',
          unit: streak == 1 ? 'dose' : 'doses',
          sub: streak == 0 ? 'Last dose not taken' : 'Taken in a row',
          icon: Icons.local_fire_department_outlined,
        ),
    ];
  }

  List<(String, String)> _details(Medicine med) => [
        ('Status', medicineStatusLabel(med.status)),
        if (med.strength != null) ('Strength', med.strengthLabel),
        if (med.startDate != null) ('Start date', medicineStartDateLabel(med)),
        if (med.endDate != null)
          ('End date', DateFormat('dd MMM yyyy').format(med.endDate!)),
        if (med.notes?.isNotEmpty ?? false) ('Notes', med.notes!),
      ];

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
    final ok = await confirmAction(
      context,
      title: 'Archive medicine?',
      message: 'Archive "${_controller!.medicine!.name}"?',
      confirmLabel: 'Archive',
    );
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
    final ok = await confirmAction(
      context,
      title: 'Delete schedule?',
      message: 'This will not affect existing dose records.',
    );
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
    final ok = await confirmAction(
      context,
      title: 'Delete refill record?',
      message: 'Refill of ${r.quantityLabel} on ${refillDateLabel(r.refillDate)}.',
    );
    if (ok && mounted) {
      await _controller!.deleteRefill(r.id);
    }
  }

  Future<void> _editDose(DoseRecord dose) async {
    final status = await showDialog<DoseStatus>(
          context: context,
          builder: (_) => DoseStatusDialog(initialStatus: dose.status),
        );
    if (status != null && mounted) {
      await _controller!.updateDose(dose.id, status);
      if (!mounted) return;
      await refreshHomeDashboard(context);
    }
  }

  Future<void> _deleteDose(DoseRecord dose) async {
    final ok = await confirmAction(
      context,
      title: 'Delete dose record?',
      message: '${doseStatusLabel(dose.status)} · ${relativeDateTime(dose.scheduledAt)}',
    );
    if (ok && mounted) {
      await _controller!.deleteDose(dose.id);
      if (!mounted) return;
      await refreshHomeDashboard(context);
    }
  }
}

/// Back, edit and more; eyebrow, serif name with the strength in accent.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.medicine,
    required this.onEdit,
    required this.onMenu,
    this.subtitle = '',
  });

  final Medicine? medicine;
  final String subtitle;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final med = medicine;
    final archived = med?.status == MedicineStatus.archived;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 8, kPageGutter, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (onEdit != null) ...[
                GlassIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
              ],
              if (onMenu != null)
                GlassMenuButton<String>(
                  items: const [
                    ('history', 'Dose history'),
                    ('archive', 'Archive'),
                  ],
                  enabled: (v) => v != 'archive' || !archived,
                  onSelected: onMenu!,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('MEDICINE', style: BlistraText.eyebrow(colors.accentText)),
              if (med != null && med.status != MedicineStatus.active) ...[
                const SizedBox(width: 8),
                Pill(
                  medicineStatusLabel(med.status).toUpperCase(),
                  color: medicineStatusColor(context, med.status),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: med?.name ?? 'Medicine',
              children: [
                if (med != null && med.strengthLabel.isNotEmpty)
                  TextSpan(
                    text: ' ${med.strengthLabel}',
                    style: TextStyle(color: colors.accentText),
                  ),
              ],
            ),
            style: BlistraText.serif(30, colors.text, height: 1.1),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// One expected dose for today with an explicit Take action for due slots.
class _TodayDoseRow extends StatelessWidget {
  const _TodayDoseRow({
    required this.dose,
    required this.isRecording,
    required this.onTake,
  });

  final ExpectedDose dose;
  final bool isRecording;
  final Future<void> Function() onTake;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final bool future = dose.scheduledAt.isAfter(DateTime.now());
    final bool due = dose.isPending && !future;
    final String subtitle = dose.isPending
        ? (future ? 'Upcoming' : 'Due now')
        : doseStatusLabel(dose.status!);
    return GlassRow(
      leading: CheckCircle(checked: dose.isTaken, urgent: due),
      title: [
        DateFormat('h:mm a').format(dose.scheduledAt),
        if (dose.doseLabel.isNotEmpty) dose.doseLabel,
      ].join(' · '),
      subtitle: subtitle,
      subtitleColor: dose.isPending
          ? (due ? colors.danger : null)
          : doseStatusColor(context, dose.status!),
      trailing: due
          ? DoseActionButton(
              label: 'Take',
              filled: true,
              busy: isRecording,
              onTap: onTake,
            )
          : null,
    );
  }
}

/// Taken / Missed / Skipped buttons that record a dose at the current time.
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
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record a dose at ${DateFormat('h:mm a').format(DateTime.now())}',
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              DoseActionButton(
                label: 'Taken',
                filled: true,
                busy: isLoading,
                onTap: () => onRecord(DoseStatus.taken),
              ),
              const SizedBox(width: 8),
              DoseActionButton(
                label: 'Missed',
                busy: isLoading,
                onTap: () => onRecord(DoseStatus.missed),
              ),
              const SizedBox(width: 8),
              DoseActionButton(
                label: 'Skipped',
                busy: isLoading,
                onTap: () => onRecord(DoseStatus.skipped),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(color: colors.danger, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  final Schedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final s = schedule;
    final times = s.times.map(timeLabel).join(', ');
    final firstHour = int.tryParse(s.times.isEmpty ? '' : s.times.first.split(':').first);
    final icon = s.scheduleType == ScheduleType.asNeeded
        ? Icons.back_hand_outlined
        : switch (firstHour == null ? null : DayPart.of(firstHour)) {
            DayPart.morning => Icons.wb_twilight_rounded,
            DayPart.afternoon => Icons.wb_sunny_outlined,
            DayPart.evening => Icons.wb_cloudy_outlined,
            DayPart.night => Icons.nightlight_outlined,
            null => Icons.schedule_rounded,
          };
    final days = (s.daysOfWeek == null || s.daysOfWeek!.isEmpty)
        ? null
        : s.daysOfWeek!.map(dayShort).join(', ');
    return GlassRow(
      leading: IconWell(icon),
      title: [
        if (times.isNotEmpty) times else scheduleTypeLabel(s.scheduleType),
        if (s.doseLabel.isNotEmpty) s.doseLabel,
      ].join(' · '),
      subtitle: [
        if (days != null) days else scheduleTypeLabel(s.scheduleType),
        scheduleRangeLabel(s),
        if (!s.active) 'Inactive',
      ].join(' · '),
      subtitleColor: s.active ? null : colors.warning,
      onTap: onEdit,
      trailing: RowMenu(
        items: const [('edit', 'Edit'), ('delete', 'Delete')],
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      ),
    );
  }
}

class _RefillRow extends StatelessWidget {
  const _RefillRow({
    required this.refill,
    required this.onEdit,
    required this.onDelete,
  });

  final Refill refill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = refill;
    return GlassRow(
      leading: const IconWell(Icons.inventory_2_outlined),
      title: r.remainingQuantity == null
          ? 'Refill of ${r.quantityLabel}'
          : 'Refill of ${r.quantityLabel} · ${r.remainingLabel} left',
      subtitle: [
        refillDateLabel(r.refillDate),
        if (r.notes?.isNotEmpty ?? false) r.notes!,
      ].join(' · '),
      onTap: onEdit,
      trailing: RowMenu(
        items: const [('edit', 'Edit'), ('delete', 'Delete')],
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      ),
    );
  }
}
