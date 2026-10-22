import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../../app_scope.dart';
import '../health_models.dart';
import '../health_repository.dart';
import '../overview_stats.dart';
import 'activity_form_screen.dart';
import 'activity_screen.dart';
import 'appointment_form_screen.dart';
import 'appointments_screen.dart';
import 'event_form_screen.dart';
import 'events_screen.dart';
import 'log_form_screen.dart';
import 'logs_screen.dart';
import 'measurement_form_screen.dart';
import 'measurements_screen.dart';
import 'profile_screen.dart';
import 'sleep_form_screen.dart';
import 'sleep_screen.dart';
import 'vital_detail_screen.dart';
import 'widgets.dart';

/// Health home: glanceable vitals first. Next appointment on top, then the
/// latest measurements, sleep and activity, recent symptoms and events, and
/// the medical profile. Every value comes from the user's own records.
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

class _SheetEntry {
  const _SheetEntry(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Measurements shown in the 2×2 Vitals grid, in reading order.
const List<MeasurementType> _vitalTypes = [
  MeasurementType.weight,
  MeasurementType.bloodPressure,
  MeasurementType.heartRate,
  MeasurementType.temperature,
];

class _HealthHomeScreenState extends State<HealthHomeScreen> {
  static const List<_SheetEntry> _resources = [
    _SheetEntry(Icons.person_outline, 'Profile'),
    _SheetEntry(Icons.monitor_weight_outlined, 'Measurements'),
    _SheetEntry(Icons.bedtime_outlined, 'Sleep'),
    _SheetEntry(Icons.directions_run, 'Activity'),
    _SheetEntry(Icons.assignment_outlined, 'Health logs'),
    _SheetEntry(Icons.event_note_outlined, 'Events'),
    _SheetEntry(Icons.calendar_month_outlined, 'Appointments'),
  ];

  static const List<_SheetEntry> _addOptions = [
    _SheetEntry(Icons.monitor_heart_outlined, 'Measurement'),
    _SheetEntry(Icons.bedtime_outlined, 'Sleep'),
    _SheetEntry(Icons.directions_run, 'Activity'),
    _SheetEntry(Icons.sick_outlined, 'Symptom'),
    _SheetEntry(Icons.event_note_outlined, 'Event'),
    _SheetEntry(Icons.calendar_month_outlined, 'Appointment'),
  ];

  bool _loading = false;
  Object? _measurementsError;

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

  Future<void> _openMeasurementForm({MeasurementType? initialType}) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MeasurementFormScreen(
          repository: _repository,
          initialType: initialType,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadMeasurements();
      await _refreshDashboard();
    }
  }

  /// Pushes a create/edit form and refreshes everything when it saved.
  /// Appointments also feed Home, so they refresh the dashboard too.
  Future<void> _openForm(Widget form, {bool dashboard = false}) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => form),
    );
    if (changed == true && mounted) {
      await _refreshAll();
      if (dashboard && mounted) {
        await _refreshDashboard();
      }
    }
  }

  Future<void> _openVital(MeasurementType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VitalDetailScreen(
          repository: _repository,
          type: type,
          onChanged: _refreshDashboard,
        ),
      ),
    );
  }

  Future<void> _openResource(int index) async {
    final Widget page = switch (index) {
      0 => ProfileScreen(repository: _repository),
      1 => MeasurementsScreen(
          repository: _repository,
          onChanged: _refreshDashboard,
        ),
      2 => SleepScreen(repository: _repository),
      3 => ActivityScreen(repository: _repository),
      4 => LogsScreen(repository: _repository),
      5 => EventsScreen(repository: _repository),
      _ => AppointmentsScreen(
          repository: _repository,
          onChanged: _refreshDashboard,
        ),
    };
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) {
      await _refreshAll();
    }
  }

  void _add(int index) {
    switch (index) {
      case 0:
        _openMeasurementForm();
      case 1:
        _openForm(SleepFormScreen(repository: _repository));
      case 2:
        _openForm(ActivityFormScreen(repository: _repository));
      case 3:
        _openForm(LogFormScreen(repository: _repository));
      case 4:
        _openForm(EventFormScreen(repository: _repository));
      default:
        _openForm(
          AppointmentFormScreen(repository: _repository),
          dashboard: true,
        );
    }
  }

  Future<void> _showSheet({
    required String title,
    required String subtitle,
    required List<_SheetEntry> entries,
    required ValueChanged<int> onSelected,
    List<String>? metas,
  }) async {
    final BlistraColors colors = BlistraColors.resolve(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: colors.sheet,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BlistraText.serif(20, colors.text)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12.5, color: colors.muted)),
              const SizedBox(height: 14),
              GlassList(
                children: [
                  for (int index = 0; index < entries.length; index++)
                    GlassRow(
                      leading: IconWell(entries[index].icon, color: colors.accentText),
                      title: entries[index].label,
                      trailing: RowMeta(
                        metas == null ? '›' : '${metas[index]}  ›',
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onSelected(index);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet() => _showSheet(
        title: 'Add',
        subtitle: 'What would you like to log?',
        entries: _addOptions,
        onSelected: _add,
      );

  void _showResourcePicker() {
    final DateTime now = DateTime.now();
    _showSheet(
      title: 'Health records',
      subtitle: 'Everything you have logged.',
      entries: _resources,
      onSelected: _openResource,
      metas: [
        _repository.profile == null ? '' : 'View',
        '${_repository.measurements.length}',
        '${_repository.sleepRecords.length}',
        '${_repository.activities.length}',
        '${_repository.logs.length}',
        '${_repository.events.length}',
        '${_repository.appointments.where((a) => a.scheduledAt.isAfter(now)).length} upcoming',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repository,
      builder: (context, _) {
        final _HealthView view = _HealthView.from(
          _repository,
          DateTime.now(),
          BlistraColors.resolve(context),
        );
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 112),
                children: [
                  BlistraPageHeader(
                    eyebrow: 'Health',
                    title: 'Your vitals',
                    subtitle: view.subtitle,
                    actions: [
                      GlassIconButton(
                        tooltip: 'Add to Health',
                        icon: Icons.add_rounded,
                        onTap: _showAddSheet,
                      ),
                      GlassIconButton(
                        tooltip: 'Health records',
                        icon: Icons.more_horiz_rounded,
                        onTap: _showResourcePicker,
                      ),
                    ],
                  ),
                  ..._sections(view),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sections(_HealthView view) {
    final bool measurementsMissing = _repository.measurements.isEmpty;
    return [
      if (view.appointment != null)
        PagePad(
          _NextAppointmentCard(
            appointment: view.appointment!,
            now: view.now,
            onTap: () => _openResource(6),
          ),
          top: 14,
        ),
      const SizedBox(height: 24),
      SectionHeader(
        title: 'Vitals',
        actionLabel: 'All ›',
        onAction: () => _openResource(1),
      ),
      PagePad(
        _loading && measurementsMissing
            ? const SkeletonLoader(rows: 2, rowHeight: 92)
            : _measurementsError != null && measurementsMissing
                ? UnavailableCard(name: 'Vitals', onRetry: _loadMeasurements)
                : _VitalsGrid(
                    view: view,
                    onOpen: _openVital,
                    onAdd: (type) => _openMeasurementForm(initialType: type),
                  ),
      ),
      const SizedBox(height: 24),
      const SectionHeader(title: 'Sleep & activity', actionLabel: 'Last 7 days'),
      StatStrip(
        stats: [
          for (final StatData stat in view.sleepAndActivity)
            StatData(
              label: stat.label,
              value: stat.value,
              unit: stat.unit,
              sub: stat.sub,
              onTap: () => _openResource(stat.label == 'Activity' ? 3 : 2),
            ),
        ],
      ),
      const SizedBox(height: 24),
      SectionHeader(
        title: 'Log',
        actionLabel: 'Journal ›',
        onAction: () => _openResource(4),
      ),
      PagePad(
        view.log.isEmpty
            ? EmptyCard(
                message: 'No symptoms or events logged yet.',
                action: 'Log',
                onAction: () => _add(3),
              )
            : GlassList(
                children: [
                  for (final _LogItem item in view.log)
                    GlassRow(
                      leading: IconWell(item.row.icon, color: item.row.color),
                      title: item.row.title,
                      subtitle: item.row.subtitle,
                      onTap: () => _openForm(item.edit(_repository)),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 24),
      SectionHeader(
        title: 'Profile',
        actionLabel: 'Edit ›',
        onAction: () => _openResource(0),
      ),
      PagePad(
        view.profile.isEmpty
            ? EmptyCard(
                message: 'Add your blood group and height. They matter in an '
                    'emergency.',
                action: 'Add',
                onAction: () => _openResource(0),
              )
            : GlassCard(
                padding: const EdgeInsets.all(15),
                onTap: () => _openResource(0),
                child: Row(
                  children: [
                    for (final (String label, String value) in view.profile)
                      Expanded(child: Figure(label: label, value: value)),
                  ],
                ),
              ),
      ),
    ];
  }
}

// ───────────────────────────── view model ─────────────────────────────

/// One row in the Log section with the form that edits it.
class _LogItem {
  const _LogItem(this.at, this.row, this.edit);

  final DateTime at;
  final HealthRow row;
  final Widget Function(HealthRepository repository) edit;
}

/// Everything the home shows, derived from the repository's loaded records.
class _HealthView {
  const _HealthView({
    required this.now,
    required this.subtitle,
    required this.appointment,
    required this.histories,
    required this.sleepAndActivity,
    required this.log,
    required this.profile,
  });

  factory _HealthView.from(
    HealthRepository repository,
    DateTime now,
    BlistraColors colors,
  ) {
    final DateTime weekAgo = now.subtract(const Duration(days: 7));

    final List<HealthAppointment> upcoming = repository.appointments
        .where((a) =>
            a.scheduledAt.isAfter(now) &&
            a.status != AppointmentStatus.cancelled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final Map<MeasurementType, List<HealthMeasurement>> histories = {
      for (final MeasurementType type in _vitalTypes)
        type: historyFor(repository.measurements, type, limit: 2),
    };
    final List<HealthMeasurement> newest =
        mostRecent(repository.measurements, count: 1);

    // Sleep: the latest night, then the average over the last 7 days.
    final List<HealthSleepRecord> sleep = List.of(repository.sleepRecords)
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final List<StatData> stats = [];
    if (sleep.isEmpty) {
      stats.add(const StatData(label: 'Last night', value: '—', sub: 'No sleep logged'));
    } else {
      final HealthSleepRecord last = sleep.first;
      final bool lastNight = isSameLocalDay(last.endedAt, now);
      final DateFormat time = DateFormat('h:mm a');
      stats.add(StatData(
        label: lastNight ? 'Last night' : 'Last sleep',
        value: durationText(sleepMinutes(last)),
        sub: lastNight
            ? '${time.format(last.startedAt.toLocal())} → '
                '${time.format(last.endedAt.toLocal())}'
            : relativeDay(last.endedAt, now),
      ));
      final List<HealthSleepRecord> week =
          sleep.where((s) => s.endedAt.isAfter(weekAgo)).toList();
      if (week.isNotEmpty) {
        final int total = week.fold(0, (sum, s) => sum + sleepMinutes(s));
        stats.add(StatData(
          label: 'Avg sleep',
          value: durationText(total ~/ week.length),
          sub: '${week.length} night${week.length == 1 ? '' : 's'}',
        ));
      }
    }
    final List<HealthActivity> activities = repository.activities
        .where((a) => a.performedAt.isAfter(weekAgo))
        .toList();
    final int minutes =
        activities.fold(0, (sum, a) => sum + (a.durationMinutes ?? 0));
    stats.add(StatData(
      label: 'Activity',
      value: '${activities.length}',
      unit: activities.length == 1 ? 'session' : 'sessions',
      sub: activities.isEmpty
          ? 'Nothing logged'
          : minutes > 0
              ? '$minutes min this week'
              : 'This week',
    ));

    final List<_LogItem> log = [
      for (final HealthLogEntry entry in repository.logs)
        _LogItem(
          entry.observedAt,
          logRow(colors, entry, now),
          (r) => LogFormScreen(repository: r, initial: entry),
        ),
      for (final HealthEvent event in repository.events)
        _LogItem(
          event.occurredAt,
          eventRow(colors, event, now),
          (r) => EventFormScreen(repository: r, initial: event),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    final HealthProfile? p = repository.profile;
    final List<(String, String)> profile = [
      if (p?.bloodType != null && p!.bloodType != BloodType.unknown)
        ('Blood group', _bloodShort(p.bloodType!)),
      if (p?.heightCm != null) ('Height', '${formatDouble(p!.heightCm)} cm'),
    ];

    final List<String> parts = [
      if (newest.isNotEmpty)
        'Last reading ${relativeDay(newest.first.measuredAt, now).toLowerCase()}',
      if (upcoming.isNotEmpty)
        'next appointment ${_futureDay(upcoming.first.scheduledAt, now)}',
    ];
    final String subtitle = parts.isEmpty
        ? 'Log a reading to see your vitals here.'
        : '${parts.join(' · ')[0].toUpperCase()}${parts.join(' · ').substring(1)}';

    return _HealthView(
      now: now,
      subtitle: subtitle,
      appointment: upcoming.isEmpty ? null : upcoming.first,
      histories: histories,
      sleepAndActivity: stats,
      log: log.take(4).toList(),
      profile: profile,
    );
  }

  final DateTime now;
  final String subtitle;
  final HealthAppointment? appointment;

  /// Newest two readings per vital, newest first.
  final Map<MeasurementType, List<HealthMeasurement>> histories;
  final List<StatData> sleepAndActivity;
  final List<_LogItem> log;
  final List<(String, String)> profile;
}

int _daysUntil(DateTime at, DateTime now) {
  final DateTime local = at.toLocal();
  return DateTime(local.year, local.month, local.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}

/// `today`, `tomorrow`, `Fri` within a week, otherwise `24 Oct`.
String _futureDay(DateTime at, DateTime now) {
  final int days = _daysUntil(at, now);
  if (days <= 0) {
    return 'today';
  }
  if (days == 1) {
    return 'tomorrow';
  }
  return DateFormat(days < 7 ? 'EEEE' : 'd MMM').format(at.toLocal());
}

String _bloodShort(BloodType type) => switch (type) {
      BloodType.aPositive => 'A+',
      BloodType.aNegative => 'A−',
      BloodType.bPositive => 'B+',
      BloodType.bNegative => 'B−',
      BloodType.abPositive => 'AB+',
      BloodType.abNegative => 'AB−',
      BloodType.oPositive => 'O+',
      BloodType.oNegative => 'O−',
      BloodType.unknown => 'Unknown',
    };

// ───────────────────────────── widgets ─────────────────────────────

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
    required this.now,
    required this.onTap,
  });

  final HealthAppointment appointment;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BlistraColors colors = BlistraColors.resolve(context);
    final DateTime at = appointment.scheduledAt.toLocal();
    final int days = _daysUntil(at, now);
    final String when = days <= 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : 'in $days days';
    final String where = appointment.location?.trim() ?? '';
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 50,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${at.day}',
                  style: BlistraText.serif(18, colors.accentText, height: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM').format(at).toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colors.accentText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT APPOINTMENT',
                  style: BlistraText.eyebrow(colors.accentText),
                ),
                const SizedBox(height: 3),
                Text(
                  appointment.title.isEmpty ? 'Appointment' : appointment.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    DateFormat('EEE · h:mm a').format(at),
                    if (where.isNotEmpty) where,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(when, color: colors.accentText),
        ],
      ),
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({
    required this.view,
    required this.onOpen,
    required this.onAdd,
  });

  final _HealthView view;
  final ValueChanged<MeasurementType> onOpen;
  final ValueChanged<MeasurementType> onAdd;

  @override
  Widget build(BuildContext context) {
    Widget tile(MeasurementType type) {
      final List<HealthMeasurement> history = view.histories[type] ?? const [];
      return Expanded(
        child: _VitalTile(
          type: type,
          latest: history.isEmpty ? null : history.first,
          previous: history.length > 1 ? history[1] : null,
          now: view.now,
          onTap: () => history.isEmpty ? onAdd(type) : onOpen(type),
        ),
      );
    }

    return Column(
      children: [
        for (int row = 0; row < _vitalTypes.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile(_vitalTypes[row]),
                const SizedBox(width: 10),
                tile(_vitalTypes[row + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.type,
    required this.latest,
    required this.previous,
    required this.now,
    required this.onTap,
  });

  final MeasurementType type;
  final HealthMeasurement? latest;
  final HealthMeasurement? previous;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BlistraColors colors = BlistraColors.resolve(context);
    final HealthMeasurement? m = latest;
    final String label = measurementTypeLabels[type] ?? type.name;
    final String sub;
    if (m == null) {
      sub = 'Tap to add';
    } else {
      final String when = relativeDay(m.measuredAt, now);
      final String? change = shortChange(m, previous);
      sub = change == null ? when : '$change · ${when.toLowerCase()}';
    }
    return Semantics(
      button: true,
      label: m == null ? 'Add $label' : label,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: BlistraText.caption(colors.muted)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: m == null ? '—' : measurementNumber(m),
                  children: [
                    if (m != null)
                      TextSpan(
                        text: ' ${displayUnit(m.unit)}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.muted,
                        ),
                      ),
                  ],
                ),
                style: BlistraText.serif(22, colors.text, height: 1.15),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
