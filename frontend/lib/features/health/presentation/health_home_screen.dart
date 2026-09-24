import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../health_models.dart';
import '../health_repository.dart';
import '../overview_stats.dart';
import 'measurement_form_screen.dart';
import 'widgets.dart';
import 'appointments_screen.dart';
import 'events_screen.dart';
import 'measurements_screen.dart';
import 'profile_screen.dart';
import 'sleep_screen.dart';
import 'activity_screen.dart';
import 'logs_screen.dart';

/// Home screen for the authenticated Health feature.
///
/// Today's overview, latest values, recent records and per-type history are
/// derived exclusively from the user's own backend records (never hardcoded).
/// Only the measurement types the backend supports are shown; trend lines are
/// plain arithmetic with no medical interpretation. Logging out clears the
/// session so the parent widget returns to the login screen.
class HealthHomeScreen extends StatefulWidget {
  const HealthHomeScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final HealthRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<HealthHomeScreen> createState() => _HealthHomeScreenState();
}

class _ResourceEntry {
  const _ResourceEntry(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _HealthHomeScreenState extends State<HealthHomeScreen> {
  static const List<_ResourceEntry> _resources = [
    _ResourceEntry(Icons.person_outline, 'Profile'),
    _ResourceEntry(Icons.monitor_weight_outlined, 'Measurements'),
    _ResourceEntry(Icons.bedtime_outlined, 'Sleep'),
    _ResourceEntry(Icons.directions_run, 'Activity'),
    _ResourceEntry(Icons.assignment_outlined, 'Health logs'),
    _ResourceEntry(Icons.event_note_outlined, 'Events'),
    _ResourceEntry(Icons.calendar_month_outlined, 'Appointments'),
  ];

  bool _measurementsLoading = false;
  Object? _measurementsError;
  MeasurementType _historyType = MeasurementType.weight;

  HealthRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
    _loadMeasurements();
  }

  Future<void> _refreshAll() async {
    await _refreshProfile();
    await _loadMeasurements();
  }

  Future<void> _refreshProfile() async {
    try {
      await _repository.loadProfile();
    } catch (_) {
      // A profile GET that fails (e.g. transient network) should not block the
      // home screen; the summary simply stays hidden and retry happens on the
      // next refresh.
    }
  }

  Future<void> _loadMeasurements() async {
    setState(() {
      _measurementsLoading = true;
      _measurementsError = null;
    });
    try {
      await _repository.loadMeasurements(size: 100);
      if (!mounted) {
        return;
      }
      setState(() => _measurementsLoading = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _measurementsError = error;
        _measurementsLoading = false;
      });
    }
  }

  /// Refreshes the Home dashboard health summary after a successful Health
  /// mutation. Failures here never block the Health flow itself.
  Future<void> _refreshDashboard() async {
    try {
      await AppScope.of(context).dashboard.refresh(
            date: DateTime.now(),
            offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          );
    } catch (_) {
      // No scope (e.g. tests) or transient network: Health stays correct.
    }
  }

  Future<void> _openMeasurementForm({
    HealthMeasurement? initial,
    MeasurementType? initialType,
  }) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MeasurementFormScreen(
          repository: _repository,
          initial: initial,
          initialType: initialType,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadMeasurements();
      await _refreshDashboard();
    }
  }

  Future<void> _confirmDeleteMeasurement(HealthMeasurement m) async {
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
      await _repository.deleteMeasurement(m.id);
      if (!mounted) {
        return;
      }
      await _loadMeasurements();
      await _refreshDashboard();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _openResource(int index) async {
    switch (index) {
      case 0:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(repository: _repository),
          ),
        );
        return;
      case 1:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MeasurementsScreen(
              repository: _repository,
              onChanged: _refreshDashboard,
            ),
          ),
        );
        await _loadMeasurements();
        return;
      case 2:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SleepScreen(repository: _repository),
          ),
        );
        return;
      case 3:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(repository: _repository),
          ),
        );
        return;
      case 4:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LogsScreen(repository: _repository),
          ),
        );
        return;
      case 5:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventsScreen(repository: _repository),
          ),
        );
        return;
      case 6:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AppointmentsScreen(
              repository: _repository,
              onChanged: _refreshDashboard,
            ),
          ),
        );
        return;
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Sign out of this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final HealthRepository repository = _repository;
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Health'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: _confirmLogout,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _measurementsLoading
                ? null
                : () => _openMeasurementForm(),
            tooltip: 'Add measurement',
            icon: const Icon(Icons.add),
            label: const Text('Add measurement'),
          ),
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (repository.profile != null)
                  _ProfileCard(profile: repository.profile!),
                if (repository.profile != null)
                  const SizedBox(height: 8),
                _measurementsSection(repository),
                const SizedBox(height: 8),
                ..._buildResourceRows(context, repository),
                // Space for the extended FAB.
                const SizedBox(height: 72),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _measurementsSection(HealthRepository repository) {
    if (_measurementsLoading && repository.measurements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_measurementsError != null && repository.measurements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 8),
              Text(
                errorMessage(_measurementsError!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _loadMeasurements,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final List<HealthMeasurement> all = repository.measurements;
    final DateTime now = DateTime.now();
    final Map<MeasurementType, HealthMeasurement> latest =
        latestPerType(all);
    final Map<MeasurementType, HealthMeasurement> todayLatest =
        latestPerType(todayOnly(all, now));
    final List<HealthMeasurement> recent = mostRecent(all);
    final List<HealthMeasurement> history =
        historyFor(all, _historyType);
    final String? trend = history.length >= 2
        ? deltaText(history[0], history[1])
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TodayOverviewCard(
          todayLatest: todayLatest,
          onAdd: (type) => _openMeasurementForm(initialType: type),
          onAddAny: () => _openMeasurementForm(),
        ),
        const SizedBox(height: 8),
        _LatestCard(
          latest: latest,
          onAdd: () => _openMeasurementForm(),
          onOpen: (type) => setState(() => _historyType = type),
        ),
        const SizedBox(height: 8),
        _RecentCard(
          recent: recent,
          onAdd: () => _openMeasurementForm(),
          onEdit: (m) => _openMeasurementForm(initial: m),
          onDelete: _confirmDeleteMeasurement,
          onViewAll: () => _openResource(1),
        ),
        const SizedBox(height: 8),
        _HistoryCard(
          selected: _historyType,
          history: history,
          trend: trend,
          onSelect: (type) => setState(() => _historyType = type),
          onAdd: () =>
              _openMeasurementForm(initialType: _historyType),
          onEdit: (m) => _openMeasurementForm(initial: m),
          onDelete: _confirmDeleteMeasurement,
          onViewAll: () => _openResource(1),
        ),
      ],
    );
  }

  List<Widget> _buildResourceRows(BuildContext context, HealthRepository repository) {
    final List<Widget> rows = [];
    for (int i = 0; i < _resources.length; i++) {
      final _ResourceEntry entry = _resources[i];
      rows.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(entry.icon, color: Theme.of(context).colorScheme.primary),
            title: Text(entry.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openResource(i),
          ),
        ),
      );
    }
    return rows;
  }
}

// ---------------------------------------------------------------------------
// Today's overview
// ---------------------------------------------------------------------------

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.todayLatest,
    required this.onAdd,
    required this.onAddAny,
  });

  final Map<MeasurementType, HealthMeasurement> todayLatest;
  final ValueChanged<MeasurementType> onAdd;
  final VoidCallback onAddAny;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Today's overview",
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddAny,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final MeasurementType type in overviewTypes)
              _TodayRow(
                type: type,
                measurement: todayLatest[type],
                onAdd: () => onAdd(type),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.type,
    required this.measurement,
    required this.onAdd,
  });

  final MeasurementType type;
  final HealthMeasurement? measurement;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final String label = measurementTypeLabels[type] ?? type.name;
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(measurementTypeIcons[type] ??
                Icons.monitor_heart_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    measurement == null
                        ? 'No ${label.toLowerCase()} recorded today'
                        : formatValue(measurement!),
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: measurement == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .outline
                                  : null,
                            ),
                  ),
                ],
              ),
            ),
            if (measurement == null)
              TextButton(
                onPressed: onAdd,
                child: const Text('Add'),
              )
            else
              Text(
                formatDateTime(measurement!.measuredAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Latest
// ---------------------------------------------------------------------------

class _LatestCard extends StatelessWidget {
  const _LatestCard({
    required this.latest,
    required this.onAdd,
    required this.onOpen,
  });

  final Map<MeasurementType, HealthMeasurement> latest;
  final VoidCallback onAdd;
  final ValueChanged<MeasurementType> onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (latest.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latest', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('No measurements yet.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add measurement'),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final MeasurementType type in overviewTypes)
              if (latest[type] != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(measurementTypeIcons[type]),
                  title: Text(measurementTypeLabels[type] ?? type.name),
                  subtitle: Text(formatDate(latest[type]!.measuredAt)),
                  trailing: Text(
                    formatValue(latest[type]!),
                    style: theme.textTheme.titleSmall,
                  ),
                  onTap: () => onOpen(type),
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent measurements
// ---------------------------------------------------------------------------

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.recent,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onViewAll,
  });

  final List<HealthMeasurement> recent;
  final VoidCallback onAdd;
  final ValueChanged<HealthMeasurement> onEdit;
  final ValueChanged<HealthMeasurement> onDelete;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Recent measurements',
                      style: theme.textTheme.titleMedium),
                ),
                if (recent.isNotEmpty)
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View all'),
                  ),
              ],
            ),
            if (recent.isEmpty) ...[
              const SizedBox(height: 4),
              const Text('No measurements yet.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add measurement'),
              ),
            ] else
              for (final HealthMeasurement m in recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(measurementTypeIcons[m.type]),
                  title: Text(
                      '${measurementTypeLabels[m.type] ?? m.type.name} · ${formatValue(m)}'),
                  subtitle: Text(formatDateTime(m.measuredAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => onDelete(m),
                  ),
                  onTap: () => onEdit(m),
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History & trends (plain arithmetic, no medical interpretation)
// ---------------------------------------------------------------------------

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.selected,
    required this.history,
    required this.trend,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onViewAll,
  });

  final MeasurementType selected;
  final List<HealthMeasurement> history;
  final String? trend;
  final ValueChanged<MeasurementType> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<HealthMeasurement> onEdit;
  final ValueChanged<HealthMeasurement> onDelete;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History & trends', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final MeasurementType type in overviewTypes)
                  ChoiceChip(
                    label: Text(measurementTypeLabels[type] ?? type.name),
                    selected: selected == type,
                    onSelected: (_) => onSelect(type),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (trend != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${measurementTypeLabels[selected] ?? selected.name}: ${formatValue(history.first)}\n$trend',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (history.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                  'No ${(measurementTypeLabels[selected] ?? selected.name).toLowerCase()} records yet.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add measurement'),
              ),
            ] else ...[
              for (final HealthMeasurement m in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(formatDate(m.measuredAt)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatValue(m),
                          style: theme.textTheme.titleSmall),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => onDelete(m),
                      ),
                    ],
                  ),
                  onTap: () => onEdit(m),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onViewAll,
                  child: const Text('View all'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _summary(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(ThemeData theme) {
    final List<String> parts = [];
    final double? height = profile.heightCm;
    final String birthDate = formatDate(profile.dateOfBirth);
    if (height != null) {
      parts.add('${formatDouble(height)} cm');
    }
    if (birthDate.isNotEmpty) {
      parts.add('Born $birthDate');
    }
    if (parts.isEmpty) {
      return Text(
        'Tap Profile to set your details.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
