/// Shared presentational helpers for the Health feature.
///
/// Keeps the per-resource screens small: a generic [RecordListScreen] handles
/// load / empty / error / retry / create/edit/delete navigation for every
/// owned resource, and [FormScaffold] provides a consistent form layout with
/// date pickers, dropdowns and a single save action.
library;

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
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
// Generic record list screen
// ---------------------------------------------------------------------------

/// Generic CRUD list screen used by every owned Health resource.
///
/// [load] refetches the whole list, [delete] removes one record, [itemBuilder]
/// renders the tile content and [formBuilder] is pushed from the add / edit
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
  });

  final String title;
  final String emptyMessage;
  final Future<List<T>> Function() load;
  final Future<void> Function(T item) delete;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget Function(BuildContext context, T? edited) formBuilder;

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
      _load();
    }
  }

  Future<void> _confirmDelete(T item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete record'),
        content: const Text('This record will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.delete(item);
      if (!mounted) {
        return;
      }
      _load();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : () => _openForm(null),
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items == null) {
      return _LoadError(message: errorMessage(_error!), onRetry: _load);
    }
    final List<T> items = _items ?? const [];
    if (items.isEmpty) {
      return _EmptyRecords(message: widget.emptyMessage, onRefresh: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final T item = items[index];
          return ListTile(
            onTap: () => _openForm(item),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: widget.itemBuilder(context, item),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(item),
            ),
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 96),
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form helpers
// ---------------------------------------------------------------------------

/// Standard layout for health forms: an AppBar, scrollable form fields and a
/// primary save button pinned at the bottom.
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.saving = false,
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(label),
      subtitle: Text(value == null ? 'Not set' : formatDateTime(value)),
      trailing: const Icon(Icons.edit_outlined),
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cake_outlined),
      title: Text(label),
      subtitle: Text(value == null ? 'Not set' : formatDate(value)),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _pick(context),
    );
  }
}

/// Controlled dropdown wrapped in a material decoration. Uses a plain
/// [DropdownButton] so the selection can be reset programmatically (avoiding
/// the deprecated `value` parameter of `DropdownButtonFormField`).
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox.shrink(),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

/// Shared text field helpers.
TextFormField noteField({
  required TextEditingController controller,
  required String label,
  int maxLines = 3,
  int maxLength = 1000,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    maxLength: maxLength,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}