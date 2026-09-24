import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../health_models.dart';
import '../health_repository.dart';
import '../overview_stats.dart';
import 'activity_screen.dart';
import 'appointments_screen.dart';
import 'events_screen.dart';
import 'logs_screen.dart';
import 'measurement_form_screen.dart';
import 'measurements_screen.dart';
import 'profile_screen.dart';
import 'sleep_screen.dart';
import 'widgets.dart';

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

  static const List<String> _tabs = [
    'Overview',
    'Measurements',
    'Trends',
    'Goals',
    'Insights',
  ];

  static const Color _green = Color(0xFF07594F);
  static const Color _ink = Color(0xFF151A38);
  static const Color _muted = Color(0xFF65758E);
  static const Color _mint = Color(0xFFE4F5EE);
  static const Color _blush = Color(0xFFFFE7EC);
  static const Color _blue = Color(0xFFE5F3FD);
  static const Color _lavender = Color(0xFFF0E9FF);
  static const Color _orange = Color(0xFFFFE9D8);
  static const Color _page = Color(0xFFFFFBF6);

  bool _loading = false;
  Object? _measurementsError;
  int _selectedTab = 0;
  int _trendDays = 30;
  MeasurementType _historyType = MeasurementType.weight;

  HealthRepository get _repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _measurementsError = null;
      });
    }
    try {
      await _repository.loadMeasurements(size: 100);
    } catch (error) {
      if (mounted) {
        setState(() => _measurementsError = error);
      }
    }
    try {
      await Future.wait<dynamic>([
        _repository.loadProfile(),
        _repository.loadSleepRecords(),
        _repository.loadActivities(),
        _repository.loadLogs(),
        _repository.loadEvents(),
        _repository.loadAppointments(),
      ]);
    } catch (_) {
      if (!mounted) {
        return;
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshDashboard() async {
    try {
      await AppScope.of(context).dashboard.refresh(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (_) {
      return;
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

  Future<void> _loadMeasurements() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _measurementsError = null;
      });
    }
    try {
      await _repository.loadMeasurements(size: 100);
    } catch (error) {
      if (mounted) {
        setState(() => _measurementsError = error);
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmDeleteMeasurement(HealthMeasurement measurement) async {
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
      await _repository.deleteMeasurement(measurement.id);
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
        break;
      case 1:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MeasurementsScreen(
              repository: _repository,
              onChanged: _refreshDashboard,
            ),
          ),
        );
        break;
      case 2:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SleepScreen(repository: _repository),
          ),
        );
        break;
      case 3:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(repository: _repository),
          ),
        );
        break;
      case 4:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LogsScreen(repository: _repository),
          ),
        );
        break;
      case 5:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventsScreen(repository: _repository),
          ),
        );
        break;
      case 6:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AppointmentsScreen(
              repository: _repository,
              onChanged: _refreshDashboard,
            ),
          ),
        );
        break;
    }
    if (mounted) {
      await _refreshAll();
    }
  }

  Future<void> _showResourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health resources',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (int index = 0; index < _resources.length; index++)
                ListTile(
                  leading: Icon(_resources[index].icon, color: _green),
                  title: Text(_resources[index].label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openResource(index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repository,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _page,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _BrandHeader(
                  onSearch: _showResourcePicker,
                  onLogs: () => _openResource(4),
                  onAppointments: () => _openResource(6),
                  onProfile: () => _openResource(0),
                ),
                const _HealthHero(),
                _HealthTabs(
                  tabs: _tabs,
                  selected: _selectedTab,
                  onSelected: _selectTab,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    child: _buildSelectedPage(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedPage() {
    if (_loading && _repository.measurements.isEmpty) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(color: _green),
      );
    }
    if (_measurementsError != null && _repository.measurements.isEmpty) {
      return _MeasurementError(
        key: const ValueKey('error'),
        message: errorMessage(_measurementsError!),
        onRetry: _loadMeasurements,
      );
    }
    return switch (_selectedTab) {
      0 => _overviewPage(),
      1 => _measurementsPage(),
      2 => _trendsPage(),
      3 => _goalsPage(),
      _ => _insightsPage(),
    };
  }

  Widget _pageShell({required Key key, required List<Widget> children}) {
    return RefreshIndicator(
      key: key,
      color: _green,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
        children: children,
      ),
    );
  }

  Widget _overviewPage() {
    final HealthRepository repository = _repository;
    final List<HealthMeasurement> all = repository.measurements;
    final Map<MeasurementType, HealthMeasurement> latest = latestPerType(all);
    final List<HealthMeasurement> recent = mostRecent(all, count: 4);
    return _pageShell(
      key: const ValueKey('overview'),
      children: [
        _MetricGrid(
          latest: latest,
          history: historyFor(all, MeasurementType.weight, limit: 1000),
          activity: _latestActivity(repository.activities),
          onMeasurement: (type) {
            setState(() {
              _historyType = type;
              _selectedTab = 2;
            });
          },
          onActivity: () => _selectTab(4),
        ),
        const SizedBox(height: 14),
        _WeightTrendCard(
          history: _trendingHistory(
            historyFor(all, MeasurementType.weight, limit: 1000),
          ),
          selectedType: MeasurementType.weight,
          trendDays: _trendDays,
          onType: (type) {
            setState(() {
              _historyType = type;
              _selectedTab = 2;
            });
          },
          onRange: (days) => setState(() => _trendDays = days),
          onAdd: () => _openMeasurementForm(initialType: _historyType),
        ),
        const SizedBox(height: 14),
        _TodayProgressCard(
          measurements: todayOnly(all, DateTime.now()),
          activities: _todayActivities(repository.activities),
          sleep: _todaySleep(repository.sleepRecords),
        ),
        const SizedBox(height: 14),
        _QuickLogCard(onOpenResource: _showResourcePicker),
        const SizedBox(height: 14),
        _RecentMeasurementsCard(
          measurements: recent,
          onEdit: (measurement) => _openMeasurementForm(initial: measurement),
          onDelete: _confirmDeleteMeasurement,
          onSeeAll: () => _openResource(1),
        ),
      ],
    );
  }

  Widget _measurementsPage() {
    final List<HealthMeasurement> measurements = mostRecent(
      _repository.measurements,
    );
    return _pageShell(
      key: const ValueKey('measurements'),
      children: [
        _QuickLogCard(onOpenResource: _showResourcePicker),
        const SizedBox(height: 14),
        _RecentMeasurementsCard(
          measurements: measurements,
          onEdit: (measurement) => _openMeasurementForm(initial: measurement),
          onDelete: _confirmDeleteMeasurement,
          onSeeAll: () => _openResource(1),
        ),
      ],
    );
  }

  Widget _trendsPage() {
    final List<HealthMeasurement> all = _repository.measurements;
    final List<HealthMeasurement> history = historyFor(
      all,
      _historyType,
      limit: 1000,
    );
    final List<HealthMeasurement> trendHistory =
        _trendingHistory(history);
    return _pageShell(
      key: const ValueKey('trends'),
      children: [
        _WeightTrendCard(
          history: trendHistory,
          selectedType: _historyType,
          trendDays: _trendDays,
          onType: (type) => setState(() => _historyType = type),
          onRange: (days) => setState(() => _trendDays = days),
          onAdd: () => _openMeasurementForm(initialType: _historyType),
        ),
        const SizedBox(height: 14),
        _TrendSummaryCard(
          all: all,
          selected: _historyType,
          onSelect: (type) {
            setState(() {
              _historyType = type;
              if (type == MeasurementType.weight && _trendDays > 365) {
                _trendDays = 365;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _goalsPage() {
    final HealthRepository repository = _repository;
    final Map<MeasurementType, HealthMeasurement> latest = latestPerType(
      repository.measurements,
    );
    final List<HealthActivity> activities = _todayActivities(
      repository.activities,
    );
    final List<HealthSleepRecord> sleep = _todaySleep(repository.sleepRecords);
    return _pageShell(
      key: const ValueKey('goals'),
      children: [
        const _Panel(child: _UnavailableGoalState()),
        const SizedBox(height: 14),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.flag_outlined,
                title: 'Current baseline',
              ),
              const SizedBox(height: 14),
              _SummaryLine(
                label: 'Weight',
                value: latest[MeasurementType.weight] == null
                    ? 'Not recorded'
                    : formatValue(latest[MeasurementType.weight]!),
              ),
              _SummaryLine(
                label: 'Blood pressure',
                value: latest[MeasurementType.bloodPressure] == null
                    ? 'Not recorded'
                    : formatValue(latest[MeasurementType.bloodPressure]!),
              ),
              _SummaryLine(
                label: 'Today’s activity',
                value: _activityDurationLabel(activities),
              ),
              _SummaryLine(
                label: 'Today’s sleep',
                value: _sleepDurationLabel(sleep),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openResource(1),
                      child: const Text('Measurements'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openResource(3),
                      child: const Text('Activity'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _insightsPage() {
    final HealthRepository repository = _repository;
    final List<HealthMeasurement> measurements = repository.measurements;
    final List<HealthMeasurement> weightHistory = historyFor(
      measurements,
      MeasurementType.weight,
      limit: 1000,
    );
    final List<HealthMeasurement> newestFirst = mostRecent(
      measurements,
      count: 100000,
    );
    final DateTime now = DateTime.now();
    final List<HealthAppointment> upcoming =
        repository.appointments
            .where((appointment) => appointment.scheduledAt.isAfter(now))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final int trackedTypes = latestPerType(measurements).length;
    final String? weightChange = weightHistory.length >= 2
        ? deltaText(weightHistory.first, weightHistory[1])
        : null;
    return _pageShell(
      key: const ValueKey('insights'),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.auto_awesome_outlined,
                title: 'Your health snapshot',
              ),
              const SizedBox(height: 14),
              _SummaryLine(
                label: 'Measurement records',
                value: '${measurements.length}',
              ),
              _SummaryLine(
                label: 'Measurement types tracked',
                value: '$trackedTypes of ${overviewTypes.length}',
              ),
              _SummaryLine(
                label: 'Latest measurement',
                value: newestFirst.isEmpty
                    ? 'Not available'
                    : formatDateTime(newestFirst.first.measuredAt),
              ),
              _SummaryLine(
                label: 'Latest weight change',
                value: weightChange ?? 'Not enough history',
              ),
              const SizedBox(height: 8),
              Text(
                'Summaries use recorded values only and do not provide medical interpretation.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: _muted, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (upcoming.isNotEmpty) ...[
          _Panel(
            child: _SummaryLine(
              label: 'Next appointment',
              value:
                  '${upcoming.first.title.isEmpty ? 'Appointment' : upcoming.first.title} · '
                  '${formatDateTime(upcoming.first.scheduledAt)}',
            ),
          ),
          const SizedBox(height: 14),
        ],
        const _SectionTitle(
          icon: Icons.folder_open_outlined,
          title: 'Health records',
        ),
        const SizedBox(height: 10),
        _ResourceGrid(repository: repository, onOpen: _openResource),
      ],
    );
  }

  List<HealthMeasurement> _trendingHistory(List<HealthMeasurement> history) {
    final DateTime cutoff = DateTime.now().subtract(Duration(days: _trendDays));
    final List<HealthMeasurement> visible =
        history
            .where((measurement) => !measurement.measuredAt.isBefore(cutoff))
            .toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return visible;
  }

  HealthActivity? _latestActivity(List<HealthActivity> values) {
    if (values.isEmpty) {
      return null;
    }
    final List<HealthActivity> sorted = List.of(values)
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return sorted.first;
  }

  List<HealthActivity> _todayActivities(List<HealthActivity> values) {
    final DateTime now = DateTime.now();
    return values
        .where((value) => isSameLocalDay(value.performedAt, now))
        .toList()
      ..sort((a, b) => b.performedAt.compareTo(a.performedAt));
  }

  List<HealthSleepRecord> _todaySleep(List<HealthSleepRecord> values) {
    final DateTime now = DateTime.now();
    return values
        .where(
          (value) =>
              isSameLocalDay(value.startedAt, now) ||
              isSameLocalDay(value.endedAt, now),
        )
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.onSearch,
    required this.onLogs,
    required this.onAppointments,
    required this.onProfile,
  });

  final VoidCallback onSearch;
  final VoidCallback onLogs;
  final VoidCallback onAppointments;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Blistra',
                      style: TextStyle(
                        color: _HealthHomeScreenState._green,
                        fontFamily: 'serif',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const Icon(Icons.eco, color: Color(0xFF4E9B69), size: 29),
                  ],
                ),
                const Text(
                  'EVERYTHING YOU NEED. ONE APP.',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: Color(0xFF5D6D88),
                    fontSize: 8.5,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          _ActionCircle(
            icon: Icons.search,
            tooltip: 'Health resources',
            onTap: onSearch,
          ),
          const SizedBox(width: 7),
          _ActionCircle(
            icon: Icons.notifications_none,
            tooltip: 'Health logs',
            onTap: onLogs,
          ),
          const SizedBox(width: 7),
          _ActionCircle(
            icon: Icons.calendar_today_outlined,
            tooltip: 'Appointments',
            onTap: onAppointments,
          ),
          const SizedBox(width: 7),
          _ActionCircle(
            icon: Icons.person_outline,
            tooltip: 'Health profile',
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF1F1F5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 21, color: _HealthHomeScreenState._ink),
          ),
        ),
      ),
    );
  }
}

class _HealthHero extends StatelessWidget {
  const _HealthHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _HealthLandscapePainter()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 150, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Health',
                  style: TextStyle(
                    color: _HealthHomeScreenState._ink,
                    fontFamily: 'serif',
                    fontSize: 48,
                    height: 0.98,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Track your health. Build a healthier you.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF405B7B),
                    fontFamily: 'serif',
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthTabs extends StatelessWidget {
  const _HealthTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _HealthHomeScreenState._ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (int index = 0; index < tabs.length; index++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == index
                        ? const Color(0xFFDDEBE4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          color: _HealthHomeScreenState._ink,
                          fontFamily: 'serif',
                          fontSize: 14,
                          fontWeight: selected == index
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.latest,
    required this.history,
    required this.activity,
    required this.onMeasurement,
    required this.onActivity,
  });

  final Map<MeasurementType, HealthMeasurement> latest;
  final List<HealthMeasurement> history;
  final HealthActivity? activity;
  final ValueChanged<MeasurementType> onMeasurement;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    final HealthMeasurement? weight = latest[MeasurementType.weight];
    final HealthMeasurement? previousWeight = history.length > 1
        ? history[1]
        : null;
    final HealthMeasurement? pressure = latest[MeasurementType.bloodPressure];
    final HealthMeasurement? heart = latest[MeasurementType.heartRate];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.08,
      children: [
        _MetricCard(
          color: _HealthHomeScreenState._mint,
          icon: Icons.monitor_weight_outlined,
          title: 'Weight',
          value: weight == null ? '—' : formatDouble(weight.value),
          unit: weight?.unit ?? '',
          status: weight == null
              ? 'Not recorded'
              : deltaText(weight, previousWeight) ?? 'No prior reading',
          statusColor: weight == null
              ? _HealthHomeScreenState._muted
              : _HealthHomeScreenState._green,
          onTap: () => onMeasurement(MeasurementType.weight),
        ),
        _MetricCard(
          color: _HealthHomeScreenState._blush,
          icon: Icons.favorite,
          title: 'Blood pressure',
          value: pressure == null
              ? '—'
              : pressure.valueDiastolic == null
              ? formatDouble(pressure.value)
              : '${formatDouble(pressure.value)} / ${formatDouble(pressure.valueDiastolic)}',
          unit: pressure?.unit ?? '',
          status: pressure == null
              ? 'Not recorded'
              : 'Updated ${formatDate(pressure.measuredAt)}',
          statusColor: pressure == null ? _HealthHomeScreenState._muted : null,
          onTap: () => onMeasurement(MeasurementType.bloodPressure),
        ),
        _MetricCard(
          color: _HealthHomeScreenState._blue,
          icon: Icons.water_drop_outlined,
          title: 'Heart rate',
          value: heart == null ? '—' : formatDouble(heart.value),
          unit: heart?.unit ?? '',
          status: heart == null
              ? 'Not recorded'
              : 'Updated ${formatDate(heart.measuredAt)}',
          statusColor: heart == null ? _HealthHomeScreenState._muted : null,
          onTap: () => onMeasurement(MeasurementType.heartRate),
        ),
        _MetricCard(
          color: _HealthHomeScreenState._lavender,
          icon: Icons.directions_run,
          title: 'Activity',
          value: activity?.durationMinutes == null
              ? '—'
              : _durationText(activity!.durationMinutes!),
          unit: '',
          status: activity == null
              ? 'Not recorded'
              : '${activity!.performedAt.toLocal().month}/${activity!.performedAt.toLocal().day} · latest activity',
          statusColor: activity == null ? _HealthHomeScreenState._muted : null,
          onTap: onActivity,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final String status;
  final Color? statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: _HealthHomeScreenState._ink,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: _HealthHomeScreenState._ink,
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: value),
                      if (unit.isNotEmpty)
                        TextSpan(
                          text: ' $unit',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _HealthHomeScreenState._muted,
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: _HealthHomeScreenState._ink,
                    fontFamily: 'serif',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: _HealthHomeScreenState._muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor ?? _HealthHomeScreenState._ink,
                  fontSize: 10.5,
                  fontWeight: statusColor == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _HealthHomeScreenState._ink.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _HealthHomeScreenState._green, size: 25),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _HealthHomeScreenState._ink,
              fontFamily: 'serif',
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _WeightTrendCard extends StatelessWidget {
  const _WeightTrendCard({
    required this.history,
    required this.selectedType,
    required this.trendDays,
    required this.onType,
    required this.onRange,
    required this.onAdd,
  });

  final List<HealthMeasurement> history;
  final MeasurementType selectedType;
  final int trendDays;
  final ValueChanged<MeasurementType> onType;
  final ValueChanged<int> onRange;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final HealthMeasurement? latest = history.isEmpty ? null : history.last;
    final String? change = history.length >= 2
        ? deltaText(history.last, history[history.length - 2])
        : null;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: Icons.show_chart,
                  title:
                      '${measurementTypeLabels[selectedType] ?? selectedType.name} trend',
                ),
              ),
              for (final MapEntry<int, String> range in const [
                MapEntry(7, '7D'),
                MapEntry(30, '1M'),
                MapEntry(90, '3M'),
                MapEntry(365, '1Y'),
              ])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GestureDetector(
                    onTap: () => onRange(range.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: trendDays == range.key
                            ? const Color(0xFFDDEBE4)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        range.value,
                        style: const TextStyle(
                          color: _HealthHomeScreenState._muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 35,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final MeasurementType type in overviewTypes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(measurementTypeLabels[type] ?? type.name),
                      selected: selectedType == type,
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 10),
                      onSelected: (_) => onType(type),
                    ),
                  ),
              ],
            ),
          ),
          if (latest == null)
            Container(
              height: 180,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timeline_outlined,
                    color: _HealthHomeScreenState._muted.withValues(
                      alpha: 0.55,
                    ),
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No ${(measurementTypeLabels[selectedType] ?? selectedType.name).toLowerCase()} data in this period',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _HealthHomeScreenState._muted,
                    ),
                  ),
                  TextButton(
                    onPressed: onAdd,
                    child: const Text('Add a real record'),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 190,
              width: double.infinity,
              child: CustomPaint(
                painter: _MeasurementChartPainter(history: history),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    change ?? 'Only one record in this period',
                    style: const TextStyle(
                      color: _HealthHomeScreenState._muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  formatValue(latest),
                  style: const TextStyle(
                    color: _HealthHomeScreenState._ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MeasurementChartPainter extends CustomPainter {
  const _MeasurementChartPainter({required this.history});

  final List<HealthMeasurement> history;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty || size.width < 80 || size.height < 80) {
      return;
    }
    const double left = 39;
    const double right = 10;
    const double top = 12;
    const double bottom = 30;
    final double width = size.width - left - right;
    final double height = size.height - top - bottom;
    final List<double> values = history.map((item) => item.value).toList();
    double minimum = values.reduce((a, b) => a < b ? a : b);
    double maximum = values.reduce((a, b) => a > b ? a : b);
    double spread = maximum - minimum;
    if (spread < 1) {
      spread = 1;
      minimum -= 0.5;
      maximum += 0.5;
    } else {
      final double padding = spread * 0.16;
      minimum -= padding;
      maximum += padding;
    }
    final Paint grid = Paint()
      ..color = const Color(0xFFDEE5E6)
      ..strokeWidth = 1;
    for (int index = 0; index < 4; index++) {
      final double y = top + height * index / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final double value = maximum - (maximum - minimum) * index / 3;
      _paintText(
        canvas,
        formatDouble(value),
        Offset(0, y - 6),
        const TextStyle(color: Color(0xFF7A88A0), fontSize: 9),
      );
    }
    for (int index = 0; index < 4; index++) {
      final double x = left + width * index / 3;
      canvas.drawLine(Offset(x, top), Offset(x, top + height), grid);
    }
    final List<Offset> points = [
      for (int index = 0; index < values.length; index++)
        Offset(
          history.length == 1
              ? left + width / 2
              : left + width * index / (values.length - 1),
          top + height * (maximum - values[index]) / (maximum - minimum),
        ),
    ];
    final Path fill = Path()..moveTo(points.first.dx, top + height);
    for (final Offset point in points) {
      fill.lineTo(point.dx, point.dy);
    }
    fill
      ..lineTo(points.last.dx, top + height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4DBB8A), Color(0x1A4DBB8A)],
        ).createShader(Rect.fromLTWH(0, top, size.width, height)),
    );
    final Path line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFF2B9D6D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final Offset point in points) {
      canvas.drawCircle(point, 4.2, Paint()..color = const Color(0xFF087A57));
      canvas.drawCircle(point, 1.6, Paint()..color = Colors.white);
    }
    final Set<int> indexes = {0, history.length ~/ 2, history.length - 1};
    for (final int index in indexes) {
      final String label = _shortDate(history[index].measuredAt);
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFF65758E), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      double dx = points[index].dx - painter.width / 2;
      dx = dx.clamp(0, size.width - painter.width).toDouble();
      painter.paint(canvas, Offset(dx, size.height - painter.height));
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _shortDate(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  bool shouldRepaint(covariant _MeasurementChartPainter oldDelegate) => true;
}

class _TodayProgressCard extends StatelessWidget {
  const _TodayProgressCard({
    required this.measurements,
    required this.activities,
    required this.sleep,
  });

  final List<HealthMeasurement> measurements;
  final List<HealthActivity> activities;
  final List<HealthSleepRecord> sleep;

  @override
  Widget build(BuildContext context) {
    final Set<MeasurementType> types = measurements
        .map((item) => item.type)
        .toSet();
    final int recordedTypes = types.length;
    final int durationMinutes = activities.fold(
      0,
      (total, item) => total + (item.durationMinutes ?? 0),
    );
    final int sleepMinutes = sleep.fold(
      0,
      (total, item) => total + _sleepMinutes(item),
    );
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.bar_chart_rounded,
            title: 'Today’s progress',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _ProgressItem(
                  progress: overviewTypes.isEmpty
                      ? 0.0
                      : recordedTypes / overviewTypes.length,
                  icon: Icons.check,
                  value: '$recordedTypes / ${overviewTypes.length}',
                  label: 'Types logged',
                ),
              ),
              Expanded(
                flex: 6,
                child: _ProgressItem(
                  progress: durationMinutes > 0 ? 1.0 : 0.0,
                  color: const Color(0xFF35B779),
                  icon: Icons.directions_run,
                  value: activities.isEmpty ? '—' : '$durationMinutes min',
                  label: '${activities.length} activities',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ProgressItem(
                  progress: sleepMinutes > 0 ? 1.0 : 0.0,
                  color: const Color(0xFF7B63D9),
                  icon: Icons.bedtime,
                  value: sleepMinutes == 0 ? '—' : _durationText(sleepMinutes),
                  label: '${sleep.length} sleep logs',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ProgressItem(
                  progress: measurements.isEmpty ? 0.0 : 1.0,
                  color: const Color(0xFF1F9BCE),
                  icon: Icons.favorite_outline,
                  value: '${measurements.length}',
                  label: 'Readings today',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.progress,
    required this.icon,
    required this.value,
    required this.label,
    this.color = _HealthHomeScreenState._green,
  });

  final double progress;
  final Color color;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: progress.clamp(0, 1).toDouble(),
              color: color,
            ),
            child: Icon(icon, color: color, size: 27),
          ),
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: _HealthHomeScreenState._ink,
              fontFamily: 'serif',
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _HealthHomeScreenState._muted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Paint background = Paint()
      ..color = const Color(0xFFECEDEE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final Paint foreground = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(bounds.deflate(5), 0, 6.28318, false, background);
    if (progress > 0) {
      canvas.drawArc(
        bounds.deflate(5),
        -1.5708,
        6.28318 * progress,
        false,
        foreground,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _QuickLogCard extends StatelessWidget {
  const _QuickLogCard({required this.onOpenResource});

  final VoidCallback onOpenResource;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.bar_chart_rounded,
                  title: 'Log a new measurement',
                ),
              ),
              TextButton(
                onPressed: onOpenResource,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See all'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 17),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (int index = 0; index < overviewTypes.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _QuickTypeButton(
                      type: overviewTypes[index],
                      color: _quickColor(index),
                      onTap: () => _openMeasurementForm(
                        initialType: overviewTypes[index],
                      ),
                    ),
                  ),
                _QuickMoreButton(onTap: onOpenResource),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _quickColor(int index) {
    return const [
      _HealthHomeScreenState._mint,
      _HealthHomeScreenState._blush,
      _HealthHomeScreenState._blue,
      _HealthHomeScreenState._orange,
      _HealthHomeScreenState._lavender,
    ][index];
  }
}

class _QuickTypeButton extends StatelessWidget {
  const _QuickTypeButton({
    required this.type,
    required this.color,
    required this.onTap,
  });

  final MeasurementType type;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 102,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              children: [
                Icon(
                  measurementTypeIcons[type],
                  color: _HealthHomeScreenState._ink,
                  size: 25,
                ),
                const SizedBox(height: 6),
                Text(
                  measurementTypeLabels[type] ?? type.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _HealthHomeScreenState._ink,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: _HealthHomeScreenState._muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickMoreButton extends StatelessWidget {
  const _QuickMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Material(
        color: const Color(0xFFF1F1F5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                Icon(Icons.more_horiz, color: _HealthHomeScreenState._muted),
                SizedBox(height: 13),
                Text(
                  'More',
                  style: TextStyle(color: _HealthHomeScreenState._ink),
                ),
                SizedBox(height: 2),
                Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: _HealthHomeScreenState._muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentMeasurementsCard extends StatelessWidget {
  const _RecentMeasurementsCard({
    required this.measurements,
    required this.onEdit,
    required this.onDelete,
    required this.onSeeAll,
  });

  final List<HealthMeasurement> measurements;
  final ValueChanged<HealthMeasurement> onEdit;
  final ValueChanged<HealthMeasurement> onDelete;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  icon: Icons.schedule,
                  title: 'Recent measurements',
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See all'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 17),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (measurements.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: const Text(
                'No measurements recorded yet',
                style: TextStyle(color: _HealthHomeScreenState._muted),
              ),
            )
          else
            for (final HealthMeasurement measurement in measurements) ...[
              _MeasurementRow(
                measurement: measurement,
                onTap: () => onEdit(measurement),
                onDelete: () => onDelete(measurement),
              ),
              if (measurement != measurements.last)
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
            ],
        ],
      ),
    );
  }
}

class _MeasurementRow extends StatelessWidget {
  const _MeasurementRow({
    required this.measurement,
    required this.onTap,
    required this.onDelete,
  });

  final HealthMeasurement measurement;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final int index = overviewTypes.indexOf(measurement.type);
    final Color color = const [
      _HealthHomeScreenState._mint,
      _HealthHomeScreenState._blush,
      _HealthHomeScreenState._blue,
      _HealthHomeScreenState._orange,
      _HealthHomeScreenState._lavender,
    ][index < 0 ? 0 : index];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                measurementTypeIcons[measurement.type],
                color: _HealthHomeScreenState._ink,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              flex: 4,
              child: Text(
                measurementTypeLabels[measurement.type] ??
                    measurement.type.name,
                style: const TextStyle(
                  color: _HealthHomeScreenState._ink,
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                formatValue(measurement),
                style: const TextStyle(
                  color: _HealthHomeScreenState._ink,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                formatDateTime(measurement.measuredAt),
                textAlign: TextAlign.end,
                maxLines: 2,
                style: const TextStyle(
                  color: _HealthHomeScreenState._muted,
                  fontSize: 10.5,
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.chevron_right, size: 20),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendSummaryCard extends StatelessWidget {
  const _TrendSummaryCard({
    required this.all,
    required this.selected,
    required this.onSelect,
  });

  final List<HealthMeasurement> all;
  final MeasurementType selected;
  final ValueChanged<MeasurementType> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.insights_outlined,
            title: 'Recorded trends',
          ),
          const SizedBox(height: 12),
          for (final MeasurementType type in overviewTypes) ...[
            Builder(
              builder: (context) {
                final List<HealthMeasurement> history = historyFor(
                  all,
                  type,
                  limit: 1000,
                );
                return InkWell(
                  onTap: () => onSelect(type),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: _HealthHomeScreenState._mint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            measurementTypeIcons[type],
                            color: _HealthHomeScreenState._ink,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                measurementTypeLabels[type] ?? type.name,
                                style: const TextStyle(
                                  color: _HealthHomeScreenState._ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${history.length} record${history.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: _HealthHomeScreenState._muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          history.isEmpty
                              ? 'Unavailable'
                              : formatValue(history.first),
                          style: const TextStyle(
                            color: _HealthHomeScreenState._muted,
                            fontSize: 12,
                          ),
                        ),
                        if (selected == type)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check,
                              color: _HealthHomeScreenState._green,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (type != overviewTypes.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _UnavailableGoalState extends StatelessWidget {
  const _UnavailableGoalState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.flag_outlined, title: 'Health goals'),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F3),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.track_changes,
                size: 38,
                color: _HealthHomeScreenState._muted,
              ),
              SizedBox(height: 9),
              Text(
                'No saved goal targets',
                style: TextStyle(
                  color: _HealthHomeScreenState._ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Goal data is not available in Health. The summaries below use your current records only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _HealthHomeScreenState._muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _HealthHomeScreenState._muted),
            ),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: _HealthHomeScreenState._ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({required this.repository, required this.onOpen});

  final HealthRepository repository;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<String> summaries = [
      repository.profile == null ? 'Not loaded' : 'View details',
      '${repository.measurements.length} records',
      '${repository.sleepRecords.length} records',
      '${repository.activities.length} records',
      '${repository.logs.length} entries',
      '${repository.events.length} entries',
      '${repository.appointments.where((item) => item.scheduledAt.isAfter(now)).length} upcoming',
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        for (int index = 0; index < _resources.length; index++)
          Material(
            color: const Color(0xFFF2F4F3),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => onOpen(index),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _resources[index].icon,
                      color: _HealthHomeScreenState._green,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _resources[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _HealthHomeScreenState._ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            summaries[index],
                            style: const TextStyle(
                              color: _HealthHomeScreenState._muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MeasurementError extends StatelessWidget {
  const _MeasurementError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: _HealthHomeScreenState._muted,
            ),
            const SizedBox(height: 10),
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

class _HealthLandscapePainter extends CustomPainter {
  const _HealthLandscapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8F3E8), Color(0xFFFFF7DE)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    final double baseline = size.height * 0.88;
    final Paint farMountain = Paint()..color = const Color(0xFFCADBD2);
    final Path back = Path()
      ..moveTo(size.width * 0.33, baseline)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.15,
        size.width * 0.76,
        baseline,
      )
      ..lineTo(size.width, baseline)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.3, size.height)
      ..close();
    canvas.drawPath(back, farMountain);
    final Paint frontMountain = Paint()..color = const Color(0xFF8FB7AC);
    final Path front = Path()
      ..moveTo(size.width * 0.45, baseline)
      ..lineTo(size.width * 0.68, size.height * 0.35)
      ..lineTo(size.width * 0.86, baseline)
      ..lineTo(size.width, size.height * 0.66)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..close();
    canvas.drawPath(front, frontMountain);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.57),
      22,
      Paint()..color = const Color(0xFFFFC77E).withValues(alpha: 0.85),
    );
    final Paint forest = Paint()..color = const Color(0xFF3D7867);
    for (int index = 0; index < 9; index++) {
      final double x = size.width * (0.48 + index * 0.055);
      final double height = 15 + (index % 3) * 5;
      _pine(canvas, Offset(x, baseline + 7), height, forest);
    }
    final Paint branch = Paint()
      ..color = const Color(0xFF315E43)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.98, size.height * 0.1),
      Offset(size.width * 0.86, size.height * 0.76),
      branch,
    );
    _leaf(canvas, const Offset(0.96, 0.22), -0.45, const Color(0xFF4E9B69));
    _leaf(canvas, const Offset(0.93, 0.38), 0.55, const Color(0xFF2F7955));
    _leaf(canvas, const Offset(0.9, 0.56), -0.42, const Color(0xFF5AA875));
    _leaf(canvas, const Offset(0.87, 0.7), 0.48, const Color(0xFF327655));
  }

  void _pine(Canvas canvas, Offset base, double height, Paint paint) {
    final Path path = Path()
      ..moveTo(base.dx, base.dy - height)
      ..lineTo(base.dx - height * 0.32, base.dy)
      ..lineTo(base.dx + height * 0.32, base.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _leaf(Canvas canvas, Offset position, double angle, Color color) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);
    final Path path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(22, -15, 45, 0)
      ..quadraticBezierTo(22, 15, 0, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HealthLandscapePainter oldDelegate) => false;
}

String _activityDurationLabel(List<HealthActivity> activities) {
  if (activities.isEmpty) {
    return 'Not recorded';
  }
  final int minutes = activities.fold(
    0,
    (total, item) => total + (item.durationMinutes ?? 0),
  );
  return minutes == 0
      ? '${activities.length} activities'
      : _durationText(minutes);
}

String _sleepDurationLabel(List<HealthSleepRecord> records) {
  if (records.isEmpty) {
    return 'Not recorded';
  }
  final int minutes = records.fold(
    0,
    (total, item) => total + _sleepMinutes(item),
  );
  return minutes == 0 ? '${records.length} sleep logs' : _durationText(minutes);
}

int _sleepMinutes(HealthSleepRecord record) {
  if (record.durationMinutes != null) {
    return record.durationMinutes!;
  }
  final int minutes = record.endedAt.difference(record.startedAt).inMinutes;
  return minutes < 0 ? 0 : minutes;
}

String _durationText(int minutes) {
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
