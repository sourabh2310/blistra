import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/glass.dart';
import '../../app_scope.dart';
import '../../habits/habits_controller.dart';
import '../../medicines/data/medicines_api_client.dart';
import '../../medicines/util/dates.dart';
import '../../notifications/state/reminders_controller.dart';
import '../../preferences/shell_destinations.dart';
import '../models/dashboard_response.dart';

/// Home: what is urgent, what is next and what is left today, on frosted
/// glass over the theme backdrop.
///
/// Reading order: header (date, streak, search, notifications, profile) →
/// Next up → Needs attention → next appointment → Today so far → nudges →
/// timeline → habits → health → spending → this week. Every value comes from
/// [DashboardResponse] except habit streaks, which come from the Habits
/// statistics API.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onDestination,
    this.onSearch,
    this.onNotifications,
    this.onProfile,
    this.hubPinned = true,
    this.homeWidgets,
  });

  final void Function(String destinationId)? onDestination;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final bool hubPinned;
  final List<String>? homeWidgets;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Keys of rows with a mutation in flight. Prevents double-submit from
  /// rapid taps; the key is source + id so unrelated rows stay interactive.
  final Set<String> _busy = {};

  /// Current streak per habit id, filled lazily from the Habits API.
  final Map<String, int> _streaks = {};
  final Set<String> _streakRequested = {};

  String _key(TimelineItem item) => '${item.source.name}:${item.sourceId}';

  void _open(String destination) => widget.onDestination?.call(destination);

  Future<void> _refreshHome() async {
    final now = DateTime.now();
    try {
      await AppScope.of(context).dashboard
          .refresh(date: now, offsetMinutes: now.timeZoneOffset.inMinutes);
    } catch (_) {
      // Refresh failures surface via the controller's error state.
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runGuarded(
    TimelineItem item,
    Future<void> Function() work,
  ) async {
    final key = _key(item);
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await work();
      await _refreshHome();
    } catch (_) {
      _fail('Could not update "${item.title}". Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _toggleTask(TimelineItem item) {
    final completed =
        item.rawStatus.toUpperCase() == 'COMPLETED' ||
        item.status == TimelineStatus.completed;
    return _runGuarded(item, () async {
      final planner = AppScope.of(context).planner;
      if (completed) {
        await planner.reopenTask(item.sourceId);
      } else {
        await planner.completeTask(item.sourceId);
      }
    });
  }

  Future<void> _completeHabit(TimelineItem item) {
    HabitsController habits;
    try {
      habits = context.read<HabitsController>();
    } catch (_) {
      _open(item.destination);
      return Future.value();
    }
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return _runGuarded(
      item,
      () =>
          habits.recordCompletion(item.sourceId, completedOn: day).then((_) {}),
    );
  }

  /// Dose mutations go through the Medicines domain API directly: Home owns
  /// no Today controller, and must never change dosage — only record the
  /// domain-supported TAKEN / SKIPPED status for the exact scheduled slot.
  Future<void> _recordDose(TimelineItem item, String status) {
    if (status == 'TAKEN' && item.at.isAfter(DateTime.now())) {
      _fail('This dose is not due yet.');
      return Future.value();
    }
    return _runGuarded(item, () async {
      final auth = context.read<AuthState>();
      final api = MedicinesApiClient(
        tokenProvider: () => auth.apiClient.token ?? '',
        onUnauthorized: () => auth.handleUnauthorized(),
      );
      await api.recordDose(item.sourceId, {
        'status': status,
        'scheduledAt': toOffsetIso(item.at),
        if (item.scheduleId != null) 'scheduleId': item.scheduleId,
      });
    });
  }

  /// Primary action for the Next up hero, when the item supports one.
  Future<void> Function()? _primaryAction(TimelineItem item) =>
      switch (item.source) {
        HomeSource.medicine when item.actionable => () => _recordDose(
          item,
          'TAKEN',
        ),
        HomeSource.task => () => _toggleTask(item),
        HomeSource.habit => () => _completeHabit(item),
        _ => null,
      };

  /// Loads streaks for today's habits once each; failures leave no streak.
  void _loadStreaks(DashboardResponse? dashboard) {
    final habits = dashboard?.habits;
    if (habits == null || habits.unavailable) return;
    HabitsController controller;
    try {
      controller = context.read<HabitsController>();
    } catch (_) {
      return;
    }
    for (final habit in habits.todayHabits) {
      if (habit.id.isEmpty || !_streakRequested.add(habit.id)) continue;
      controller
          .fetchStatistics(habit.id)
          .then((stats) {
            if (mounted) {
              setState(() => _streaks[habit.id] = stats.currentStreak);
            }
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.dashboard, scope.authState]),
      builder: (context, _) {
        final controller = scope.dashboard;
        final dashboard = controller.dashboard;
        final now = DateTime.now();
        final name = resolveDisplayName(
          user: dashboard?.user,
          email: scope.authState.userEmail,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadStreaks(dashboard);
        });
        final streak = _streaks.values.fold<int>(0, math.max);
        final view = dashboard == null
            ? null
            : _HomeData.from(
                dashboard,
                now,
                _orderedWidgets(widget.homeWidgets),
              );
        return Material(
          type: MaterialType.transparency,
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 14,
                bottom: 28,
              ),
              children: [
                PagePad(
                  _Header(
                    now: now,
                    name: name,
                    streak: streak,
                    subtitle:
                        view?.subtitle ??
                        (controller.isLoading
                            ? 'Getting your day ready…'
                            : 'Pull down to try again.'),
                    onSearch: widget.onSearch,
                    onNotifications: widget.onNotifications,
                    onProfile: widget.onProfile,
                  ),
                ),
                if (controller.isLoading && dashboard == null)
                  const PagePad(_Skeleton())
                else if (view == null)
                  PagePad(
                    _FullError(
                      message:
                          controller.error ?? 'Home is unavailable right now.',
                      onRetry: _refreshHome,
                    ),
                  )
                else
                  ..._sections(view),
                if (!widget.hubPinned)
                  PagePad(
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _open('HUB'),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Explore Hub'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sections(_HomeData view) {
    final hero = view.nextUp;
    return [
      if (hero != null)
        PagePad(
          _NextUpHero(
            item: hero,
            busy: _busy.contains(_key(hero)),
            onPrimary: _primaryAction(hero),
            onSkip: hero.source == HomeSource.medicine && hero.actionable
                ? () => _recordDose(hero, 'SKIPPED')
                : null,
            onOpen: () => _open(hero.destination),
          ),
          top: 18,
        ),
      if (view.show(HomeWidgets.needsAttention) && view.attention.isNotEmpty)
        PagePad(_AttentionCard(items: view.attention, onOpen: _open), top: 12),
      if (view.appointment != null)
        PagePad(
          _AppointmentCard(
            appointment: view.appointment!,
            now: view.now,
            onTap: () => _open('HEALTH'),
          ),
          top: 12,
        ),
      if (view.show(HomeWidgets.todayOverview) && view.stats.isNotEmpty) ...[
        PagePad(_SectionTitle('Today so far', action: 'Swipe ›'), top: 26),
        _StatStrip(stats: view.stats, onOpen: _open),
      ],
      if (view.nudges.isNotEmpty)
        PagePad(_NudgeCard(nudges: view.nudges, onOpen: _open), top: 10),
      if (view.show(HomeWidgets.todaysSchedule)) ...[
        PagePad(
          _SectionTitle(
            "Today's timeline",
            action: 'Planner ›',
            onAction: () => _open('PLANNER/TODAY'),
          ),
          top: 26,
        ),
        PagePad(
          view.plannerUnavailable
              ? UnavailableCard(name: 'Planner', onRetry: _refreshHome)
              : view.timeline.isEmpty
              ? const EmptyCard(message: 'Nothing scheduled for today.')
              : _Timeline(
                  items: view.timeline,
                  next: hero,
                  busy: _busy,
                  keyOf: _key,
                  onOpen: (item) => _open(item.destination),
                ),
        ),
      ],
      if (view.show(HomeWidgets.habits) && view.habits != null) ...[
        PagePad(
          _SectionTitle(
            'Habits',
            action:
                '${view.habits!.completedToday} of '
                '${view.habits!.expectedToday} done',
            onAction: () => _open('HABITS'),
          ),
          top: 26,
        ),
        PagePad(
          view.habits!.unavailable
              ? UnavailableCard(name: 'Habits', onRetry: _refreshHome)
              : _HabitsCard(
                  habits: view.habits!,
                  streaks: _streaks,
                  busy: _busy,
                  onComplete: (habit) => _completeHabit(_habitItem(habit)),
                  onOpen: (habit) => _open('HABITS/${habit.id}'),
                ),
        ),
      ],
      if (view.show(HomeWidgets.health) && view.measurements.isNotEmpty) ...[
        PagePad(
          _SectionTitle(
            'Health',
            action: 'Vitals ›',
            onAction: () => _open('HEALTH'),
          ),
          top: 26,
        ),
        _StatStrip(stats: view.measurements, onOpen: _open),
      ],
      if (view.show(HomeWidgets.finance) && view.month != null) ...[
        PagePad(
          _SectionTitle(
            'Spending this month',
            action: 'Finance ›',
            onAction: () => _open('FINANCE'),
          ),
          top: 26,
        ),
        PagePad(_SpendingCard(month: view.month!)),
      ],
      if (view.show(HomeWidgets.thisWeek) &&
          view.week != null &&
          !view.week!.unavailable) ...[
        PagePad(
          _SectionTitle(
            'This week',
            action: 'Details ›',
            onAction: () => _open('HOME/WEEK'),
          ),
          top: 26,
        ),
        PagePad(
          _WeekCard(
            week: view.week!,
            now: view.now,
            onTap: () => _open('HOME/WEEK'),
          ),
        ),
      ],
    ];
  }

  TimelineItem _habitItem(HabitSummary habit) => TimelineItem(
    at: DateTime.now(),
    title: habit.name,
    meta: 'Habit',
    status: TimelineStatus.upcoming,
    destination: 'HABITS/${habit.id}',
    source: HomeSource.habit,
    sourceId: habit.id,
    rawStatus: 'PENDING',
  );
}

List<String> _orderedWidgets(List<String>? raw) {
  if (raw == null || raw.isEmpty) return HomeWidgets.defaults;
  try {
    return HomeWidgets.normalizeWidgets(raw);
  } on ArgumentError {
    return HomeWidgets.defaults;
  }
}

// ───────────────────────────── view model ─────────────────────────────

/// One tile in a horizontal strip (Today so far, Health).
class _Stat {
  const _Stat({
    required this.label,
    required this.value,
    required this.sub,
    required this.destination,
    this.unit = '',
    this.total,
    this.progress,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final String unit;

  /// "of N" shown after [value], for counts with a ring.
  final String? total;
  final String sub;
  final String destination;
  final double? progress;
  final Color? color;
  final IconData? icon;
}

class _Nudge {
  const _Nudge(this.icon, this.title, this.sub, this.action, this.destination);

  final IconData icon;
  final String title;
  final String sub;
  final String action;
  final String destination;
}

/// Everything Home shows, derived once per build from [DashboardResponse].
class _HomeData {
  _HomeData._({
    required this.now,
    required this.widgets,
    required this.timeline,
    required this.nextUp,
    required this.attention,
    required this.appointment,
    required this.stats,
    required this.nudges,
    required this.habits,
    required this.measurements,
    required this.month,
    required this.week,
    required this.plannerUnavailable,
    required this.subtitle,
  });

  final DateTime now;
  final List<String> widgets;
  final List<TimelineItem> timeline;
  final TimelineItem? nextUp;
  final List<AttentionItem> attention;
  final AppointmentSummary? appointment;
  final List<_Stat> stats;
  final List<_Nudge> nudges;
  final HabitSection? habits;
  final List<_Stat> measurements;
  final CurrencySection? month;
  final WeekSection? week;
  final bool plannerUnavailable;
  final String subtitle;

  bool show(String id) => widgets.contains(id);

  factory _HomeData.from(
    DashboardResponse d,
    DateTime now,
    List<String> widgets,
  ) {
    // Today only: overdue items from earlier days live in Needs attention.
    final timeline = buildTimeline(
      d,
      now: now,
      limit: 20,
    ).where((i) => !i.anytime && _sameDay(i.at, now)).toList();
    final nextUp = _pickNextUp(timeline, now);
    final attention = _attention(d, now, nextUp);
    final appointment = _nextAppointment(d.health, now);
    final urgent = nextUp != null && _isUrgent(nextUp, now);
    final parts = <String>[
      if (urgent && nextUp.source == HomeSource.medicine)
        'Your dose is almost due'
      else if (urgent)
        '${nextUp.title} is due now',
      if (attention.isNotEmpty)
        attention.length == 1
            ? 'one thing needs attention'
            : '${_words(attention.length)} things need attention',
    ];
    final subtitle = parts.isEmpty
        ? (timeline.any((i) => !i.done)
              ? "Nothing urgent. Here's what is left today."
              : "You're all caught up for today.")
        : '${_capitalise(parts.join(', and '))}.';
    final finance = d.finance;
    final month =
        finance == null || finance.unavailable || finance.currencies.isEmpty
        ? null
        : finance.currencies.first;
    return _HomeData._(
      now: now,
      widgets: widgets,
      timeline: timeline.take(6).toList(),
      nextUp: nextUp,
      attention: attention,
      appointment: appointment,
      stats: _todayStats(d, now),
      nudges: _nudges(d.diet, now),
      habits: d.habits,
      measurements: _measurements(d.health),
      month: month,
      week: d.week,
      plannerUnavailable: d.planner?.unavailable ?? false,
      subtitle: subtitle,
    );
  }
}

/// Overdue tasks and doses whose time has passed without being taken.
/// Habits have their own card and future doses are not yet a problem, so
/// neither appears here. The Next up item is not repeated.
List<AttentionItem> _attention(
  DashboardResponse d,
  DateTime now,
  TimelineItem? nextUp,
) {
  final items = <AttentionItem>[];
  final planner = d.planner;
  if (planner != null && !planner.unavailable) {
    for (final task in _uniqueTasks(planner)) {
      final status = (task.status ?? '').toUpperCase();
      final at = DateTime.tryParse(task.dueAt ?? task.startAt ?? '')?.toLocal();
      if (task.id.isEmpty ||
          status == 'COMPLETED' ||
          status == 'CANCELLED' ||
          at == null ||
          !at.isBefore(now) ||
          task.id == nextUp?.sourceId) {
        continue;
      }
      final priority = (task.priority ?? '').toUpperCase();
      items.add(
        AttentionItem(
          title: task.title,
          detail: [
            _sameDay(at, now)
                ? 'Overdue since ${_shortTime(at)}'
                : 'Overdue since ${DateFormat('EEEE').format(at)}',
            if (priority == 'HIGH' || priority == 'URGENT') 'High',
          ].join(' · '),
          destination: 'PLANNER/TASK/${task.id}',
        ),
      );
    }
  }
  final meds = d.medicines;
  if (meds != null && !meds.unavailable) {
    for (final dose in meds.dosesToday) {
      final status = dose.status.toUpperCase();
      final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
      if (dose.medicineId.isEmpty ||
          at == null ||
          status == 'TAKEN' ||
          status == 'SKIPPED' ||
          status == 'CANCELLED' ||
          (status != 'MISSED' && at.isAfter(now)) ||
          (nextUp != null &&
              nextUp.sourceId == dose.medicineId &&
              nextUp.at == at)) {
        continue;
      }
      items.add(
        AttentionItem(
          title: dose.medicineName,
          detail: status == 'MISSED'
              ? 'Dose missed at ${_shortTime(at)}'
              : 'Dose was due at ${_shortTime(at)}',
          destination: 'MEDICINES/${dose.medicineId}',
        ),
      );
    }
  }
  return items.take(3).toList();
}

bool _isUrgent(TimelineItem item, DateTime now) =>
    item.status == TimelineStatus.overdue ||
    item.status == TimelineStatus.missed ||
    (item.status == TimelineStatus.due &&
        item.at.difference(now).inMinutes <= 60);

/// The most time-critical open item: a due medicine first, then anything
/// overdue, then the next upcoming item.
TimelineItem? _pickNextUp(List<TimelineItem> items, DateTime now) {
  final open = items
      .where(
        (i) =>
            !i.done &&
            i.status != TimelineStatus.cancelled &&
            i.source != HomeSource.meal,
      )
      .toList();
  for (final i in open) {
    if (i.source == HomeSource.medicine && i.status == TimelineStatus.due) {
      return i;
    }
  }
  for (final i in open) {
    if (i.status == TimelineStatus.overdue && i.source == HomeSource.task) {
      return i;
    }
  }
  for (final i in open) {
    if (!i.at.isBefore(now)) return i;
  }
  return null;
}

AppointmentSummary? _nextAppointment(HealthSection? health, DateTime now) {
  if (health == null || health.unavailable) return null;
  AppointmentSummary? best;
  DateTime? bestAt;
  for (final a in health.upcomingAppointments) {
    final at = DateTime.tryParse(a.scheduledAt)?.toLocal();
    final status = (a.status ?? '').toUpperCase();
    if (at == null || at.isBefore(now) || status == 'CANCELLED') continue;
    if (bestAt == null || at.isBefore(bestAt)) {
      best = a;
      bestAt = at;
    }
  }
  return best;
}

List<_Stat> _todayStats(DashboardResponse d, DateTime now) {
  final colors = ActiveColors.value;
  final stats = <_Stat>[];
  final planner = d.planner;
  if (planner != null && !planner.unavailable) {
    final tasks = _uniqueTasks(planner)
        .where((t) => (t.status ?? '').toUpperCase() != 'CANCELLED');
    final total = tasks.length;
    final done = tasks
        .where((t) => (t.status ?? '').toUpperCase() == 'COMPLETED')
        .length;
    final overdue = planner.overdueTasks.length;
    stats.add(
      _Stat(
        label: 'Tasks',
        value: '$done',
        total: '$total',
        sub: total == 0
            ? 'Nothing due today'
            : '${total - done} left${overdue > 0 ? ' · $overdue overdue' : ''}',
        progress: total == 0 ? 0 : done / total,
        color: colors.accentText,
        destination: 'PLANNER/TODAY',
      ),
    );
  }
  final meds = d.medicines;
  if (meds != null && !meds.unavailable) {
    final total = meds.dosesToday.length;
    final taken = meds.dosesToday.where(_isTaken).length;
    DateTime? next;
    for (final dose in meds.dosesToday) {
      final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
      final s = dose.status.toUpperCase();
      if (at == null || s == 'TAKEN' || s == 'SKIPPED' || s == 'CANCELLED') {
        continue;
      }
      if (!at.isBefore(now) && (next == null || at.isBefore(next))) next = at;
    }
    stats.add(
      _Stat(
        label: 'Medicines',
        value: '$taken',
        total: '$total',
        sub: [
          if (next != null) 'Next ${_shortTime(next)}',
          '${meds.activeMedicineCount} active',
        ].join(' · '),
        progress: total == 0 ? 0 : taken / total,
        color: colors.data[0],
        destination: 'MEDICINES',
      ),
    );
  }
  final habits = d.habits;
  if (habits != null && !habits.unavailable) {
    final left = habits.expectedToday - habits.completedToday;
    stats.add(
      _Stat(
        label: 'Habits',
        value: '${habits.completedToday}',
        total: '${habits.expectedToday}',
        sub: left <= 0 ? 'All done' : '$left remaining',
        progress: habits.expectedToday == 0
            ? 0
            : habits.completedToday / habits.expectedToday,
        color: colors.data[1],
        destination: 'HABITS',
      ),
    );
  }
  final diet = d.diet;
  if (diet != null && !diet.unavailable) {
    final ml = double.tryParse(diet.waterTotalMilliliters ?? '') ?? 0;
    stats.add(
      _Stat(
        label: 'Water',
        value: _plainNumber((ml / 1000).toStringAsFixed(1)),
        unit: 'L',
        sub: diet.waterCount == 1 ? '1 glass' : '${diet.waterCount} glasses',
        icon: Icons.water_drop_outlined,
        destination: 'DIET',
      ),
    );
    final n = diet.nutrition;
    final kcal = n?.caloriesKcal?.total;
    stats.add(
      _Stat(
        label: 'Calories',
        value: kcal == null ? '0' : _plainNumber(kcal),
        unit: 'kcal',
        sub: diet.mealCount == 1
            ? '1 meal logged'
            : '${diet.mealCount} meals logged',
        icon: Icons.local_fire_department_outlined,
        destination: 'DIET',
      ),
    );
    for (final (label, macro, icon) in [
      ('Protein', n?.proteinG, Icons.egg_alt_outlined),
      ('Carbs', n?.carbohydratesG, Icons.rice_bowl_outlined),
      ('Fat', n?.fatG, Icons.opacity_outlined),
      ('Fiber', n?.fiberG, Icons.eco_outlined),
    ]) {
      if (macro?.total == null) continue;
      stats.add(
        _Stat(
          label: label,
          value: _plainNumber(macro!.total!),
          unit: 'g',
          sub: kcal == null ? 'Today' : 'Of ${_plainNumber(kcal)} kcal',
          icon: icon,
          destination: 'DIET',
        ),
      );
    }
  }
  final finance = d.finance;
  if (finance != null && !finance.unavailable && finance.today != null) {
    final today = finance.today!.currencies;
    final c = today.isEmpty ? null : today.first;
    final currency =
        c?.currency ??
        (finance.currencies.isEmpty
            ? 'INR'
            : finance.currencies.first.currency);
    stats.add(
      _Stat(
        label: 'Spent',
        value: formatSpend(c?.expense ?? '0', currency),
        sub: today.length > 1 ? '${today.length} currencies' : 'Today',
        icon: Icons.payments_outlined,
        destination: 'FINANCE',
      ),
    );
    stats.add(
      _Stat(
        label: 'Income',
        value: formatSpend(c?.income ?? '0', currency),
        sub: 'Today',
        icon: Icons.trending_up_rounded,
        destination: 'FINANCE',
      ),
    );
  }
  if (planner != null && !planner.unavailable) {
    final starts = [
      for (final e in planner.todayEvents)
        ?DateTime.tryParse(e.startAt)?.toLocal(),
    ]..sort();
    final next = starts.where((at) => !at.isBefore(now)).firstOrNull;
    stats.add(
      _Stat(
        label: 'Events',
        value: '${starts.length}',
        unit: 'today',
        sub: next == null ? 'None left' : 'Next ${_shortTime(next)}',
        icon: Icons.event_outlined,
        destination: 'PLANNER/TODAY',
      ),
    );
  }
  return stats;
}

List<_Nudge> _nudges(DietSection? diet, DateTime now) {
  if (diet == null || diet.unavailable) return const [];
  final nudges = <_Nudge>[];
  final lastWater = diet.water
      .map((w) => DateTime.tryParse(w.consumedAt ?? '')?.toLocal())
      .whereType<DateTime>()
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
  final ml = double.tryParse(diet.waterTotalMilliliters ?? '') ?? 0;
  final litres = _plainNumber((ml / 1000).toStringAsFixed(1));
  if (now.hour >= 9 && now.hour < 22) {
    if (lastWater == null) {
      nudges.add(
        const _Nudge(
          Icons.water_drop_outlined,
          'No water logged yet today',
          'A glass now keeps you on track',
          '+ Water',
          'DIET',
        ),
      );
    } else if (now.difference(lastWater).inHours >= 3) {
      nudges.add(
        _Nudge(
          Icons.water_drop_outlined,
          'No water since ${_shortTime(lastWater)}',
          '$litres L so far today',
          '+ Water',
          'DIET',
        ),
      );
    }
  }
  final meals = [...diet.meals]
    ..sort((a, b) => (a.consumedAt ?? '').compareTo(b.consumedAt ?? ''));
  final hasDinner = meals.any((m) => (m.type ?? '').toUpperCase() == 'DINNER');
  if (now.hour >= 20 && !hasDinner) {
    final last = meals.isEmpty ? null : meals.last;
    final kcal = last == null ? null : _mealKcal(last);
    nudges.add(
      _Nudge(
        Icons.restaurant_outlined,
        'Dinner not logged yet',
        last == null
            ? 'No meals logged today'
            : 'Last meal · ${_mealTitle(last.type)}'
                  '${kcal == null ? '' : ' · $kcal kcal'}',
        'Log',
        'DIET',
      ),
    );
  }
  return nudges;
}

String? _mealKcal(MealSummary meal) {
  var total = 0.0;
  var any = false;
  for (final item in meal.items) {
    final v = double.tryParse(item.caloriesKcal ?? '');
    if (v != null) {
      total += v;
      any = true;
    }
  }
  return any ? NumberFormat('#,##0').format(total) : null;
}

List<_Stat> _measurements(HealthSection? health) {
  if (health == null || health.unavailable) return const [];
  return [
    for (final m in health.latestMeasurements)
      if (m.value != null)
        _Stat(
          label: _measurementLabel(m.type),
          value: m.valueDiastolic == null
              ? _plainNumber(m.value!)
              : '${_plainNumber(m.value!)}/${_plainNumber(m.valueDiastolic!)}',
          unit: m.unit ?? '',
          sub: _capitalise(_relativeDay(m.measuredAt)),
          icon: _measurementIcon(m.type),
          destination: 'HEALTH',
        ),
  ];
}

IconData _measurementIcon(String type) => switch (type.toUpperCase()) {
  'WEIGHT' => Icons.monitor_weight_outlined,
  'BLOOD_PRESSURE' => Icons.speed_rounded,
  'HEART_RATE' => Icons.favorite_outline,
  'BLOOD_GLUCOSE' || 'GLUCOSE' => Icons.bloodtype_outlined,
  'TEMPERATURE' => Icons.thermostat_outlined,
  _ => Icons.monitor_heart_outlined,
};

String _words(int n) => switch (n) {
  2 => 'two',
  3 => 'three',
  4 => 'four',
  5 => 'five',
  _ => '$n',
};

String _capitalise(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _shortTime(DateTime t) =>
    DateFormat(t.minute == 0 ? 'h a' : 'h:mm a').format(t);

// ───────────────────────────── shared pieces ─────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: BlistraText.serif(17, colors.text)),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.accentText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small square glass button used in the header.
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.child,
    required this.label,
    this.onTap,
    this.width = 38,
  });

  final Widget child;
  final String label;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: width,
          height: 38,
          child: GlassCard(
            radius: 14,
            padding: EdgeInsets.zero,
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}





// ───────────────────────────── header ─────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.now,
    required this.name,
    required this.streak,
    required this.subtitle,
    this.onSearch,
    this.onNotifications,
    this.onProfile,
  });

  final DateTime now;
  final String name;
  final int streak;
  final String subtitle;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final initials = initialsForName(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE · d MMM').format(now).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BlistraText.eyebrow(colors.accentText),
              ),
            ),
            if (streak > 0) ...[
              _GlassIcon(
                label: '$streak-day habit streak',
                width: streak > 9 ? 64 : 56,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: Color(0xFFFFB454),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$streak',
                      style: BlistraText.serif(
                        15,
                        colors.isDark
                            ? const Color(0xFFFFD08A)
                            : const Color(0xFF9A5A00),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            _GlassIcon(
              label: 'Search',
              onTap: onSearch,
              child: Icon(Icons.search_rounded, size: 19, color: colors.text),
            ),
            const SizedBox(width: 8),
            _NotificationButton(onTap: onNotifications),
            const SizedBox(width: 8),
            Semantics(
              label: 'Profile',
              button: true,
              excludeSemantics: true,
              child: _GlassIcon(
                label: 'Profile',
                onTap: onProfile,
                child: initials.isEmpty
                    ? Icon(
                        Icons.person_outline_rounded,
                        size: 19,
                        color: colors.accentText,
                      )
                    : Text(
                        initials,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.accentText,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${greetingForHour(now.hour)},\n'),
              TextSpan(
                text: name == 'there' ? 'there.' : '$name.',
                style: TextStyle(color: colors.accentText),
              ),
            ],
          ),
          style: BlistraText.serif(31, colors.text, height: 1.1),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted),
        ),
      ],
    );
  }
}

/// Bell with a dot while reminders are active. There is no unread count in
/// the API, so the badge never shows a made-up number.
class _NotificationButton extends StatelessWidget {
  const _NotificationButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    var active = false;
    try {
      active = context.watch<RemindersController>().reminders.any(
        (r) => r.isActive,
      );
    } catch (_) {
      active = false;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _GlassIcon(
          label: 'Notifications',
          onTap: onTap,
          child: Icon(
            Icons.notifications_none_outlined,
            size: 19,
            color: colors.text,
          ),
        ),
        if (active)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B7D),
                shape: BoxShape.circle,
                border: Border.all(color: colors.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────── next up ─────────────────────────────

class _NextUpHero extends StatelessWidget {
  const _NextUpHero({
    required this.item,
    required this.busy,
    required this.onOpen,
    this.onPrimary,
    this.onSkip,
  });

  final TimelineItem item;
  final bool busy;
  final VoidCallback onOpen;
  final Future<void> Function()? onPrimary;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final now = DateTime.now();
    final urgent = _isUrgent(item, now);
    final tone = urgent ? colors.danger : colors.accentText;
    final dark = colors.isDark;
    final ink = dark
        ? Colors.white
        : (urgent ? const Color(0xFF4A0F19) : colors.text);
    final soft = ink.withValues(alpha: 0.75);
    final eyebrow = dark
        ? Color.lerp(tone, Colors.white, 0.65)!
        : Color.lerp(tone, Colors.black, 0.15)!;
    final minutes = item.at.difference(now).inMinutes;
    final countdown = minutes > 0
        ? 'in ${_duration(minutes)}'
        : minutes == 0
        ? 'now'
        : 'overdue by ${_duration(-minutes)}';
    final primaryLabel = switch (item.source) {
      HomeSource.medicine => 'Mark taken',
      HomeSource.task => 'Mark done',
      HomeSource.habit => 'Done',
      _ => 'Open',
    };
    final radius = BorderRadius.circular(30);
    return Semantics(
      container: true,
      label: 'Next up: ${item.title}, $countdown',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: tone.withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: -18,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: tone.withValues(alpha: dark ? 0.32 : 0.35),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [
                        tone.withValues(alpha: 0.28),
                        tone.withValues(alpha: 0.07),
                      ]
                    : [
                        Color.alphaBlend(
                          tone.withValues(alpha: 0.22),
                          Colors.white,
                        ),
                        Color.alphaBlend(
                          tone.withValues(alpha: 0.07),
                          Colors.white,
                        ),
                      ],
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onOpen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      urgent
                          ? 'NEXT UP · DUE SOON'
                          : 'NEXT UP · ${_shortTime(item.at).toUpperCase()}',
                      style: BlistraText.eyebrow(eyebrow),
                    ),
                    const SizedBox(height: 8),
                    Text(item.title, style: BlistraText.serif(25, ink)),
                    const SizedBox(height: 4),
                    Text(
                      _heroMeta(item),
                      style: TextStyle(fontSize: 12.5, color: soft),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '● $countdown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: dark ? Colors.white : eyebrow,
                        fontFeatures: BlistraText.tabular,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _HeroButton(
                          label: primaryLabel,
                          filled: true,
                          busy: busy,
                          ink: ink,
                          onTap: onPrimary ?? () async => onOpen(),
                        ),
                        if (onSkip != null) ...[
                          const SizedBox(width: 8),
                          _HeroButton(
                            label: 'Skip',
                            filled: false,
                            busy: false,
                            ink: ink,
                            onTap: busy ? null : () async => onSkip!(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _heroMeta(TimelineItem item) {
  final kind = switch (item.source) {
    HomeSource.medicine => 'Medicine',
    HomeSource.task => 'Task',
    HomeSource.event => 'Event',
    HomeSource.habit => 'Habit',
    HomeSource.meal => 'Meal',
    HomeSource.appointment => 'Appointment',
  };
  return '$kind · scheduled ${_shortTime(item.at)}';
}

String _duration(int minutes) {
  if (minutes < 60) return '$minutes minute${minutes == 1 ? '' : 's'}';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.filled,
    required this.busy,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final bool busy;
  final Color ink;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = BlistraColors.resolve(context).isDark;
    final bg = filled
        ? (dark ? Colors.white : ink)
        : ink.withValues(alpha: dark ? 0.16 : 0.1);
    final fg = filled ? (dark ? const Color(0xFF3A0D14) : Colors.white) : ink;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy || onTap == null ? null : () => onTap!(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(99),
            border: filled
                ? null
                : Border.all(color: ink.withValues(alpha: 0.2)),
          ),
          child: busy
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
        ),
      ),
    );
  }
}

// ───────────────────────────── attention ─────────────────────────────

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.items, required this.onOpen});

  final List<AttentionItem> items;
  final void Function(String destination) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final header = colors.isDark
        ? Color.lerp(colors.danger, Colors.white, 0.45)!
        : colors.danger;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
            color: colors.danger.withValues(alpha: colors.isDark ? 0.2 : 0.12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'NEEDS ATTENTION',
                    style: BlistraText.eyebrow(header).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: header,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            InkWell(
              onTap: () => onOpen(items[i].destination),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: colors.inkAt(0.1))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: colors.danger, blurRadius: 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].detail,
                            style: TextStyle(fontSize: 11, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Open ›',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.accentText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── appointment ─────────────────────────────

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.now,
    required this.onTap,
  });

  final AppointmentSummary appointment;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final at = DateTime.parse(appointment.scheduledAt).toLocal();
    final days = DateTime(
      at.year,
      at.month,
      at.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final when = days == 0
        ? 'Today'
        : days == 1
        ? 'Tomorrow'
        : 'in $days days';
    final where = appointment.location?.trim() ?? '';
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
                Text('NEXT APPOINTMENT', style: BlistraText.eyebrow(colors.accentText)),
                const SizedBox(height: 3),
                Text(
                  appointment.title,
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

// ───────────────────────────── stat strips ─────────────────────────────

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats, required this.onOpen});

  final List<_Stat> stats;
  final void Function(String destination) onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        clipBehavior: Clip.none,
        itemCount: stats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _StatTile(
          stat: stats[i],
          onTap: () => onOpen(stats[i].destination),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.onTap});

  final _Stat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return SizedBox(
      width: 138,
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stat.label.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                      ),
                    ),
                  ),
                  if (stat.progress != null)
                    ProgressRing(
                      progress: stat.progress!,
                      color: stat.color ?? colors.accentText,
                    )
                  else if (stat.icon != null)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.inkAt(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(stat.icon, size: 17, color: colors.muted),
                    ),
                ],
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: stat.value,
                  children: [
                    if (stat.total != null || stat.unit.isNotEmpty)
                      TextSpan(
                        text: stat.total != null
                            ? ' / ${stat.total}'
                            : ' ${stat.unit}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.muted,
                        ),
                      ),
                  ],
                ),
                style: BlistraText.serif(24, colors.text, height: 1.1),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              stat.sub,
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

// ───────────────────────────── nudges ─────────────────────────────

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.nudges, required this.onOpen});

  final List<_Nudge> nudges;
  final void Function(String destination) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < nudges.length; i++)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: colors.inkAt(0.08))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.inkAt(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(nudges[i].icon, size: 17, color: colors.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nudges[i].title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nudges[i].sub,
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    nudges[i].action,
                    color: colors.accentText,
                    onTap: () => onOpen(nudges[i].destination),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── timeline ─────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.items,
    required this.next,
    required this.busy,
    required this.keyOf,
    required this.onOpen,
  });

  final List<TimelineItem> items;
  final TimelineItem? next;
  final Set<String> busy;
  final String Function(TimelineItem) keyOf;
  final void Function(TimelineItem) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Stack(
      children: [
        Positioned(
          left: 49,
          top: 6,
          bottom: 16,
          child: Container(
            width: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.inkAt(0.5), colors.inkAt(0.05)],
              ),
            ),
          ),
        ),
        Column(
          children: [
            for (final item in items)
              _TimelineRow(
                item: item,
                isNext: next != null && keyOf(next!) == keyOf(item),
                busy: busy.contains(keyOf(item)),
                onTap: () => onOpen(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.isNext,
    required this.busy,
    required this.onTap,
  });

  final TimelineItem item;
  final bool isNext;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final now = DateTime.now();
    final dot = switch (item.source) {
      HomeSource.medicine => colors.data[0],
      HomeSource.task => colors.data[1],
      HomeSource.appointment || HomeSource.event => colors.data[2],
      _ => colors.accentText,
    };
    final c = isNext ? colors.accentText : dot;
    final icon = switch (item.source) {
      HomeSource.medicine => Icons.medication_outlined,
      HomeSource.task => Icons.check_rounded,
      HomeSource.event => Icons.event_outlined,
      HomeSource.habit => Icons.repeat_rounded,
      HomeSource.meal => Icons.restaurant_outlined,
      HomeSource.appointment => Icons.medical_services_outlined,
    };
    final sameDay = _sameDay(item.at, now);
    final days = DateTime(
      item.at.year,
      item.at.month,
      item.at.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final Widget? trailing = isNext
        ? Text(
            'NEXT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.accentText,
            ),
          )
        : item.status == TimelineStatus.overdue
        ? Pill('OVERDUE', color: colors.danger)
        : !sameDay && days > 0
        ? Text(
            days == 1 ? 'TOMORROW' : '$days DAYS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.muted,
            ),
          )
        : null;
    final faded = item.done || item.status == TimelineStatus.cancelled;
    final card = Container(
      decoration: isNext
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.accentText.withValues(alpha: 0.4),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.accentText.withValues(alpha: 0.18),
                  colors.accentText.withValues(alpha: 0.05),
                ],
              ),
            )
          : null,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        onTap: onTap,
        // Fade the content, not the glass: opacity over a backdrop blur
        // leaves a dark inner box.
        child: Opacity(
          opacity: faded ? 0.55 : 1,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c,
                        ),
                      )
                    : Icon(icon, size: 16, color: c),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                        decoration: item.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.meta,
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              sameDay
                  ? DateFormat('HH:mm').format(item.at)
                  : '${DateFormat('EEE').format(item.at)}\n'
                        '${DateFormat('HH:mm').format(item.at)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isNext ? colors.accentText : colors.muted,
                fontFeatures: BlistraText.tabular,
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: c, blurRadius: 12)],
                ),
              ),
            ),
          ),
          Expanded(child: card),
        ],
      ),
    );
  }
}

// ───────────────────────────── habits ─────────────────────────────

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({
    required this.habits,
    required this.streaks,
    required this.busy,
    required this.onComplete,
    required this.onOpen,
  });

  final HabitSection habits;
  final Map<String, int> streaks;
  final Set<String> busy;
  final void Function(HabitSummary) onComplete;
  final void Function(HabitSummary) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    if (habits.todayHabits.isEmpty) {
      return const EmptyCard(message: 'No habits due today.');
    }
    final progress = habits.expectedToday == 0
        ? 0.0
        : habits.completedToday / habits.expectedToday;
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressLine(
            value: progress,
            gradient: LinearGradient(
              colors: [colors.accentText, colors.data[0]],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final habit in habits.todayHabits)
                _HabitChip(
                  habit: habit,
                  streak: streaks[habit.id] ?? 0,
                  busy: busy.contains('${HomeSource.habit.name}:${habit.id}'),
                  onTap: habit.completedToday
                      ? () => onOpen(habit)
                      : () => onComplete(habit),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitChip extends StatelessWidget {
  const _HabitChip({
    required this.habit,
    required this.streak,
    required this.busy,
    required this.onTap,
  });

  final HabitSummary habit;
  final int streak;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final done = habit.completedToday;
    return Semantics(
      button: true,
      checked: done,
      label: habit.name,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 9, 13, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: done ? colors.accentSoft : colors.glassFill,
            border: Border.all(
              color: done
                  ? colors.accentText.withValues(alpha: 0.5)
                  : colors.glassBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? colors.accentText : Colors.transparent,
                  border: Border.all(
                    color: done ? colors.accentText : colors.inkAt(0.6),
                    width: 1.8,
                  ),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: colors.accentText,
                        ),
                      )
                    : done
                    ? Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: colors.onAccent,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                habit.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 12,
                  color: Color(0xFFFFB454),
                ),
                Text(
                  '$streak',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.data[1],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── spending ─────────────────────────────

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({required this.month});

  final CurrencySection month;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final net = double.tryParse(month.net) ?? 0;
    final expense = double.tryParse(month.expense) ?? 0;
    final cats = month.topCategories.take(3).toList();
    final barColors = [colors.data[0], colors.data[1], colors.accentText];
    Widget figure(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: BlistraText.serif(17, color)),
          ),
        ],
      ),
    );
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              figure(
                'Income',
                formatSpend(month.income, month.currency),
                colors.accentText,
              ),
              const SizedBox(width: 8),
              figure(
                'Spent',
                formatSpend(month.expense, month.currency),
                colors.text,
              ),
              const SizedBox(width: 8),
              figure(
                'Net',
                '${net > 0 ? '+' : ''}${formatSpend(month.net, month.currency)}',
                net >= 0 ? colors.accentText : colors.danger,
              ),
            ],
          ),
          if (cats.isNotEmpty) const SizedBox(height: 4),
          for (var i = 0; i < cats.length; i++) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cats[i].categoryName,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ),
                Text(
                  formatSpend(cats[i].amount, month.currency),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(
              value: expense <= 0
                  ? 0
                  : (double.tryParse(cats[i].amount) ?? 0) / expense,
              color: barColors[i],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── week ─────────────────────────────

/// Week strip and totals. The API reports how many days were active, not
/// which ones, so the strip only marks past days and today.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, required this.now, this.onTap});

  final WeekSection week;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final start =
        week.start ??
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
    final today = DateTime(now.year, now.month, now.day);
    Widget stat(int n, int of, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: '$n',
              children: [
                TextSpan(
                  text: '/$of',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
            style: BlistraText.serif(21, colors.text),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: colors.muted)),
        ],
      ),
    );
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = DateTime(
                        start.year,
                        start.month,
                        start.day + i,
                      );
                      final isToday = day == today;
                      final past = day.isBefore(today);
                      return Container(
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: isToday
                              ? Colors.transparent
                              : colors.inkAt(past ? 0.14 : 0.07),
                          border: isToday
                              ? Border.all(color: colors.accentText, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          DateFormat('E').format(day).substring(0, 1),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isToday ? colors.accentText : colors.muted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(week.completedTasks, week.tasksDue, 'Tasks done'),
              stat(week.habitCompletions, week.habitOccurrences, 'Habits kept'),
              stat(week.activeDays, 7, 'Active days'),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── states ─────────────────────────────



class _FullError extends StatelessWidget {
  const _FullError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Home is unavailable', style: BlistraText.serif(19, colors.text)),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(fontSize: 12.5, color: colors.muted),
            ),
            const SizedBox(height: 14),
            Pill('Try again', color: colors.accentText, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    Widget block(double h) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: colors.inkAt(0.06),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
    return Semantics(
      label: 'Loading Home',
      child: Column(children: [block(170), block(130), block(124), block(240)]),
    );
  }
}

enum TimelineStatus { upcoming, due, completed, missed, overdue, cancelled }

/// Owning domain of an aggregated Home schedule row. Home never duplicates
/// domain entities; every row keeps its source + source id so taps and
/// inline actions route to the owning domain.
enum HomeSource { task, event, habit, medicine, meal, appointment }

class TimelineItem {
  TimelineItem({
    required this.at,
    required this.title,
    required this.meta,
    required this.status,
    required this.destination,
    this.anytime = false,
    this.source = HomeSource.task,
    this.sourceId = '',
    this.rawStatus = '',
    this.scheduleId,
    this.scheduledAt,
  });

  final DateTime at;
  final String title;
  final String meta;
  final TimelineStatus status;
  final String destination;
  final bool anytime;

  /// Owning domain (medicines / planner / habits / diet / health).
  final HomeSource source;

  /// Id of the owning domain record (task id, dose medicine id, habit id,
  /// meal id, event id, appointment id). Never synthesized.
  final String sourceId;

  /// Verbatim domain status string (e.g. TAKEN / COMPLETED / PENDING).
  /// Display [status] is derived from this without inventing completion.
  final String rawStatus;

  /// Medicine schedule slot, when the source is a dose.
  final String? scheduleId;

  /// Original scheduled instant string, when the source is a dose.
  final String? scheduledAt;

  bool get done => status == TimelineStatus.completed;

  /// Whether Home may offer an inline mutation for this row. Meals, events
  /// and appointments open details only; tasks, habits and pending doses
  /// expose domain-owned actions.
  bool get actionable =>
      source == HomeSource.task ||
      source == HomeSource.habit ||
      (source == HomeSource.medicine &&
          rawStatus.toUpperCase() != 'TAKEN' &&
          rawStatus.toUpperCase() != 'CANCELLED' &&
          rawStatus.toUpperCase() != 'SKIPPED');
}

class AttentionItem {
  AttentionItem({
    required this.title,
    required this.detail,
    required this.destination,
  });

  final String title;
  final String detail;
  final String destination;
}

class HomeMetric {
  HomeMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.destination,
    required this.caption,
    required this.semanticLabel,
    this.progress = 0.0,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final String destination;

  /// Two-line supporting caption rendered under the metric (e.g.
  /// "tasks / remaining"). Static UI copy — the [value] above it is the
  /// live domain number.
  final String caption;

  /// Accessibility label for the card action (e.g. "Open today's tasks").
  final String semanticLabel;

  /// Completion ratio [0, 1] shown as a thin progress bar on the tile.
  final double progress;
}

class HomeOverview {
  HomeOverview(this.metrics);
  final List<HomeMetric> metrics;
  List<HomeMetric> get availableMetrics => metrics;
}

HomeOverview computeHomeOverview(DashboardResponse? dashboard) {
  if (dashboard == null) return HomeOverview(const []);
  final metrics = <HomeMetric>[];
  final planner = dashboard.planner;
  if (planner != null && !planner.unavailable) {
    final allTasks = _uniqueTasks(planner);
    final total = allTasks.length;
    final remaining = allTasks.where((task) {
      final status = (task.status ?? '').toUpperCase();
      return status != 'COMPLETED' && status != 'CANCELLED';
    }).length;
    final done = total - remaining;
    metrics.add(
      HomeMetric(
        label: 'Tasks remaining',
        value: '$remaining',
        detail: 'Today',
        icon: Icons.calendar_today_outlined,
        destination: 'PLANNER/TODAY',
        caption: 'tasks\nremaining',
        semanticLabel: "Open today's tasks",
        progress: total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0),
      ),
    );
  }
  final medicines = dashboard.medicines;
  if (medicines != null && !medicines.unavailable) {
    final expected = medicines.dosesToday.length;
    final taken = medicines.dosesToday.where(_isTaken).length;
    metrics.add(
      HomeMetric(
        label: 'Medicines',
        value: '$taken of $expected',
        detail: 'Taken today',
        icon: Icons.medication_outlined,
        destination: 'MEDICINES',
        caption: 'medicines\ntaken',
        semanticLabel: 'Open medicines',
        progress: expected == 0 ? 0.0 : (taken / expected).clamp(0.0, 1.0),
      ),
    );
  }
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    final expected = habits.expectedToday;
    final done = habits.completedToday;
    metrics.add(
      HomeMetric(
        label: 'Habits',
        value: '${habits.completedToday} of ${habits.expectedToday}',
        detail: 'Done today',
        icon: Icons.eco_outlined,
        destination: 'HABITS',
        caption: 'habits\ncompleted',
        semanticLabel: 'Open habits',
        progress: expected == 0 ? 0.0 : (done / expected).clamp(0.0, 1.0),
      ),
    );
  }
  final finance = dashboard.finance;
  if (finance != null && !finance.unavailable && finance.today != null) {
    final currencies = finance.today!.currencies;
    if (currencies.isEmpty) {
      metrics.add(
        HomeMetric(
          label: 'Spending today',
          value: 'No spending',
          detail: 'No activity today',
          icon: Icons.account_balance_wallet_outlined,
          destination: 'FINANCE',
          caption: 'spent\ntoday',
          semanticLabel: 'Open finance',
        ),
      );
    } else {
      final expense = currencies.length == 1 ? currencies.first.expense : null;
      metrics.add(
        HomeMetric(
          label: 'Spending today',
          value: expense == null || expense.isEmpty
              ? currencies.length == 1
                    ? 'No spending'
                    : '${currencies.length} currencies'
              : formatSpend(expense, currencies.first.currency),
          detail: currencies.length == 1
              ? '${currencies.first.currency} today'
              : 'Currency summaries',
          icon: Icons.account_balance_wallet_outlined,
          destination: 'FINANCE',
          caption: 'spent\ntoday',
          semanticLabel: 'Open finance',
        ),
      );
    }
  }
  return HomeOverview(metrics);
}

List<AttentionItem> buildAttentionItems(
  DashboardResponse? dashboard, {
  DateTime? now,
  int limit = 3,
}) {
  if (dashboard == null) return const [];
  final current = now ?? DateTime.now();
  final result = <AttentionItem>[];
  final planner = dashboard.planner;
  if (planner != null && !planner.unavailable) {
    for (final task in _uniqueTasks(planner)) {
      final status = (task.status ?? '').toUpperCase();
      final at = DateTime.tryParse(task.dueAt ?? task.startAt ?? '')?.toLocal();
      if (task.id.isEmpty ||
          status == 'COMPLETED' ||
          status == 'CANCELLED' ||
          at == null ||
          !at.isBefore(current)) {
        continue;
      }
      result.add(
        AttentionItem(
          title: task.title,
          detail: 'Task is overdue',
          destination: 'PLANNER/TASK/${task.id}',
        ),
      );
    }
  }
  final medicines = dashboard.medicines;
  if (medicines != null && !medicines.unavailable) {
    for (final dose in medicines.dosesToday) {
      final status = dose.status.toUpperCase();
      final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
      if (dose.medicineId.isEmpty ||
          _isTaken(dose) ||
          status == 'CANCELLED' ||
          status == 'SKIPPED' ||
          at == null) {
        continue;
      }
      final isAttention =
          status == 'PENDING' || status == 'MISSED' || at.isBefore(current);
      if (!isAttention) {
        continue;
      }
      result.add(
        AttentionItem(
          title: dose.medicineName,
          detail: status == 'MISSED'
              ? 'Medicine dose was missed'
              : 'Medicine dose is still pending',
          destination: 'MEDICINES/${dose.medicineId}',
        ),
      );
    }
  }
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    final incomplete = habits.todayHabits
        .where((habit) => !habit.completedToday)
        .toList();
    if (incomplete.isNotEmpty) {
      for (final habit in incomplete) {
        if (habit.id.isEmpty) continue;
        result.add(
          AttentionItem(
            title: habit.name,
            detail: 'Habit is still due today',
            destination: 'HABITS/${habit.id}',
          ),
        );
      }
    } else if (habits.expectedToday > habits.completedToday) {
      result.add(
        AttentionItem(
          title: 'Incomplete habits',
          detail: '${habits.expectedToday - habits.completedToday} due today',
          destination: 'HABITS',
        ),
      );
    }
  }
  return result.take(limit).toList();
}

List<TimelineItem> buildTimeline(
  DashboardResponse? dashboard, {
  required DateTime now,
  int limit = 5,
}) {
  if (dashboard == null) return const [];
  final items = <TimelineItem>[];
  final planner = dashboard.planner;
  if (planner != null && !planner.unavailable) {
    for (final event in planner.todayEvents) {
      final start = DateTime.tryParse(event.startAt)?.toLocal();
      if (start == null || event.id.isEmpty) continue;
      final end = DateTime.tryParse(event.endAt ?? '')?.toLocal();
      items.add(
        TimelineItem(
          at: start,
          title: event.title,
          meta:
              'Event · ${_time(start)}${end == null ? '' : ' – ${_time(end)}'}',
          status: _eventStatus(start, end, now),
          destination: 'PLANNER/EVENT/${event.id}',
          source: HomeSource.event,
          sourceId: event.id,
        ),
      );
    }
    for (final task in _uniqueTasks(planner)) {
      final status = (task.status ?? '').toUpperCase();
      if (status == 'CANCELLED') continue;
      final at = DateTime.tryParse(task.dueAt ?? task.startAt ?? '')?.toLocal();
      if (at == null || task.id.isEmpty) continue;
      items.add(
        TimelineItem(
          at: at,
          title: task.title,
          meta: 'Task · ${_time(at)}',
          status: status == 'COMPLETED'
              ? TimelineStatus.completed
              : at.isBefore(now)
              ? TimelineStatus.overdue
              : TimelineStatus.upcoming,
          destination: 'PLANNER/TASK/${task.id}',
          source: HomeSource.task,
          sourceId: task.id,
          rawStatus: task.status ?? '',
        ),
      );
    }
  }
  final medicines = dashboard.medicines;
  if (medicines != null && !medicines.unavailable) {
    for (final dose in medicines.dosesToday) {
      final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
      if (at == null || dose.medicineId.isEmpty) continue;
      final status = dose.status.toUpperCase();
      items.add(
        TimelineItem(
          at: at,
          title: dose.medicineName,
          meta: 'Medicine · ${_time(at)}',
          status: status == 'TAKEN'
              ? TimelineStatus.completed
              : status == 'CANCELLED' || status == 'SKIPPED'
              ? TimelineStatus.cancelled
              : at.isBefore(now)
              ? TimelineStatus.due
              : at.difference(now).inMinutes <= 60
              ? TimelineStatus.due
              : TimelineStatus.upcoming,
          destination: 'MEDICINES/${dose.medicineId}',
          source: HomeSource.medicine,
          sourceId: dose.medicineId,
          rawStatus: dose.status,
          scheduleId: dose.scheduleId,
          scheduledAt: dose.scheduledAt,
        ),
      );
    }
  }
  final diet = dashboard.diet;
  if (diet != null && !diet.unavailable) {
    for (final meal in diet.meals) {
      final at = DateTime.tryParse(meal.consumedAt ?? '')?.toLocal();
      if (at == null || meal.id.isEmpty) continue;
      items.add(
        TimelineItem(
          at: at,
          title: _mealTitle(meal.type),
          meta: 'Diet · ${_time(at)}',
          status: TimelineStatus.completed,
          destination: 'DIET/MEAL/${meal.id}',
          source: HomeSource.meal,
          sourceId: meal.id,
          rawStatus: 'LOGGED',
        ),
      );
    }
  }
  final health = dashboard.health;
  if (health != null && !health.unavailable) {
    for (final appointment in health.upcomingAppointments) {
      final at = DateTime.tryParse(appointment.scheduledAt)?.toLocal();
      if (at == null || !_sameDay(at, now)) continue;
      final status = (appointment.status ?? '').toUpperCase();
      items.add(
        TimelineItem(
          at: at,
          title: appointment.title,
          meta: 'Health · ${_time(at)}',
          status: status == 'COMPLETED'
              ? TimelineStatus.completed
              : status == 'CANCELLED'
              ? TimelineStatus.cancelled
              : at.isBefore(now)
              ? TimelineStatus.overdue
              : TimelineStatus.upcoming,
          destination: 'HEALTH',
          source: HomeSource.appointment,
          sourceId: appointment.id,
          rawStatus: appointment.status ?? '',
        ),
      );
    }
  }
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    for (final habit in habits.todayHabits.where(
      (habit) => !habit.completedToday && habit.id.isNotEmpty,
    )) {
      final anchor = DateTime(now.year, now.month, now.day);
      items.add(
        TimelineItem(
          at: anchor,
          title: habit.name,
          meta: 'Habit · Any time today',
          status: TimelineStatus.upcoming,
          destination: 'HABITS/${habit.id}',
          anytime: true,
          source: HomeSource.habit,
          sourceId: habit.id,
          rawStatus: 'PENDING',
        ),
      );
    }
  }
  items.sort((a, b) {
    if (a.anytime != b.anytime) return a.anytime ? 1 : -1;
    return a.at.compareTo(b.at);
  });
  return items.take(limit).toList();
}

bool _isTaken(DoseSummary dose) => dose.status.toUpperCase() == 'TAKEN';

String _time(DateTime value) => DateFormat('h:mm a').format(value);

String _mealTitle(String? value) {
  if (value == null || value.isEmpty) return 'Meal';
  return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Event display status. A passed scheduled time NEVER means completed:
/// without an owning-domain completion record, a past event is overdue.
/// Events carry no completion flag in the dashboard payload, so the only
/// honest states are due / overdue / upcoming.
TimelineStatus _eventStatus(DateTime start, DateTime? end, DateTime now) {
  if ((end ?? start).isBefore(now)) return TimelineStatus.overdue;
  if (!start.isAfter(now)) return TimelineStatus.due;
  return TimelineStatus.upcoming;
}

/// Human-friendly money text for Home tiles: currency symbol, thousands
/// separators and no trailing zeros ("₹420", "₹1,250.50").
String formatSpend(String amount, String currency) {
  final parsed = double.tryParse(amount);
  if (parsed == null) return amount;
  const symbols = {'INR': '₹', 'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥'};
  final whole = parsed == parsed.roundToDouble();
  final text = NumberFormat(whole ? '#,##0' : '#,##0.00').format(parsed);
  final symbol = symbols[currency.toUpperCase()];
  return symbol != null ? '$symbol$text' : '$currency $text';
}

/// "68.40" -> "68.4", "72.00" -> "72"; non-numeric text is returned as is.
String _plainNumber(String raw) {
  final parsed = double.tryParse(raw);
  if (parsed == null) return raw;
  if (parsed == parsed.roundToDouble()) {
    return NumberFormat('#,##0').format(parsed);
  }
  return NumberFormat('#,##0.##').format(parsed);
}

String _measurementLabel(String type) => switch (type.toUpperCase()) {
  'WEIGHT' => 'Latest weight',
  'HEART_RATE' => 'Heart rate',
  'BLOOD_PRESSURE' => 'Blood pressure',
  'TEMPERATURE' => 'Temperature',
  'HEIGHT' => 'Height',
  final other => other.replaceAll('_', ' ').toLowerCase(),
};

/// "today", "yesterday" or "N days ago" for an ISO timestamp; empty if unknown.
String _relativeDay(String? iso) {
  final at = DateTime.tryParse(iso ?? '')?.toLocal();
  if (at == null) return '';
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}

/// Today's tasks plus overdue ones, each task once. The backend lists a task
/// whose time has passed in both `todayTasks` and `overdueTasks`.
List<TaskSummary> _uniqueTasks(PlannerSection planner) {
  final seen = <String>{};
  return [
    for (final task in [...planner.todayTasks, ...planner.overdueTasks])
      if (task.id.isEmpty || seen.add(task.id)) task,
  ];
}
