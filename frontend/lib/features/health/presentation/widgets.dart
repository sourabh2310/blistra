/// Shared presentational helpers for the Health feature.
///
/// Keeps the per-resource screens small: a generic [RecordListScreen] handles
/// load / empty / error / retry / create/edit/delete navigation for every
/// owned resource, and [FormScaffold] provides a consistent form layout with
/// date pickers, dropdowns and a single save action. Both follow the glass
/// templates in design/app-pages.html.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';
import '../health_models.dart';

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

String _two(int value) => value.toString().padLeft(2, '0');

/// Local, human readable `yyyy-MM-dd HH:mm`.
String formatDateTime(DateTime? value) {
  final DateTime? local = value?.toLocal();
  if (local == null) {
    return '';
  }
  return '${_two(local.year)}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Local, human readable `yyyy-MM-dd`.
String formatDate(DateTime? value) {
  final DateTime? local = value?.toLocal();
  if (local == null) {
    return '';
  }
  return '${_two(local.year)}-${_two(local.month)}-${_two(local.day)}';
}

/// Trims trailing zeros from a decimal so `70.0` renders as `70`.
String formatDouble(double? value) {
  if (value == null) {
    return '';
  }
  return value == value.roundToDouble() ? '${value.round()}' : '$value';
}

/// Renders a duration in minutes as `"45 min"` or an empty label when null.
String formatMinutes(int? minutes) {
  if (minutes == null) {
    return '';
  }
  return '$minutes min';
}

// ---------------------------------------------------------------------------
// Enum labels (UI only, never sent to the backend)
// ---------------------------------------------------------------------------

const Map<MeasurementType, String> measurementTypeLabels = {
  MeasurementType.weight: 'Weight',
  MeasurementType.height: 'Height',
  MeasurementType.heartRate: 'Heart rate',
  MeasurementType.temperature: 'Temperature',
  MeasurementType.bloodPressure: 'Blood pressure',
};

const Map<MeasurementType, IconData> measurementTypeIcons = {
  MeasurementType.weight: Icons.monitor_weight_outlined,
  MeasurementType.height: Icons.height,
  MeasurementType.heartRate: Icons.favorite_outline,
  MeasurementType.temperature: Icons.thermostat_outlined,
  MeasurementType.bloodPressure: Icons.monitor_heart_outlined,
};

/// Units the backend validates per measurement type.
List<String> unitsFor(MeasurementType type) => switch (type) {
      MeasurementType.weight => const ['KG', 'LB'],
      MeasurementType.height => const ['CM', 'IN'],
      MeasurementType.heartRate => const ['BPM'],
      MeasurementType.temperature => const ['C', 'F'],
      MeasurementType.bloodPressure => const ['MMHG'],
    };

String defaultUnitFor(MeasurementType type) => switch (type) {
      MeasurementType.weight => 'KG',
      MeasurementType.height => 'CM',
      MeasurementType.heartRate => 'BPM',
      MeasurementType.temperature => 'C',
      MeasurementType.bloodPressure => 'MMHG',
    };

const Map<BloodType, String> bloodTypeLabels = {
  BloodType.aPositive: 'A positive',
  BloodType.aNegative: 'A negative',
  BloodType.bPositive: 'B positive',
  BloodType.bNegative: 'B negative',
  BloodType.abPositive: 'AB positive',
  BloodType.abNegative: 'AB negative',
  BloodType.oPositive: 'O positive',
  BloodType.oNegative: 'O negative',
  BloodType.unknown: 'Unknown',
};

const Map<Severity, String> severityLabels = {
  Severity.mild: 'Mild',
  Severity.moderate: 'Moderate',
  Severity.severe: 'Severe',
};

const Map<ActivityType, String> activityTypeLabels = {
  ActivityType.walking: 'Walking',
  ActivityType.running: 'Running',
  ActivityType.cycling: 'Cycling',
  ActivityType.swimming: 'Swimming',
  ActivityType.strengthTraining: 'Strength training',
  ActivityType.yoga: 'Yoga',
  ActivityType.sports: 'Sports',
  ActivityType.other: 'Other',
};

const Map<EventType, String> eventTypeLabels = {
  EventType.checkup: 'Check-up',
  EventType.vaccination: 'Vaccination',
  EventType.medicalVisit: 'Medical visit',
  EventType.labTest: 'Lab test',
  EventType.other: 'Other',
};

const Map<AppointmentStatus, String> appointmentStatusLabels = {
  AppointmentStatus.scheduled: 'Scheduled',
  AppointmentStatus.confirmed: 'Confirmed',
  AppointmentStatus.completed: 'Completed',
  AppointmentStatus.cancelled: 'Cancelled',
  AppointmentStatus.missed: 'Missed',
};

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Human readable description of any error (prefers the backend's message for
/// `ApiException`, which is already safe to show to the user).
String errorMessage(Object error) {
  if (error is ApiException) {
    final String message = error.message.trim();
    if (message.isNotEmpty) {
      return message;
    }
  }
  return error.toString();
}

/// Shows a backend/network error as a SnackBar.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorMessage(error))));
}

// ---------------------------------------------------------------------------
// Friendly display helpers (UI only)
// ---------------------------------------------------------------------------

/// `Fri, 24 Oct · 5:00 PM` in local time.
String friendlyDateTime(DateTime value) =>
    DateFormat('EEE, d MMM · h:mm a').format(value.toLocal());

/// `Fri, 24 Oct 1990` in local time.
String friendlyDate(DateTime value) =>
    DateFormat('EEE, d MMM y').format(value.toLocal());

/// `Today`, `Yesterday`, `Tue` within the last week, otherwise `12 Oct`.
String relativeDay(DateTime value, DateTime now) {
  final DateTime local = value.toLocal();
  final int days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  if (days == 0) {
    return 'Today';
  }
  if (days == 1) {
    return 'Yesterday';
  }
  if (days > 1 && days < 7) {
    return DateFormat('EEE').format(local);
  }
  return DateFormat(local.year == now.year ? 'd MMM' : 'd MMM y').format(local);
}

/// Readable unit for a backend unit code (`MMHG` → `mmHg`).
String displayUnit(String unit) => switch (unit.toUpperCase()) {
      'KG' => 'kg',
      'LB' => 'lb',
      'CM' => 'cm',
      'IN' => 'in',
      'BPM' => 'bpm',
      'C' => '°C',
      'F' => '°F',
      'MMHG' => 'mmHg',
      _ => unit,
    };

/// `72.4` or `118/76`, without the unit.
String measurementNumber(HealthMeasurement m) =>
    m.type == MeasurementType.bloodPressure && m.valueDiastolic != null
        ? '${formatDouble(m.value)}/${formatDouble(m.valueDiastolic)}'
        : formatDouble(m.value);

/// Compact change from [previous] to [latest]: `▼ 0.7`, `▲ 2/▼ 1` or
/// `No change`; with [signs], `-0.7` and `+2/-1` instead of arrows (for
/// serif numbers, which have no arrow glyphs). Null without a previous
/// reading. Plain arithmetic only.
String? shortChange(
  HealthMeasurement latest,
  HealthMeasurement? previous, {
  bool signs = false,
}) {
  if (previous == null) {
    return null;
  }
  String part(double diff) {
    final double rounded = (diff * 10).round() / 10;
    if (rounded == 0) {
      return '0';
    }
    if (signs) {
      return '${rounded > 0 ? '+' : '-'}${formatDouble(rounded.abs())}';
    }
    return '${rounded > 0 ? '▲' : '▼'} ${formatDouble(rounded.abs())}';
  }

  if (latest.type == MeasurementType.bloodPressure &&
      latest.valueDiastolic != null &&
      previous.valueDiastolic != null) {
    final String sys = part(latest.value - previous.value);
    final String dia = part(latest.valueDiastolic! - previous.valueDiastolic!);
    return sys == '0' && dia == '0' ? 'No change' : '$sys/$dia';
  }
  final String diff = part(latest.value - previous.value);
  return diff == '0' ? 'No change' : diff;
}

/// Row colour for each measurement type, from the theme's colours.
Color measurementColor(BlistraColors colors, MeasurementType type) =>
    switch (type) {
      MeasurementType.weight => colors.accentText,
      MeasurementType.bloodPressure => colors.danger,
      MeasurementType.heartRate => colors.data[2],
      MeasurementType.temperature => colors.warning,
      MeasurementType.height => colors.data[0],
    };

/// Duration in minutes as `7h 12m`, `45m` or `2h`.
String durationText(int minutes) {
  final int hours = minutes ~/ 60;
  final int remainder = minutes % 60;
  if (hours == 0) {
    return '${remainder}m';
  }
  if (remainder == 0) {
    return '${hours}h';
  }
  return '${hours}h ${remainder}m';
}

/// Recorded duration, or the span between start and end when absent.
int sleepMinutes(HealthSleepRecord record) {
  if (record.durationMinutes != null) {
    return record.durationMinutes!;
  }
  final int minutes = record.endedAt.difference(record.startedAt).inMinutes;
  return minutes < 0 ? 0 : minutes;
}

// ---------------------------------------------------------------------------
// Generic record list screen
// ---------------------------------------------------------------------------

/// What one record shows as a [GlassRow].
class HealthRow {
  const HealthRow({
    required this.title,
    required this.icon,
    this.subtitle,
    this.color,
    this.meta,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Tints the icon well; neutral when null.
  final Color? color;

  /// Short trailing text, e.g. the value or time.
  final String? meta;
}

/// Generic CRUD list screen used by every owned Health resource.
///
/// [load] refetches the whole list, [delete] removes one record, [itemBuilder]
/// describes each row and [formBuilder] is pushed from the add / edit
/// actions; it should pop with `true` when the list must refresh.
class RecordListScreen<T> extends StatefulWidget {
  const RecordListScreen({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.load,
    required this.delete,
    required this.itemBuilder,
    required this.formBuilder,
    this.onChanged,
    this.noun = 'record',
  });

  final String title;
  final String emptyMessage;
  final Future<List<T>> Function() load;
  final Future<void> Function(T item) delete;
  final HealthRow Function(BuildContext context, T item) itemBuilder;
  final Widget Function(BuildContext context, T? edited) formBuilder;

  /// Invoked after a successful create/edit/delete so owners (e.g. the Health
  /// overview) can refresh dependent state such as the Home dashboard.
  final Future<void> Function()? onChanged;

  /// Singular name for the count line ("3 records").
  final String noun;

  @override
  State<RecordListScreen<T>> createState() => _RecordListScreenState<T>();
}

class _RecordListScreenState<T> extends State<RecordListScreen<T>> {
  List<T>? _items;
  Object? _error;
  bool _loading = false;

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
      final List<T> items = await widget.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openForm(T? edited) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => widget.formBuilder(context, edited),
      ),
    );
    if (changed == true && mounted) {
      await _load();
      await widget.onChanged?.call();
    }
  }

  Future<void> _confirmDelete(T item) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Delete record',
      message: 'This record will be permanently removed.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.delete(item);
      if (!mounted) {
        return;
      }
      await _load();
      await widget.onChanged?.call();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<T>? items = _items;
    final String? count = items == null
        ? null
        : items.isEmpty
            ? 'Nothing recorded yet'
            : '${items.length} ${widget.noun}${items.length == 1 ? '' : 's'}';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              BlistraPageHeader(
                eyebrow: 'Health',
                title: widget.title,
                subtitle: count,
                showAvatar: false,
                actions: [
                  GlassIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Add',
                    onTap: _loading ? null : () => _openForm(null),
                  ),
                ],
              ),
              PagePad(_buildBody(), top: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items == null) {
      return const SkeletonLoader(rows: 4);
    }
    if (_error != null && _items == null) {
      return _LoadError(
        name: widget.title,
        message: errorMessage(_error!),
        onRetry: _load,
      );
    }
    final List<T> items = _items ?? const [];
    if (items.isEmpty) {
      return EmptyCard(
        message: widget.emptyMessage,
        action: 'Add',
        onAction: () => _openForm(null),
      );
    }
    final BlistraColors colors = BlistraColors.resolve(context);
    return GlassList(
      children: [
        for (final T item in items)
          Builder(
            builder: (context) {
              final HealthRow row = widget.itemBuilder(context, item);
              return GlassRow(
                onTap: () => _openForm(item),
                leading: IconWell(row.icon, color: row.color),
                title: row.title,
                subtitle: row.subtitle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (row.meta != null) RowMeta(row.meta!),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: colors.muted,
                      ),
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDelete(item),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.name,
    required this.message,
    required this.onRetry,
  });

  final String name;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final BlistraColors colors = BlistraColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UnavailableCard(name: name, onRetry: onRetry),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            message,
            style: TextStyle(fontSize: 11, color: colors.muted),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Form helpers
// ---------------------------------------------------------------------------

/// Standard layout for health forms (the Form page template): back button,
/// small eyebrow, a question-style serif heading, glass fields and Save
/// pinned to the bottom.
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.heading,
    this.saving = false,
  });

  /// Short page name shown as the eyebrow ("Add measurement").
  final String title;

  /// Question-style heading ("What did you measure?"); defaults to [title].
  final String? heading;

  /// The form body; usually a [ListView] padded with [formPadding].
  final Widget child;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BlistraPageHeader(
              eyebrow: title,
              title: heading ?? title,
              showAvatar: false,
            ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        label: 'Save',
        busy: saving,
        onPressed: onSave,
      ),
    );
  }
}

/// Padding for the scrolling body inside a [FormScaffold].
const EdgeInsets formPadding =
    EdgeInsets.fromLTRB(kPageGutter, 14, kPageGutter, 24);

/// Small uppercase label above a [GlassSegmented] in forms.
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final BlistraColors colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 0, 8),
      child: Text(text.toUpperCase(), style: BlistraText.caption(colors.muted)),
    );
  }
}

/// [GlassSegmented] with a [FormLabel] and the standard field spacing.
class FormSegmented<T> extends StatelessWidget {
  const FormSegmented({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormLabel(label),
          GlassSegmented<T>(
            options: options,
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Glass text field that also supports input formatters and a length limit
/// ([GlassTextField] has neither).
class HealthField extends StatelessWidget {
  const HealthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final BlistraColors colors = BlistraColors.resolve(context);
    return FieldCard(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: 1,
        validator: validator,
        style: TextStyle(fontSize: 14, color: colors.text),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14, color: colors.muted),
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorStyle: TextStyle(fontSize: 11, color: colors.danger),
        ),
      ),
    );
  }
}

/// Tappable glass field showing a value and a trailing icon.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BlistraColors colors = BlistraColors.resolve(context);
    return Semantics(
      button: true,
      label: label,
      child: FieldCard(
        label: label,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(child: Text(value)),
            Icon(icon, size: 18, color: colors.accentText),
          ],
        ),
      ),
    );
  }
}

/// Picks a date and a time and reports the combined value.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime initial = value ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      value: value == null ? 'Not set' : friendlyDateTime(value!),
      icon: Icons.event_outlined,
      onTap: () => _pick(context),
    );
  }
}

/// Picks a date only (used for `dateOfBirth`).
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (date != null) {
      onChanged(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PickerField(
      label: label,
      value: value == null ? 'Not set' : friendlyDate(value!),
      icon: Icons.cake_outlined,
      onTap: () => _pick(context),
    );
  }
}

/// Glass field holding a plain [DropdownButton], so the selection can be
/// reset programmatically (avoiding the deprecated `value` parameter of
/// `DropdownButtonFormField`). Prefer [FormSegmented] for 2–4 short options.
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final BlistraColors colors = BlistraColors.resolve(context);
    return FieldCard(
      label: label,
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: colors.sheet,
        borderRadius: BorderRadius.circular(16),
        icon: Icon(Icons.expand_more_rounded, size: 20, color: colors.accentText),
        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: colors.text),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

/// Shared multi-line notes field.
Widget noteField({
  required TextEditingController controller,
  required String label,
  int maxLines = 3,
  int maxLength = 1000,
}) {
  return HealthField(
    controller: controller,
    label: label,
    maxLines: maxLines,
    maxLength: maxLength,
    keyboardType: TextInputType.multiline,
  );
}
