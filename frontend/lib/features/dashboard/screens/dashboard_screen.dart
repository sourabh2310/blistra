import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
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
                                  const SizedBox(height: 20),
                                  _Greeting(
                                    name: name,
                                    now: now,
                                    dashboard: controller.dashboard,
                                  ),
                                  const SizedBox(height: 18),
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
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BlistraMark(size: 30),
                        const SizedBox(width: 8),
                        Text(
                          'Blistra',
                          maxLines: 1,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            color: BlistraColors.resolve(context).text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (constraints.maxWidth >= 360)
                  Text(
                    'Everything you need. One app.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BlistraColors.resolve(context).muted,
                      letterSpacing: .1,
                    ),
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
          _NotificationAction(onPressed: onNotifications),
          Semantics(
            label: 'Profile',
            button: true,
            child: InkWell(
              onTap: onProfile,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: BlistraColors.resolve(context).accent,
                  child: Text(
                    initialsForName(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: BlistraColors.resolve(context).glassFill,
        side: const BorderSide(color: Color(0xFFE8E0D7)),
        fixedSize: const Size(44, 44),
      ),
      icon: Icon(icon, color: BlistraColors.resolve(context).text, size: 22),
    ),
  );
}

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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onPressed,
            tooltip: 'Notifications',
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: BlistraColors.resolve(context).glassFill,
              side: const BorderSide(color: Color(0xFFE8E0D7)),
              fixedSize: const Size(44, 44),
            ),
            icon: Icon(
              Icons.notifications_none_outlined,
              color: BlistraColors.resolve(context).text,
              size: 22,
            ),
          ),
          if (hasActive)
            Positioned(
              right: 9,
              top: 9,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE24545),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
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
    final theme = Theme.of(context);
    final attention = buildAttentionItems(
      dashboard,
      now: now,
      limit: 1000,
    ).length;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greetingForHour(now.hour)},',
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'serif',
            color: BlistraColors.resolve(context).muted,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                  color: BlistraColors.resolve(context).text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _dayPartIcon(now.hour),
              size: 30,
              color: const Color(0xFFF0A63C),
              semanticLabel: greetingForHour(now.hour),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          DateFormat('EEEE, d MMMM').format(now),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'serif',
            color: BlistraColors.resolve(context).muted,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          attention == 0
              ? "You're all caught up for today."
              : 'You have $attention thing${attention == 1 ? '' : 's'} to take care of today.',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontFamily: 'serif',
            height: 1.28,
            color: BlistraColors.resolve(context).muted,
          ),
        ),
      ],
    );
    final art = ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: CustomPaint(
        painter: _LandscapePainter(BlistraColors.resolve(context)),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 340;
        if (sideBySide) {
          return GlassCard(
            padding: const EdgeInsets.all(18),
            radius: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: text),
                const SizedBox(width: 14),
                SizedBox(width: 132, height: 190, child: art),
              ],
            ),
          );
        }
        return GlassCard(
          padding: const EdgeInsets.all(18),
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              const SizedBox(height: 14),
              SizedBox(height: 92, width: double.infinity, child: art),
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

  Widget _section(String id) => _SectionContent(
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
        final wide = constraints.maxWidth >= 700;
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
                  Expanded(child: _section(first)),
                  const SizedBox(width: 12),
                  Expanded(child: _section(second)),
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
    required this.id,
    required this.dashboard,
    required this.now,
    required this.onDestination,
    required this.onRefresh,
    required this.homeWidgets,
  });

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
    ),
    HomeWidgets.needsAttention => _NeedsAttention(
      dashboard: dashboard,
      now: now,
      onDestination: onDestination,
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
                if (constraints.maxWidth >= 520) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0;
                          i < metrics.availableMetrics.length;
                          i++) ...[
                        if (i > 0) const SizedBox(width: spacing),
                        Expanded(child: card(i)),
                      ],
                    ],
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
  });

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
  });

  final DashboardResponse dashboard;
  final DateTime now;
  final void Function(String destinationId)? onDestination;

  @override
  Widget build(BuildContext context) {
    final items = buildAttentionItems(dashboard, now: now, limit: 4);
    return _Panel(
      title: 'Needs your attention',
      icon: Icons.notifications_active_outlined,
      trailing: _SeeAll(
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F7EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF0B6B4F),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're on track!",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No urgent items right now.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
          if (constraints.maxWidth >= 520) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: card(selected[0])),
                const SizedBox(width: spacing),
                Expanded(child: card(selected[1])),
              ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monday → Sunday bars visualise the same real aggregates used
          // below (task/habit progress + active days). The backend exposes
          // only week aggregates — never per-day completions — so bars show
          // aggregate activity per active day, never invented daily values.
          // Day letters/dates come from the real week [start].
          _WeekBars(
            start: value.start,
            activeDays: value.activeDays,
            taskProgress: taskProgress,
            habitProgress: habitProgress,
          ),
          const SizedBox(height: 6),
          _WeekDayStrip(start: value.start),
          const SizedBox(height: 10),
          _WeekDetails(
            habitProgress: habitProgress,
            taskProgress: taskProgress,
            activeDays: value.activeDays,
          ),
        ],
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
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _WeekBar(
                  isActive: i < filled,
                  isToday:
                      isThisWeek &&
                      monday.add(Duration(days: i)).day == today.day &&
                      monday.add(Duration(days: i)).month == today.month,
                  height: (i < filled ? 22 + 46 * overall : 10.0).toDouble(),
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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _WeekDetail(
          value: '${(habitProgress * 100).round()}%',
          label: 'Habits completed',
        ),
        Container(width: 1, height: 46, color: BlistraColors.resolve(context).glassBorder),
        _WeekDetail(
          value: '${(taskProgress * 100).round()}%',
          label: 'Tasks completed',
        ),
        Container(width: 1, height: 46, color: BlistraColors.resolve(context).glassBorder),
        _WeekDetail(value: '$activeDays / 7', label: 'Days active'),
      ],
    );
  }
}

class _WeekDetail extends StatelessWidget {
  const _WeekDetail({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'serif',
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
        final item = measurements.isEmpty ? null : measurements.first;
        return _ModuleValue(
          item?.value ?? 'No recent measurement',
          item == null
              ? 'No recent measurement'
              : '${item.type.replaceAll('_', ' ')}${item.unit == null || item.unit!.isEmpty ? '' : ' · ${item.unit}'}',
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
              : '$calories kcal',
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
            expense.isEmpty ? 'No spending' : expense,
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
    final theme = Theme.of(context);
    final style = _moduleStyle(id, theme.colorScheme);
    // Reference mini-card: circular icon left, title + live metric +
    // supporting text stacked in the middle, chevron right.
    return Semantics(
      label: '${HomeWidgets.label(id)}: $value $detail',
      button: onTap != null,
      child: Card(
        color: _tinted(context, style.foreground),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.foreground.withValues(alpha: .2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _iconFg(context, style.foreground), size: 24),
                ),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: BlistraColors.resolve(context).text,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w800,
                          color: BlistraColors.resolve(context).text,
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: BlistraColors.resolve(context).muted,
                        ),
                      ),
                      if (action != null) action!,
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: .7,
                    ),
                  ),
              ],
            ),
          ),
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
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 21, color: BlistraColors.resolve(context).text),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w800,
                      color: BlistraColors.resolve(context).text,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
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
    final theme = Theme.of(context);
    final style = _metricStyle(label, theme.colorScheme);
    return Semantics(
      label: '$semanticLabel: $value $detail',
      button: true,
      child: Card(
        color: _tinted(context, style.foreground),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.foreground.withValues(alpha: .2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 22, color: _iconFg(context, style.foreground)),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: .7,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w800,
                    color: BlistraColors.resolve(context).text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.2,
                    color: BlistraColors.resolve(context).muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    final theme = Theme.of(context);
    final statusColor = _timelineColor(item.status, theme.colorScheme);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                item.anytime ? 'Anytime' : DateFormat('h:mm a').format(item.at),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'serif',
                  color: BlistraColors.resolve(context).muted,
                ),
              ),
            ),
            SizedBox(
              width: 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showDivider)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: BlistraColors.resolve(context).glassBorder,
                      ),
                    ),
                  Semantics(
                    label: _timelineStatusLabel(item.status),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _categoryColor(item.meta).withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _categoryIcon(item.meta),
                      size: 16,
                      color: _categoryColor(item.meta),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final completed = item.status == TimelineStatus.completed;
    if (onCompleteTask != null && item.source == HomeSource.task) {
      return IconButton(
        onPressed: onCompleteTask,
        tooltip: completed ? 'Reopen task' : 'Complete task',
        visualDensity: VisualDensity.compact,
        icon: Icon(
          completed ? Icons.undo_rounded : Icons.check_circle_outline,
          size: 22,
          color: completed ? statusColor : const Color(0xFF18A768),
        ),
      );
    }
    if (onCompleteHabit != null && item.source == HomeSource.habit) {
      return IconButton(
        onPressed: onCompleteHabit,
        tooltip: 'Mark habit complete',
        visualDensity: VisualDensity.compact,
        icon: const Icon(
          Icons.check_circle_outline,
          size: 22,
          color: Color(0xFF18A768),
        ),
      );
    }
    if (item.source == HomeSource.medicine && item.actionable) {
      final due = !item.at.isAfter(DateTime.now());
      if (!due) {
        return Icon(
          Icons.notifications_none,
          size: 19,
          color: statusColor,
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onTakeDose,
            tooltip: 'Take dose',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.check_circle_outline,
              size: 22,
              color: Color(0xFF18A768),
            ),
          ),
          IconButton(
            onPressed: onSkipDose,
            tooltip: 'Skip dose',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: Color(0xFFE08A22),
            ),
          ),
        ],
      );
    }
    return Icon(_timelineIcon(item.status), size: 19, color: statusColor);
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
    final theme = Theme.of(context);
    final color = _attentionColor(item.detail);
    return Padding(
      padding: EdgeInsets.only(bottom: showDivider ? 7 : 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _attentionIcon(item.detail),
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      item.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
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
    if (MediaQuery.sizeOf(context).width < 520) {
      return IconButton(
        onPressed: onTap,
        tooltip: label,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.arrow_forward, size: 19),
      );
    }
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: Text(label),
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

class _LandscapePainter extends CustomPainter {
  const _LandscapePainter(this.colors);

  /// Scene colours follow the accent palette and light/dark mode.
  final BlistraColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final p = colors.accent;
    final p2 = colors.accent2;
    final dark = colors.isDark;
    final skyTop = dark
        ? Color.lerp(const Color(0xFF12113A), p, .28)!
        : Color.lerp(const Color(0xFFFFF0D8), p2, .32)!;
    final skyBottom = dark
        ? Color.lerp(const Color(0xFF2A1848), p2, .6)!
        : Color.lerp(const Color(0xFFEAF6F2), p, .28)!;
    final farColor = dark
        ? Color.lerp(const Color(0xFF1D1B4A), p, .4)!
        : Color.lerp(const Color(0xFFDBE9EC), p, .4)!;
    final nearColor = dark
        ? Color.lerp(const Color(0xFF13113A), p, .28)!
        : Color.lerp(const Color(0xFFBCD6D6), p, .62)!;
    final waterColor = dark
        ? Color.lerp(const Color(0xFF0A0A26), p, .2)!
        : Color.lerp(const Color(0xFFBCD6D6), p, .45)!;
    final treeColor = dark
        ? const Color(0xFF0A0A26)
        : Color.lerp(const Color(0xFF06251F), p, .8)!;
    final sunColor = dark ? const Color(0xFFFFD9A0) : const Color(0xFFFFF4CC);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skyTop, skyBottom],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .72, size.height * .42),
      size.width * .2,
      Paint()..color = sunColor.withValues(alpha: dark ? .95 : .85),
    );
    final far = Path()
      ..moveTo(0, size.height * .58)
      ..lineTo(size.width * .24, size.height * .28)
      ..lineTo(size.width * .48, size.height * .56)
      ..lineTo(size.width * .7, size.height * .32)
      ..lineTo(size.width, size.height * .58)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(far, Paint()..color = farColor);
    final near = Path()
      ..moveTo(0, size.height * .64)
      ..lineTo(size.width * .28, size.height * .45)
      ..lineTo(size.width * .5, size.height * .66)
      ..lineTo(size.width * .74, size.height * .47)
      ..lineTo(size.width, size.height * .64)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, Paint()..color = nearColor);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .64, size.width, size.height * .36),
      Paint()..color = waterColor,
    );
    for (var index = 0; index < 4; index++) {
      final y = size.height * (.7 + index * .055);
      canvas.drawLine(
        Offset(size.width * .12, y),
        Offset(size.width * (.45 + index * .1), y),
        Paint()
          ..color = Colors.white.withValues(alpha: .28)
          ..strokeWidth = 1.2,
      );
    }
    final treePaint = Paint()..color = treeColor;
    for (final point in const [
      Offset(.08, .75),
      Offset(.17, .79),
      Offset(.26, .75),
      Offset(.34, .82),
    ]) {
      final x = point.dx * size.width;
      final base = point.dy * size.height;
      final height = size.height * .22;
      canvas.drawRect(
        Rect.fromLTWH(x - 1.5, base - height * .65, 3, height * .65),
        Paint()..color = const Color(0xFF6D5737),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, base - height)
          ..lineTo(x - 7, base - height * .25)
          ..lineTo(x + 7, base - height * .25)
          ..close(),
        treePaint,
      );
    }
    final table = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .56,
        size.height * .84,
        size.width * .6,
        size.height * .12,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(table, Paint()..color = const Color(0xFF9B6444));
    canvas.drawRect(
      Rect.fromLTWH(size.width * .82, size.height * .9, 4, size.height * .1),
      Paint()..color = const Color(0xFF70462F),
    );
    final cup = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .75,
        size.height * .72,
        size.width * .17,
        size.height * .15,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(cup, Paint()..color = const Color(0xFFD7A778));
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * .86,
        size.height * .74,
        size.width * .12,
        size.height * .1,
      ),
      -1.4,
      2.8,
      false,
      Paint()
        ..color = const Color(0xFF876044)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _LandscapePainter oldDelegate) =>
      oldDelegate.colors.palette != colors.palette ||
      oldDelegate.colors.brightness != colors.brightness;
}

/// Module icon colour: lightened in dark mode so it stays readable on glass.
Color _iconFg(BuildContext context, Color module) =>
    BlistraColors.resolve(context).isDark
        ? Color.lerp(module, Colors.white, .4)!
        : module;

/// Module tint over the glass surface: pastel in light, deeper in dark.
Color _tinted(BuildContext context, Color module) {
  final colors = BlistraColors.resolve(context);
  return Color.alphaBlend(
    module.withValues(alpha: colors.isDark ? .18 : .12),
    colors.glassFill,
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
      foreground: Color(0xFF07836A),
    );
  }
  if (label.contains('Medicines')) {
    return const _FeatureStyle(
      background: Color(0xFFEFF5FF),
      iconBackground: Color(0xFFDDE9FF),
      foreground: Color(0xFF2878EA),
    );
  }
  if (label.contains('Habits')) {
    return const _FeatureStyle(
      background: Color(0xFFFFF3E8),
      iconBackground: Color(0xFFFFE3C6),
      foreground: Color(0xFFE66A2C),
    );
  }
  return _FeatureStyle(
    background: scheme.brightness == Brightness.dark
        ? const Color(0xFF302746)
        : const Color(0xFFF4EAFE),
    iconBackground: scheme.brightness == Brightness.dark
        ? const Color(0xFF493560)
        : const Color(0xFFE9D7FC),
    foreground: const Color(0xFF8B35D1),
  );
}

_FeatureStyle _moduleStyle(String id, ColorScheme scheme) => switch (id) {
  HomeWidgets.health => const _FeatureStyle(
    background: Color(0xFFFFEEEE),
    iconBackground: Color(0xFFFFD7D7),
    foreground: Color(0xFFEF3E4D),
  ),
  HomeWidgets.medicines => const _FeatureStyle(
    background: Color(0xFFEFF5FF),
    iconBackground: Color(0xFFDDE9FF),
    foreground: Color(0xFF2878EA),
  ),
  HomeWidgets.diet => const _FeatureStyle(
    background: Color(0xFFFFF3E8),
    iconBackground: Color(0xFFFFE3C6),
    foreground: Color(0xFFE66A2C),
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
    final remaining = [...planner.todayTasks, ...planner.overdueTasks].where((
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
              : expense,
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
    for (final task in [...planner.overdueTasks, ...planner.todayTasks]) {
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
    for (final task in [...planner.todayTasks, ...planner.overdueTasks]) {
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
  return '${value[0].toUpperCase()}${value.substring(1)}';
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
