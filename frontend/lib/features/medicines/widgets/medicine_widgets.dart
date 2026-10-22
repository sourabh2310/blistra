/// Small Medicines-only pieces not covered by the shared Blistra components.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../models/dose_record.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../util/insights.dart';

/// Compact Take / Skip button for a dose row: filled accent or ghost glass.
class DoseActionButton extends StatelessWidget {
  const DoseActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: filled ? colors.accentText : colors.inkAt(0.1),
              borderRadius: BorderRadius.circular(99),
              border: filled ? null : Border.all(color: colors.inkAt(0.14)),
            ),
            child: busy && filled
                ? SizedBox(
                    width: 22,
                    height: 14,
                    child: Center(
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: colors.onAccent,
                        ),
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: filled ? colors.onAccent : colors.text,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// ⋯ glass button that opens a menu of [items] (value, label).
class GlassMenuButton<T> extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.tooltip = 'More',
    this.icon = Icons.more_horiz_rounded,
    this.enabled,
  });

  final List<(T, String)> items;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final IconData icon;

  /// Optional per-item enabled check.
  final bool Function(T value)? enabled;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        for (final (value, label) in items)
          PopupMenuItem<T>(
            value: value,
            enabled: enabled?.call(value) ?? true,
            child: Text(label),
          ),
      ],
      child: GlassIconButton(icon: icon, tooltip: null, onTap: null),
    );
  }
}

/// Trailing ⋯ on a row that opens a small menu (Edit / Delete).
class RowMenu extends StatelessWidget {
  const RowMenu({super.key, required this.items, required this.onSelected});

  final List<(String, String)> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return PopupMenuButton<String>(
      tooltip: 'Options',
      onSelected: onSelected,
      icon: Icon(Icons.more_vert_rounded, size: 18, color: colors.muted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 120),
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(32, 32)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      itemBuilder: (_) => [
        for (final (value, label) in items)
          PopupMenuItem(value: value, child: Text(label)),
      ],
    );
  }
}

/// Glass card holding a spinner while a section loads.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: height,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.accentText,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section heading with no bottom/top gaps of its own beyond the standard
/// [SectionHeader]; adds the 24 px gap the design puts above each section.
class MedSection extends StatelessWidget {
  const MedSection({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: SectionHeader(
          title: title,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      );
}

/// Theme colour for a dose status: accent for taken, red for missed, amber
/// for skipped.
Color doseStatusColor(BuildContext context, DoseStatus status) {
  final colors = BlistraColors.resolve(context);
  return switch (status) {
    DoseStatus.taken => colors.accentText,
    DoseStatus.missed => colors.danger,
    DoseStatus.skipped => colors.warning,
  };
}

/// Theme colour for a medicine status pill.
Color medicineStatusColor(BuildContext context, MedicineStatus status) {
  final colors = BlistraColors.resolve(context);
  return switch (status) {
    MedicineStatus.active => colors.accentText,
    MedicineStatus.paused => colors.warning,
    MedicineStatus.completed => colors.data[0],
    MedicineStatus.archived => colors.muted,
  };
}

/// A stable theme data colour per medicine name.
Color medicineTint(BuildContext context, String name) {
  final data = BlistraColors.resolve(context).data;
  final sum = name.codeUnits.fold<int>(0, (s, u) => s + u);
  return data[sum % data.length];
}

/// Icon hinting at the medicine's form.
IconData medicineIcon(Medicine m) {
  final value = '${m.form ?? ''} ${m.name}'.toLowerCase();
  if (value.contains('syrup') || value.contains('liquid')) {
    return Icons.local_drink_outlined;
  }
  if (value.contains('cream') || value.contains('ointment')) {
    return Icons.spa_outlined;
  }
  if (value.contains('vitamin')) return Icons.wb_sunny_outlined;
  return Icons.medication_outlined;
}

/// "Metformin 500 mg".
String medicineTitle(Medicine m) =>
    m.strengthLabel.isEmpty ? m.name : '${m.name} ${m.strengthLabel}';

/// Dialog to change a recorded dose's status.
class DoseStatusDialog extends StatefulWidget {
  const DoseStatusDialog({super.key, required this.initialStatus});

  final DoseStatus initialStatus;

  @override
  State<DoseStatusDialog> createState() => _DoseStatusDialogState();
}

class _DoseStatusDialogState extends State<DoseStatusDialog> {
  late DoseStatus _selected = widget.initialStatus;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change dose status'),
      content: GlassSegmented<DoseStatus>(
        options: const [
          (DoseStatus.taken, 'Taken'),
          (DoseStatus.missed, 'Missed'),
          (DoseStatus.skipped, 'Skipped'),
        ],
        selected: _selected,
        onChanged: (v) => setState(() => _selected = v),
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

/// Glass field that opens a date picker; shows "Not set" when empty.
class DateFieldCard extends StatelessWidget {
  const DateFieldCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.lastDate,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? error;
  final DateTime? lastDate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldCard(
          label: label,
          onTap: () async {
            final last = lastDate ?? DateTime(2100);
            final initial = value ?? DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initial.isAfter(last) ? last : initial,
              firstDate: DateTime(2000),
              lastDate: last,
            );
            if (picked != null) onChanged(picked);
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? 'Not set' : _fmt(value!),
                  style: TextStyle(color: value == null ? colors.muted : colors.text),
                ),
              ),
              Icon(Icons.calendar_today_outlined, size: 15, color: colors.muted),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(error!, style: TextStyle(fontSize: 11.5, color: colors.danger)),
          ),
      ],
    );
  }

  static String _fmt(DateTime d) => DateFormat('d MMM yyyy').format(d);
}

/// Small uppercase label above a non-text form control.
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Text(text.toUpperCase(), style: BlistraText.caption(colors.muted)),
    );
  }
}

/// A recorded dose: status circle, when, status, and an Edit / Delete menu.
class DoseRecordRow extends StatelessWidget {
  const DoseRecordRow({
    super.key,
    required this.dose,
    required this.onEdit,
    required this.onDelete,
    this.timeOnly = false,
  });

  final DoseRecord dose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Shows just the time (for lists already grouped by day).
  final bool timeOnly;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final statusColor = doseStatusColor(context, dose.status);
    final taken = dose.status == DoseStatus.taken;
    final noted = dose.note?.isNotEmpty ?? false;
    return GlassRow(
      leading: taken
          ? const CheckCircle(checked: true)
          : Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 1.8),
              ),
              child: Icon(
                dose.status == DoseStatus.missed
                    ? Icons.priority_high_rounded
                    : Icons.remove_rounded,
                size: 13,
                color: statusColor,
              ),
            ),
      title: timeOnly
          ? DateFormat('h:mm a').format(dose.scheduledAt)
          : relativeDateTime(dose.scheduledAt),
      subtitle: [
        doseStatusLabel(dose.status),
        if (taken && dose.takenAt != null)
          'at ${DateFormat('h:mm a').format(dose.takenAt!)}',
        if (noted) dose.note!,
      ].join(' · '),
      subtitleColor: taken ? colors.muted : statusColor,
      onTap: onEdit,
      trailing: RowMenu(
        items: const [('edit', 'Edit status'), ('delete', 'Delete')],
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
      ),
    );
  }
}
