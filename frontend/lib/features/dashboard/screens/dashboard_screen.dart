import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/accent_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../app_scope.dart';
import '../../habits/habits_controller.dart';
import '../../medicines/data/medicines_api_client.dart';
import '../../medicines/util/dates.dart';
import '../../notifications/state/reminders_controller.dart';
import '../../preferences/shell_destinations.dart';
import '../models/dashboard_response.dart';

class DashboardScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.dashboard, scope.authState]),
      builder: (context, _) {
        final controller = scope.dashboard;
        final now = DateTime.now();
        final name = resolveDisplayName(
          user: controller.dashboard?.user,
          email: scope.authState.userEmail,
        );
        Future<void> refresh() => controller.refresh(
          date: now,
          offsetMinutes: now.timeZoneOffset.inMinutes,
        );
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  onRefresh: refresh,
                  child: SizedBox.expand(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SafeArea(
                        bottom: false,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Header(
                                    displayName: name,
                                    onSearch: onSearch,
                                    onNotifications: onNotifications,
                                    onProfile: onProfile,
                                  ),
                                  const SizedBox(height: 16),
                                  _Greeting(
                                    name: name,
                                    now: now,
                                    dashboard: controller.dashboard,
                                  ),
                                  const SizedBox(height: 8),
                                  if (controller.isLoading &&
                                      controller.dashboard == null)
                                    const _DashboardSkeleton()
                                  else if (controller.dashboard == null)
                                    _FullError(
                                      message:
                                          controller.error ??
                                          'Home is unavailable right now.',
                                      onRetry: refresh,
                                    )
                                  else
                                    _HomeContent(
                                      dashboard: controller.dashboard!,
                                      now: now,
                                      homeWidgets: _orderedWidgets(homeWidgets),
                                      hubPinned: hubPinned,
                                      onDestination: onDestination,
                                      onRefresh: refresh,
                                    ),
                                ],
                              ),
                            ),
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
      },
    );
  }
}

List<String> _orderedWidgets(List<String>? raw) {
  if (raw == null || raw.isEmpty) return HomeWidgets.defaults;
  try {
    return HomeWidgets.normalizeWidgets(raw);
  } on ArgumentError {
    return HomeWidgets.defaults;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.displayName,
    this.onSearch,
    this.onNotifications,
    this.onProfile,
  });

  final String displayName;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const BlistraMark(size: 26),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Blistra',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.5,
                        color: colors.text,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Everything you need. One app.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _HeaderAction(
          tooltip: 'Search',
          icon: Icons.search_rounded,
          onPressed: onSearch,
        ),
        const SizedBox(width: 8),
        _NotificationAction(onPressed: onNotifications),
        const SizedBox(width: 8),
        Semantics(
          label: 'Profile',
          button: true,
          child: GestureDetector(
            onTap: onProfile,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: colors.gradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: .4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    initialsForName(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FD06B),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badge = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GlassCard(
                padding: EdgeInsets.zero,
                radius: 14,
                blur: 16,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, size: 19, color: colors.text),
                ),
              ),
              if (badge)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D6D),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell action with an unread dot driven exclusively by real reminder state.
///
/// Shows a dot only when a [RemindersController] is available above Home and
/// it holds at least one active (scheduled) reminder. With no provider or no
/// active reminders, no badge is rendered — never a fake permanent dot.
/// Bell action with an unread dot driven exclusively by real reminder state.
///
/// Shows a dot only when a [RemindersController] is available above Home and
/// it holds at least one active (scheduled) reminder. With no provider or no
/// active reminders, no badge is rendered — never a fake permanent dot.
class _NotificationAction extends StatelessWidget {
  const _NotificationAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    bool hasActive = false;
    try {
      final reminders = context.watch<RemindersController>();
      hasActive = reminders.reminders.any((r) => r.isActive);
    } catch (_) {
      hasActive = false;
    }
    return _HeaderAction(
      tooltip: 'Notifications',
      icon: Icons.notifications_none_outlined,
      onPressed: onPressed,
      badge: hasActive,
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    required this.now,
    required this.dashboard,
  });

  final String name;
  final DateTime now;
  final DashboardResponse? dashboard;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final attention = buildAttentionItems(
      dashboard,
      now: now,
      limit: 1000,
    ).length;
    final focus = attention == 0
        ? "You're all caught up for today."
        : 'You have $attention thing${attention == 1 ? '' : 's'} to focus on today.';
    return LayoutBuilder(
      builder: (context, constraints) {
        final artWidth = constraints.maxWidth * .58;
        final artHeight = artWidth * 210 / 220;
        return SizedBox(
          height: math.max(210, artHeight),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -16,
                top: -6,
                width: artWidth,
                height: artHeight,
                child: ExcludeSemantics(
                  child: CustomPaint(painter: _ArchPainter(colors)),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                right: artWidth * .5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${greetingForHour(now.hour)},',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 17,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 40,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.8,
                              color: colors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          _dayPartIcon(now.hour),
                          size: 28,
                          color: const Color(0xFFFFB020),
                          semanticLabel: greetingForHour(now.hour),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('EEEE, d MMMM').format(now),
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 15,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      focus,
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 14,
                        height: 1.4,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.dashboard,
    required this.now,
    required this.homeWidgets,
    required this.hubPinned,
    required this.onDestination,
    required this.onRefresh,
  });

  final DashboardResponse dashboard;
  final DateTime now;
  final List<String> homeWidgets;
  final bool hubPinned;
  final void Function(String destinationId)? onDestination;
  final Future<void> Function() onRefresh;

  Widget _section(String id, {bool compact = false}) => _SectionContent(
    compact: compact,
    id: id,
    dashboard: dashboard,
    now: now,
    onDestination: onDestination,
    onRefresh: onRefresh,
    homeWidgets: homeWidgets,
  );

  @override
  Widget build(BuildContext context) {
    final sections = homeWidgets.where(HomeWidgets.sections.contains).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        // Reference places schedule + attention side by side. On wide
        // layouts pair them in a row (in the user's configured order);
        // phones keep the stacked mobile-first flow.
        final wide = constraints.maxWidth >= 300;
        final pair = wide &&
            sections.contains(HomeWidgets.todaysSchedule) &&
            sections.contains(HomeWidgets.needsAttention);
        var paired = false;
        for (final id in sections) {
          final isPair = id == HomeWidgets.todaysSchedule ||
              id == HomeWidgets.needsAttention;
          if (pair && isPair) {
            if (paired) continue;
            paired = true;
            final first = sections.firstWhere(
              (s) =>
                  s == HomeWidgets.todaysSchedule ||
                  s == HomeWidgets.needsAttention,
            );
            final second = first == HomeWidgets.todaysSchedule
                ? HomeWidgets.needsAttention
                : HomeWidgets.todaysSchedule;
            children.add(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: first == HomeWidgets.todaysSchedule ? 112 : 88,
                    child: _section(first, compact: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: second == HomeWidgets.todaysSchedule ? 112 : 88,
                    child: _section(second, compact: true),
                  ),
                ],
              ),
            );
            children.add(const SizedBox(height: 12));
            continue;
          }
          children.add(_section(id));
          children.add(const SizedBox(height: 12));
        }
        if (!hubPinned) {
          children.add(
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onDestination?.call('HUB'),
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('Explore Hub'),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({
    this.compact = false,
    required this.id,
    required this.dashboard,
    required this.now,
    required this.onDestination,
    required this.onRefresh,
    required this.homeWidgets,
  });

  final bool compact;
  final String id;
  final DashboardResponse dashboard;
  final DateTime now;
  final void Function(String destinationId)? onDestination;
  final Future<void> Function() onRefresh;
  final List<String> homeWidgets;

  @override
  Widget build(BuildContext context) => switch (id) {
    HomeWidgets.todayOverview => _TodayOverview(
      dashboard: dashboard,
      onDestination: onDestination,
      onRefresh: onRefresh,
    ),
    HomeWidgets.todaysSchedule => _TodaySchedule(
      dashboard: dashboard,
      now: now,
      onDestination: onDestination,
      compact: compact,
    ),
    HomeWidgets.needsAttention => _NeedsAttention(
      dashboard: dashboard,
      now: now,
      onDestination: onDestination,
      compact: compact,
    ),
    HomeWidgets.yourLife => _YourLife(
      dashboard: dashboard,
      homeWidgets: homeWidgets,
      onDestination: onDestination,
      onRefresh: onRefresh,
    ),
    HomeWidgets.thisWeek => _ThisWeek(
      week: dashboard.week,
      onDestination: onDestination,
      onRefresh: onRefresh,
    ),
    _ => const SizedBox.shrink(),
  };
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({
    required this.dashboard,
    required this.onDestination,
    required this.onRefresh,
  });

  final DashboardResponse dashboard;
  final void Function(String destinationId)? onDestination;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final metrics = computeHomeOverview(dashboard);
    Widget card(int i) => _MetricCard(
      label: metrics.availableMetrics[i].label,
      value: metrics.availableMetrics[i].value,
      detail: metrics.availableMetrics[i].detail,
      icon: metrics.availableMetrics[i].icon,
      caption: metrics.availableMetrics[i].caption,
      semanticLabel: metrics.availableMetrics[i].semanticLabel,
      onTap: () =>
          onDestination?.call(metrics.availableMetrics[i].destination),
    );
    return _Panel(
      title: 'Today',
      icon: Icons.calendar_today_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Opacity(opacity: 0, child: Text('Today overview')),
          ),
          if (metrics.availableMetrics.isEmpty)
            _ErrorState(onRetry: onRefresh, moduleError: true)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                // Reference hierarchy is a four-card pastel strip. Wide
                // layouts show all four across; phones get a 2 x 2 grid so
                // every card stays a full touch target with no overflow and
                // no horizontal scrolling.
                if (constraints.maxWidth >= 300) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0;
                            i < metrics.availableMetrics.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: card(i)),
                        ],
                      ],
                    ),
                  );
                }
                // Wrap sizes every card to its intrinsic content height,
                // so the icon row + large metric + two-line caption can
                // never clip on 320px phones (a fixed aspect ratio would).
                final cardWidth =
                    (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (var i = 0;
                        i < metrics.availableMetrics.length;
                        i++)
                      SizedBox(width: cardWidth, child: card(i)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TodaySchedule extends StatefulWidget {
  const _TodaySchedule({
    required this.dashboard,
    required this.now,
    required this.onDestination,
    this.compact = false,
  });

  final bool compact;

  final DashboardResponse dashboard;
  final DateTime now;
  final void Function(String destinationId)? onDestination;

  @override
  State<_TodaySchedule> createState() => _TodayScheduleState();
}

class _TodayScheduleState extends State<_TodaySchedule> {
  /// Keys of rows with a mutation in flight. Prevents double-submit from
  /// rapid taps; the key is source + id so unrelated rows stay interactive.
  final Set<String> _busy = {};

  String _key(TimelineItem item) => '${item.source.name}:${item.sourceId}';

  Future<void> _refreshHome() async {
    try {
      final scope = AppScope.of(context);
      await scope.dashboard.refresh(
        date: widget.now,
        offsetMinutes: widget.now.timeZoneOffset.inMinutes,
      );
    } catch (_) {
      // Refresh failures surface via the controller's error state.
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runGuarded(TimelineItem item, Future<void> Function() work) async {
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
      widget.onDestination?.call(item.destination);
      return Future.value();
    }
    final day = DateTime(widget.now.year, widget.now.month, widget.now.day);
    return _runGuarded(
      item,
      () => habits.recordCompletion(item.sourceId, completedOn: day).then((_) {}),
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

  @override
  Widget build(BuildContext context) {
    // "Next up" is a visual reframe of today's schedule: same TimelineItem
    // model, same buildTimeline aggregation, same domain-owned mutations.
    final items = buildTimeline(widget.dashboard, now: widget.now, limit: 6);
    return _Panel(
      title: 'Next up',
      icon: Icons.schedule_rounded,
      compact: widget.compact,
      trailing: _SeeAll(
        onTap: () => widget.onDestination?.call('PLANNER/TODAY'),
      ),
      child: items.isEmpty
          ? const _EmptyState(message: 'Nothing scheduled for today.')
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _ScheduleRow(
                    item: items[i],
                    showDivider: i != items.length - 1,
                    busy: _busy.contains(_key(items[i])),
                    onTap: () =>
                        widget.onDestination?.call(items[i].destination),
                    onCompleteTask: items[i].source == HomeSource.task
                        ? () => _toggleTask(items[i])
                        : null,
                    onCompleteHabit: items[i].source == HomeSource.habit
                        ? () => _completeHabit(items[i])
                        : null,
                    onTakeDose: items[i].source == HomeSource.medicine
                        ? () => _recordDose(items[i], 'TAKEN')
                        : null,
                    onSkipDose: items[i].source == HomeSource.medicine
                        ? () => _recordDose(items[i], 'SKIPPED')
                        : null,
                  ),
              ],
            ),
    );
  }
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({
    required this.dashboard,
    required this.now,
    required this.onDestination,
    this.compact = false,
  });

  final bool compact;

  final DashboardResponse dashboard;
  final DateTime now;
  final void Function(String destinationId)? onDestination;

  @override
  Widget build(BuildContext context) {
    final items = buildAttentionItems(dashboard, now: now, limit: 4);
    return _Panel(
      title: compact ? 'Needs attention' : 'Needs your attention',
      icon: Icons.notifications_none_rounded,
      compact: compact,
      trailing: compact
          ? null
          : _SeeAll(
              label: 'See details',
              onTap: () => onDestination?.call('HUB'),
            ),
      child: items.isEmpty
          ? const _AttentionEmptyState()
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _AttentionRow(
                    item: items[i],
                    showDivider: i != items.length - 1,
                    onTap: () => onDestination?.call(items[i].destination),
                  ),
              ],
            ),
    );
  }
}

/// Positive empty state for the attention section, driven only by the real
/// (empty) AttentionItem list — never hardcoded urgency.
class _AttentionEmptyState extends StatelessWidget {
  const _AttentionEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are on track',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  'No other urgent items right now.',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.25,
                    color: colors.muted,
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

/// Home's personal snapshot. Previously "Your life" rendered every module
/// card (medicines / habits / finance duplicated the TODAY metrics and the
/// Hub). It now renders ONLY Health + Diet from the existing dashboard
/// payload: medicines, habits and finance already live in TODAY and in
/// their own Hub modules. The [HomeWidgets.yourLife] section token is kept
/// so persisted preferences stay compatible; only the rendered content
/// changed. Data, empty states and navigation reuse [_ModuleCard].
class _YourLife extends StatelessWidget {
  const _YourLife({
    required this.dashboard,
    required this.homeWidgets,
    required this.onDestination,
    required this.onRefresh,
  });

  final DashboardResponse dashboard;
  final List<String> homeWidgets;
  final void Function(String destinationId)? onDestination;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // Wellbeing snapshot only — never repeat TODAY's tasks/medicines/
    // habits/finance cards here, regardless of stored module preferences.
    const selected = [HomeWidgets.health, HomeWidgets.diet];
    return _Panel(
      title: 'Your wellbeing',
      icon: Icons.favorite_outline,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          Widget card(String id) => _ModuleCard(
            id: id,
            dashboard: dashboard,
            onDestination: onDestination,
            onRefresh: onRefresh,
          );
          if (constraints.maxWidth >= 300) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: card(selected[0])),
                  const SizedBox(width: spacing),
                  Expanded(child: card(selected[1])),
                ],
              ),
            );
          }
          return Column(
            children: [
              card(selected[0]),
              const SizedBox(height: spacing),
              card(selected[1]),
            ],
          );
        },
      ),
    );
  }
}

class _ThisWeek extends StatelessWidget {
  const _ThisWeek({
    required this.week,
    required this.onDestination,
    required this.onRefresh,
  });

  final WeekSection? week;
  final void Function(String destinationId)? onDestination;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final value = week;
    if (value != null && value.unavailable) {
      return _Panel(
        title: 'This week',
        icon: Icons.bar_chart_rounded,
        child: _ErrorState(onRetry: onRefresh, moduleError: true),
      );
    }
    final total = value == null ? 0 : value.tasksDue + value.habitOccurrences;
    if (value == null || total == 0) {
      return const _Panel(
        title: 'This week',
        icon: Icons.bar_chart_rounded,
        child: _EmptyState(message: 'No weekly activity to show.'),
      );
    }
    final taskProgress = value.tasksDue == 0
        ? 0.0
        : (value.completedTasks / value.tasksDue).clamp(0.0, 1.0).toDouble();
    final habitProgress = value.habitOccurrences == 0
        ? 0.0
        : (value.habitCompletions / value.habitOccurrences)
              .clamp(0.0, 1.0)
              .toDouble();
    return _Panel(
      title: 'This week',
      icon: Icons.bar_chart_rounded,
      trailing: _SeeAll(
        label: 'See details',
        onTap: () => onDestination?.call('DASHBOARD/WEEK'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The backend exposes only week aggregates (never per-day values),
          // so bars show aggregate activity per active day.
          final bars = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WeekBars(
                start: value.start,
                activeDays: value.activeDays,
                taskProgress: taskProgress,
                habitProgress: habitProgress,
              ),
              const SizedBox(height: 6),
              _WeekDayStrip(start: value.start),
            ],
          );
          final details = _WeekDetails(
            habitProgress: habitProgress,
            taskProgress: taskProgress,
            activeDays: value.activeDays,
          );
          if (constraints.maxWidth < 300) {
            return Column(children: [bars, const SizedBox(height: 10), details]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 11, child: bars),
              const SizedBox(width: 10),
              Expanded(flex: 14, child: details),
            ],
          );
        },
      ),
    );
  }
}

/// Monday-through-Sunday activity bars built from the real week aggregates.
/// Heights derive only from [taskProgress], [habitProgress] and
/// [activeDays] — the backend provides no per-day completions, so no
/// per-day values are claimed. The first [activeDays] columns (from Monday)
/// render filled at aggregate height; the rest render as track. The date
/// row itself is [_WeekDayStrip] with the real week [start] dates.
class _WeekBars extends StatelessWidget {
  const _WeekBars({
    required this.start,
    required this.activeDays,
    required this.taskProgress,
    required this.habitProgress,
  });

  final DateTime? start;
  final int activeDays;
  final double taskProgress;
  final double habitProgress;

  @override
  Widget build(BuildContext context) {
    final monday = start ?? _WeekDayStrip.mondayOf(DateTime.now());
    final today = DateTime.now();
    final isThisWeek =
        !today.isBefore(monday) &&
        today.isBefore(monday.add(const Duration(days: 7)));
    final overall =
        ((taskProgress + habitProgress) / 2).clamp(0.15, 1.0).toDouble();
    final filled = activeDays.clamp(0, 7);
    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.5),
                child: _WeekBar(
                  isActive: i < filled,
                  isToday:
                      isThisWeek &&
                      monday.add(Duration(days: i)).day == today.day &&
                      monday.add(Duration(days: i)).month == today.month,
                  height: (i < filled ? 18 + 40 * overall : 8.0).toDouble(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single week-activity bar. Height and fill come exclusively from the
/// real week aggregates computed in [_ThisWeek].
class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.isActive,
    required this.isToday,
    required this.height,
  });

  final bool isActive;
  final bool isToday;
  final double height;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    height: isToday && isActive ? height + 6 : height,
    decoration: BoxDecoration(
      color: isToday && isActive
          ? BlistraColors.resolve(context).accent
          : isActive
          ? BlistraColors.resolve(context).accent.withValues(alpha: .75)
          : BlistraColors.resolve(context).accent.withValues(alpha: .18),
      borderRadius: const BorderRadius.all(Radius.circular(6)),
    ),
  );
}

/// Monday-through-Sunday strip built from the real week [start] returned by
/// the backend. Shows honest calendar dates only — never invented activity.
class _WeekDayStrip extends StatelessWidget {
  const _WeekDayStrip({required this.start});

  final DateTime? start;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monday = start ?? _mondayOf(DateTime.now());
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[i],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BlistraColors.resolve(context).muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${monday.add(Duration(days: i)).day}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Monday of [day]'s week. Shared with [_WeekBars] so bars and date
  /// labels always agree on the same real calendar days.
  static DateTime mondayOf(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static DateTime _mondayOf(DateTime day) => mondayOf(day);
}

class _WeekDetails extends StatelessWidget {
  const _WeekDetails({
    required this.habitProgress,
    required this.taskProgress,
    required this.activeDays,
  });

  final double habitProgress;
  final double taskProgress;
  final int activeDays;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Container(
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _WeekDetail(
              value: '${(habitProgress * 100).round()}%',
              label: 'Habits\ncompleted',
            ),
          ),
          Expanded(
            child: _WeekDetail(
              value: '${(taskProgress * 100).round()}%',
              label: 'Tasks\ncompleted',
            ),
          ),
          Expanded(
            child: _WeekDetail(value: '$activeDays / 7', label: 'Days\nactive'),
          ),
        ],
      ),
    );
  }
}

class _WeekDetail extends StatelessWidget {
  const _WeekDetail({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, height: 1.2, color: colors.muted),
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.id,
    required this.dashboard,
    required this.onDestination,
    required this.onRefresh,
  });

  final String id;
  final DashboardResponse dashboard;
  final void Function(String destinationId)? onDestination;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final value = _moduleValue();
    if (value.isError) {
      return _ModuleCardShell(
        id: id,
        icon: _moduleIcon(id),
        value: 'Unavailable',
        detail: 'Could not load this module.',
        action: IconButton(
          onPressed: onRefresh,
          tooltip: 'Retry',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.refresh, size: 18),
        ),
      );
    }
    return _ModuleCardShell(
      id: id,
      icon: _moduleIcon(id),
      value: value.value,
      detail: value.detail,
      onTap: () => onDestination?.call(_moduleDestination(id)),
    );
  }

  _ModuleValue _moduleValue() {
    switch (id) {
      case HomeWidgets.health:
        final section = dashboard.health;
        if (section == null || section.unavailable) return _ModuleValue.error();
        final measurements = [...section.latestMeasurements];
        measurements.sort((a, b) {
          final aDate =
              DateTime.tryParse(a.measuredAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              DateTime.tryParse(b.measuredAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        // Weight is the headline health number when recorded; otherwise the
        // most recent reading of any kind.
        MeasurementSummary? item;
        for (final m in measurements) {
          if (m.type.toUpperCase() == 'WEIGHT') {
            item = m;
            break;
          }
        }
        item ??= measurements.isEmpty ? null : measurements.first;
        if (item == null) {
          return const _ModuleValue(
            'No recent measurement',
            'No recent measurement',
          );
        }
        final unit = item.unit == null || item.unit!.isEmpty ? '' : ' ${item.unit}';
        final label = _measurementLabel(item.type);
        final age = _relativeDay(item.measuredAt);
        return _ModuleValue(
          '${_plainNumber(item.value ?? '')}$unit',
          age.isEmpty ? label : '$label · $age',
        );
      case HomeWidgets.medicines:
        final section = dashboard.medicines;
        if (section == null || section.unavailable) return _ModuleValue.error();
        final expected = section.dosesToday.length;
        final taken = section.dosesToday.where(_isTaken).length;
        return _ModuleValue(
          '$taken of $expected',
          expected == 0 ? 'No doses expected today' : 'Doses taken today',
        );
      case HomeWidgets.diet:
        final section = dashboard.diet;
        if (section == null || section.unavailable) return _ModuleValue.error();
        final calories = section.nutrition?.caloriesKcal?.total;
        return _ModuleValue(
          calories == null || calories.isEmpty
              ? '${section.mealCount} meal${section.mealCount == 1 ? '' : 's'}'
              : '${_plainNumber(calories)} kcal',
          'Logged today',
        );
      case HomeWidgets.habits:
        final section = dashboard.habits;
        if (section == null || section.unavailable) return _ModuleValue.error();
        return _ModuleValue(
          '${section.completedToday} of ${section.expectedToday}',
          section.expectedToday == 0
              ? 'No habits expected today'
              : 'Completed today',
        );
      case HomeWidgets.finance:
        final section = dashboard.finance;
        if (section == null || section.unavailable) return _ModuleValue.error();
        final currencies = section.today?.currencies ?? const [];
        if (currencies.isEmpty) {
          return const _ModuleValue('No spending', 'No activity today');
        }
        if (currencies.length == 1) {
          final currency = currencies.first;
          final expense = currency.expense;
          return _ModuleValue(
            expense.isEmpty
                ? 'No spending'
                : formatSpend(expense, currency.currency),
            '${currency.currency} spent today',
          );
        }
        return _ModuleValue(
          '${currencies.length} currencies',
          'Spending summaries today',
        );
      default:
        return const _ModuleValue('Unavailable', '');
    }
  }
}

class _ModuleValue {
  const _ModuleValue(this.value, this.detail) : isError = false;
  const _ModuleValue.error()
    : value = 'Unavailable',
      detail = '',
      isError = true;

  final String value;
  final String detail;
  final bool isError;
}

class _ModuleCardShell extends StatelessWidget {
  const _ModuleCardShell({
    required this.id,
    required this.icon,
    required this.value,
    required this.detail,
    this.action,
    this.onTap,
  });

  final String id;
  final IconData icon;
  final String value;
  final String detail;
  final Widget? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final style = _moduleStyle(id, Theme.of(context).colorScheme);
    return Semantics(
      label: '${HomeWidgets.label(id)}: $value $detail',
      button: onTap != null,
      child: _ModuleTile(
        color: style.foreground,
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _TileIcon(icon: icon, color: style.foreground, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    HomeWidgets.label(id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.muted),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.2,
                      color: colors.muted,
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.compact = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  /// Smaller heading and padding for half-width panels.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 24,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        compact ? 12 : 14,
        compact ? 10 : 14,
        compact ? 8 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 17 : 20, color: colors.accentText),
                SizedBox(width: compact ? 5 : 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: colors.text,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          child,
        ],
      ),
    );
  }
}

/// Reference-style today summary card: pastel surface, circular tinted icon
/// with a chevron, large serif metric, two-line caption. The [value] is the
/// live domain number; only the static caption copy is fixed.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.caption,
    required this.semanticLabel,
    required this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final String caption;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final style = _metricStyle(label, Theme.of(context).colorScheme);
    return Semantics(
      label: '$semanticLabel: $value $detail',
      button: true,
      child: _ModuleTile(
        color: style.foreground,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _TileIcon(icon: icon, color: style.foreground, size: 32),
                Icon(Icons.chevron_right, size: 14, color: colors.muted),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Fraunces',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, height: 1.2, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted glass tile used for module summaries.
class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.color,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
  });

  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: colors.isDark ? .26 : .20),
              color.withValues(alpha: .06),
            ],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.color, this.size = 32});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .28),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: size * .54, color: onGlass(context, color)),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.item,
    required this.onTap,
    this.showDivider = true,
    this.busy = false,
    this.onCompleteTask,
    this.onCompleteHabit,
    this.onTakeDose,
    this.onSkipDose,
  });

  final TimelineItem item;
  final VoidCallback onTap;
  final bool showDivider;
  final bool busy;
  final VoidCallback? onCompleteTask;
  final VoidCallback? onCompleteHabit;
  final VoidCallback? onTakeDose;
  final VoidCallback? onSkipDose;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final statusColor = _timelineColor(item.status, Theme.of(context).colorScheme);
    final category = _categoryColor(item.meta);
    final time = item.anytime
        ? 'Any\ntime'
        : DateFormat('h:mm\na').format(item.at);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                time,
                style: TextStyle(fontSize: 9, height: 1.15, color: colors.muted),
              ),
            ),
            SizedBox(
              width: 12,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showDivider)
                    Positioned(
                      top: 22,
                      bottom: -22,
                      child: Container(width: 1.5, color: colors.glassBorder),
                    ),
                  Semantics(
                    label: _timelineStatusLabel(item.status),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: category.withValues(alpha: .20),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                _categoryIcon(item.meta),
                size: 14,
                color: onGlass(context, category),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    item.meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.2,
                      color: colors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _ScheduleTrailing(
              item: item,
              statusColor: statusColor,
              busy: busy,
              onCompleteTask: onCompleteTask,
              onCompleteHabit: onCompleteHabit,
              onTakeDose: onTakeDose,
              onSkipDose: onSkipDose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Trailing inline action for a schedule row. Mutations always go through
/// the owning domain controller/API; Home never invents dosage, completion,
/// or medical decisions. While a mutation is in flight a spinner replaces
/// the action to prevent double-submit.
/// Trailing inline action for a schedule row. Mutations always go through
/// the owning domain controller/API; Home never invents dosage, completion,
/// or medical decisions. While a mutation is in flight a spinner replaces
/// the action to prevent double-submit.
///
/// Rendered as a small check circle (as in the design). A due dose is taken
/// with a tap and skipped with a long press.
class _ScheduleTrailing extends StatelessWidget {
  const _ScheduleTrailing({
    required this.item,
    required this.statusColor,
    required this.busy,
    this.onCompleteTask,
    this.onCompleteHabit,
    this.onTakeDose,
    this.onSkipDose,
  });

  final TimelineItem item;
  final Color statusColor;
  final bool busy;
  final VoidCallback? onCompleteTask;
  final VoidCallback? onCompleteHabit;
  final VoidCallback? onTakeDose;
  final VoidCallback? onSkipDose;

  Widget _circle(
    BuildContext context, {
    required bool done,
    required String tooltip,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final colors = BlistraColors.resolve(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? colors.accent : Colors.transparent,
              border: Border.all(
                color: done ? colors.accent : colors.muted,
                width: 1.8,
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 11, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 26,
        height: 26,
        child: Padding(
          padding: EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final completed = item.status == TimelineStatus.completed;
    if (onCompleteTask != null && item.source == HomeSource.task) {
      return _circle(
        context,
        done: completed,
        tooltip: completed ? 'Reopen task' : 'Complete task',
        onTap: onCompleteTask,
      );
    }
    if (onCompleteHabit != null && item.source == HomeSource.habit) {
      return _circle(
        context,
        done: completed,
        tooltip: 'Mark habit complete',
        onTap: onCompleteHabit,
      );
    }
    if (item.source == HomeSource.medicine && item.actionable) {
      final due = !item.at.isAfter(DateTime.now());
      if (!due) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.notifications_none, size: 18, color: statusColor),
        );
      }
      return _circle(
        context,
        done: false,
        tooltip: 'Take dose (long press to skip)',
        onTap: onTakeDose,
        onLongPress: onSkipDose,
      );
    }
    if (completed) {
      return _circle(context, done: true, tooltip: 'Completed');
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(_timelineIcon(item.status), size: 17, color: statusColor),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.item,
    required this.onTap,
    this.showDivider = true,
  });

  final AttentionItem item;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final color = _attentionColor(item.detail);
    return Padding(
      padding: EdgeInsets.only(bottom: showDivider ? 7 : 0),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: colors.isDark ? .16 : .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .28),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _attentionIcon(item.detail),
                      size: 14,
                      color: onGlass(context, color),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          item.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.2,
                            color: onGlass(context, color),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 13, color: colors.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap, this.label = 'See all'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          '$label ›',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: BlistraColors.resolve(context).accentText,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, this.moduleError = false});
  final Future<void> Function() onRetry;
  final bool moduleError;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          moduleError
              ? 'Some Home data could not be loaded.'
              : 'Try again to load Home.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}

class _FullError extends StatelessWidget {
  const _FullError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Home is unavailable',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ),
  );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: [
        _SkeletonBlock(color: color, height: 180),
        const SizedBox(height: 16),
        _SkeletonBlock(color: color, height: 120),
        const SizedBox(height: 16),
        _SkeletonBlock(color: color, height: 240),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.color, required this.height});
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

class _FeatureStyle {
  const _FeatureStyle({
    required this.background,
    required this.iconBackground,
    required this.foreground,
  });

  final Color background;
  final Color iconBackground;
  final Color foreground;
}

_FeatureStyle _metricStyle(String label, ColorScheme scheme) {
  if (label.contains('Tasks')) {
    return const _FeatureStyle(
      background: Color(0xFFE9F7EF),
      iconBackground: Color(0xFFD4F0E3),
      foreground: ModuleColors.planner,
    );
  }
  if (label.contains('Medicines')) {
    return const _FeatureStyle(
      background: Color(0xFFEFF5FF),
      iconBackground: Color(0xFFDDE9FF),
      foreground: ModuleColors.medicines,
    );
  }
  if (label.contains('Habits')) {
    return const _FeatureStyle(
      background: Color(0xFFFFF3E8),
      iconBackground: Color(0xFFFFE3C6),
      foreground: ModuleColors.diet,
    );
  }
  return _FeatureStyle(
    background: scheme.brightness == Brightness.dark
        ? const Color(0xFF302746)
        : const Color(0xFFF4EAFE),
    iconBackground: scheme.brightness == Brightness.dark
        ? const Color(0xFF493560)
        : const Color(0xFFE9D7FC),
    foreground: ModuleColors.habits,
  );
}

_FeatureStyle _moduleStyle(String id, ColorScheme scheme) => switch (id) {
  HomeWidgets.health => const _FeatureStyle(
    background: Color(0xFFFFEEEE),
    iconBackground: Color(0xFFFFD7D7),
    foreground: ModuleColors.health,
  ),
  HomeWidgets.medicines => const _FeatureStyle(
    background: Color(0xFFEFF5FF),
    iconBackground: Color(0xFFDDE9FF),
    foreground: Color(0xFF2878EA),
  ),
  HomeWidgets.diet => const _FeatureStyle(
    background: Color(0xFFFFF3E8),
    iconBackground: Color(0xFFFFE3C6),
    foreground: ModuleColors.diet,
  ),
  HomeWidgets.habits => const _FeatureStyle(
    background: Color(0xFFEAF7EF),
    iconBackground: Color(0xFFD4F0E3),
    foreground: Color(0xFF0B6B4F),
  ),
  HomeWidgets.finance => _metricStyle('Spending today', scheme),
  _ => _metricStyle('', scheme),
};

IconData _categoryIcon(String meta) {
  if (meta.startsWith('Medicine')) return Icons.medication_outlined;
  if (meta.startsWith('Habit')) return Icons.directions_run_rounded;
  if (meta.startsWith('Meal')) return Icons.restaurant_outlined;
  if (meta.startsWith('Health')) return Icons.favorite_outline;
  if (meta.startsWith('Event')) return Icons.groups_2_outlined;
  if (meta.startsWith('Task')) return Icons.description_outlined;
  return Icons.circle_outlined;
}

Color _categoryColor(String meta) {
  if (meta.startsWith('Medicine')) return const Color(0xFFEF5570);
  if (meta.startsWith('Habit')) return const Color(0xFF1B9A70);
  if (meta.startsWith('Meal')) return const Color(0xFFE76B2E);
  if (meta.startsWith('Health')) return const Color(0xFFB640A0);
  if (meta.startsWith('Event')) return const Color(0xFF7D42D5);
  if (meta.startsWith('Task')) return const Color(0xFF377BD5);
  return const Color(0xFF4A837B);
}

Color _timelineColor(TimelineStatus status, ColorScheme scheme) =>
    switch (status) {
      TimelineStatus.completed => const Color(0xFF18A768),
      TimelineStatus.overdue ||
      TimelineStatus.missed => const Color(0xFFE24545),
      TimelineStatus.due => const Color(0xFFE24545),
      TimelineStatus.cancelled => scheme.outline,
      TimelineStatus.upcoming => const Color(0xFF3278E8),
    };

Color _attentionColor(String detail) {
  if (detail.contains('overdue')) return const Color(0xFFC6402E);
  if (detail.contains('Medicine')) return const Color(0xFFDE3D5B);
  return const Color(0xFF16805D);
}

IconData _attentionIcon(String detail) {
  if (detail.contains('overdue')) return Icons.check_rounded;
  if (detail.contains('Medicine')) return Icons.medication_outlined;
  return Icons.bolt_rounded;
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
    final remaining = _uniqueTasks(planner).where((
      task,
    ) {
      final status = (task.status ?? '').toUpperCase();
      return status != 'COMPLETED' && status != 'CANCELLED';
    }).length;
    metrics.add(
      HomeMetric(
        label: 'Tasks remaining',
        value: '$remaining',
        detail: 'Today',
        icon: Icons.calendar_today_outlined,
        destination: 'PLANNER/TODAY',
        caption: 'tasks\nremaining',
        semanticLabel: "Open today's tasks",
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
      ),
    );
  }
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    metrics.add(
      HomeMetric(
        label: 'Habits',
        value: '${habits.completedToday} of ${habits.expectedToday}',
        detail: 'Done today',
        icon: Icons.eco_outlined,
        destination: 'HABITS',
        caption: 'habits\ncompleted',
        semanticLabel: 'Open habits',
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

IconData _moduleIcon(String id) => switch (id) {
  HomeWidgets.health => Icons.favorite_outline,
  HomeWidgets.medicines => Icons.medication_outlined,
  HomeWidgets.diet => Icons.restaurant_outlined,
  HomeWidgets.habits => Icons.repeat,
  HomeWidgets.finance => Icons.account_balance_wallet_outlined,
  _ => Icons.circle_outlined,
};

String _moduleDestination(String id) => switch (id) {
  HomeWidgets.health => 'HEALTH',
  HomeWidgets.medicines => 'MEDICINES',
  HomeWidgets.diet => 'DIET',
  HomeWidgets.habits => 'HABITS',
  HomeWidgets.finance => 'FINANCE',
  _ => 'HUB',
};

IconData _timelineIcon(TimelineStatus status) => switch (status) {
  TimelineStatus.completed => Icons.check_circle_outline,
  TimelineStatus.overdue || TimelineStatus.missed => Icons.error_outline,
  TimelineStatus.due => Icons.notifications_none,
  TimelineStatus.cancelled => Icons.remove_circle_outline,
  TimelineStatus.upcoming => Icons.circle_outlined,
};

String _time(DateTime value) => DateFormat('h:mm a').format(value);

/// Time-of-day glyph beside the greeting name (reference shows a sun).
/// Purely presentational; the hour comes from the user's local time.
IconData _dayPartIcon(int hour) {
  if (hour >= 5 && hour < 12) return Icons.wb_sunny_rounded;
  if (hour >= 12 && hour < 17) return Icons.wb_sunny_outlined;
  if (hour >= 17 && hour < 21) return Icons.wb_twilight_rounded;
  return Icons.nightlight_round;
}

String _mealTitle(String? value) {
  if (value == null || value.isEmpty) return 'Meal';
  return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _timelineStatusLabel(TimelineStatus status) => switch (status) {
  TimelineStatus.upcoming => 'Upcoming',
  TimelineStatus.due => 'Due',
  TimelineStatus.completed => 'Completed',
  TimelineStatus.missed => 'Missed',
  TimelineStatus.overdue => 'Overdue',
  TimelineStatus.cancelled => 'Cancelled',
};

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

/// Window-with-landscape artwork used beside the greeting. Colours follow the
/// accent palette and light/dark mode.
class _ArchPainter extends CustomPainter {
  const _ArchPainter(this.colors);

  final BlistraColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 220, size.height / 210);
    final p = colors.accent;
    final p2 = colors.accent2;
    final dark = colors.isDark;
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    final sky1 = dark ? mix(const Color(0xFF12113A), p, .28) : mix(const Color(0xFFFFF0D8), p2, .32);
    final sky2 = dark ? mix(const Color(0xFF2A1848), p2, .6) : mix(const Color(0xFFEAF6F2), p, .28);
    final sun = dark ? const Color(0xFFFFD9A0) : const Color(0xFFFFF4CC);
    final m1 = dark ? mix(const Color(0xFF1D1B4A), p, .4) : mix(const Color(0xFFDBE9EC), p, .4);
    final m2 = dark ? mix(const Color(0xFF13113A), p, .28) : mix(const Color(0xFFBCD6D6), p, .62);
    final m3 = dark ? mix(const Color(0xFF0A0A26), p, .2) : mix(const Color(0xFF16463D), p, .78);
    final tree = dark ? const Color(0xFF0A0A26) : mix(const Color(0xFF06251F), p, .85);

    final frame = Path()
      ..moveTo(12, 210)
      ..lineTo(12, 92)
      ..cubicTo(12, 30, 58, -6, 112, -6)
      ..cubicTo(166, -6, 212, 30, 212, 92)
      ..lineTo(212, 210)
      ..close();
    canvas.drawPath(frame, Paint()..color = m1.withValues(alpha: .55));

    final arch = Path()
      ..moveTo(24, 210)
      ..lineTo(24, 92)
      ..cubicTo(24, 38, 62, 8, 112, 8)
      ..cubicTo(162, 8, 200, 38, 200, 92)
      ..lineTo(200, 210)
      ..close();
    canvas.save();
    canvas.clipPath(arch);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 220, 100), Paint()..color = sky1);
    canvas.drawRect(const Rect.fromLTWH(0, 100, 220, 110), Paint()..color = sky2);
    if (dark) {
      final star = Paint()..color = Colors.white.withValues(alpha: .85);
      canvas.drawCircle(const Offset(60, 40), 1.5, star);
      canvas.drawCircle(const Offset(150, 30), 1.3, star);
      canvas.drawCircle(const Offset(180, 62), 1.5, star);
    }
    canvas.drawCircle(const Offset(140, 96), 22, Paint()..color = sun);
    canvas.drawPath(
      Path()
        ..moveTo(0, 120)
        ..lineTo(40, 80)
        ..lineTo(72, 110)
        ..lineTo(112, 66)
        ..lineTo(156, 112)
        ..lineTo(220, 84)
        ..lineTo(220, 210)
        ..lineTo(0, 210)
        ..close(),
      Paint()..color = m1,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 142)
        ..lineTo(52, 104)
        ..lineTo(100, 136)
        ..lineTo(150, 100)
        ..lineTo(220, 134)
        ..lineTo(220, 210)
        ..lineTo(0, 210)
        ..close(),
      Paint()..color = m2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 168)
        ..quadraticBezierTo(60, 150, 120, 164)
        ..quadraticBezierTo(180, 178, 220, 158)
        ..lineTo(220, 210)
        ..lineTo(0, 210)
        ..close(),
      Paint()..color = m3,
    );
    final trees = Paint()..color = tree;
    void pine(double x, double top, double w, double h) => canvas.drawPath(
      Path()
        ..moveTo(x, top)
        ..lineTo(x - w / 2, top + h)
        ..lineTo(x + w / 2, top + h)
        ..close(),
      trees,
    );
    pine(34, 126, 20, 40);
    pine(58, 140, 16, 30);
    pine(178, 126, 20, 42);
    canvas.restore();

    final leaf = Paint()..color = tree.withValues(alpha: .85);
    canvas.drawPath(
      Path()
        ..moveTo(200, 150)
        ..cubicTo(228, 130, 232, 100, 216, 80)
        ..cubicTo(206, 108, 196, 124, 200, 150)
        ..close(),
      leaf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(212, 178)
        ..cubicTo(236, 164, 240, 140, 228, 126)
        ..cubicTo(222, 146, 210, 158, 212, 178)
        ..close(),
      leaf..color = tree.withValues(alpha: .7),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArchPainter old) =>
      old.colors.palette != colors.palette ||
      old.colors.brightness != colors.brightness;
}


/// "68.40" -> "68.4", "72.00" -> "72"; non-numeric text is returned as is.
String _plainNumber(String raw) {
  final parsed = double.tryParse(raw);
  if (parsed == null) return raw;
  if (parsed == parsed.roundToDouble()) return NumberFormat('#,##0').format(parsed);
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
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(at.year, at.month, at.day))
      .inDays;
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
