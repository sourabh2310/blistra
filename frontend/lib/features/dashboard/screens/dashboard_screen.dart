import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
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
        final Future<void> Function() refresh = () => controller.refresh(
              date: now,
              offsetMinutes: now.timeZoneOffset.inMinutes,
            );
        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: _AmbientLeaves()),
              RefreshIndicator(
                onRefresh: refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Header(
                                displayName: name,
                                onSearch: onSearch,
                                onNotifications: onNotifications,
                                onProfile: onProfile,
                                onCalendar: () => onDestination?.call('PLANNER/TODAY'),
                              ),
                              const SizedBox(height: 20),
                              _Greeting(
                                name: name,
                                now: now,
                                dashboard: controller.dashboard,
                              ),
                              const SizedBox(height: 18),
                              if (controller.isLoading && controller.dashboard == null)
                                const _DashboardSkeleton()
                              else if (controller.dashboard == null)
                                _FullError(
                                  message: controller.error ?? 'Home is unavailable right now.',
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
    this.onCalendar,
  });

  final String displayName;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Blistra',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: const Color(0xFF174A3B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const _LeafMark(size: 38),
                ],
              ),
              Text(
                'Everything you need. One app.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF526B64),
                  letterSpacing: .1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _HeaderAction(
          tooltip: 'Search',
          icon: Icons.search_rounded,
          onPressed: onSearch,
        ),
        _HeaderAction(
          tooltip: 'Planner',
          icon: Icons.calendar_today_outlined,
          onPressed: onCalendar,
        ),
        _HeaderAction(
          tooltip: 'Notifications',
          icon: Icons.notifications_none_outlined,
          onPressed: onNotifications,
        ),
        Semantics(
          label: 'Profile',
          button: true,
          child: InkWell(
            onTap: onProfile,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 21,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  initialsForName(displayName),
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
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
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 5),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .72),
            side: const BorderSide(color: Color(0xFFE8E0D7)),
            fixedSize: const Size(42, 42),
          ),
          icon: Icon(icon, color: const Color(0xFF193D37), size: 23),
        ),
      );
}

class _LeafMark extends StatelessWidget {
  const _LeafMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LeafMarkPainter()),
      );
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.now, required this.dashboard});

  final String name;
  final DateTime now;
  final DashboardResponse? dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attention = buildAttentionItems(dashboard, now: now, limit: 1000).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final textWidth = wide ? constraints.maxWidth * .5 : constraints.maxWidth * .61;
        return SizedBox(
          height: wide ? 230 : 218,
          child: Stack(
            children: [
              Positioned(
                right: wide ? 12 : 0,
                top: 0,
                bottom: 0,
                width: wide ? constraints.maxWidth * .48 : constraints.maxWidth * .45,
                child: const ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(110),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: CustomPaint(painter: _LandscapePainter()),
                ),
              ),
              SizedBox(
                width: textWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${greetingForHour(now.hour)},',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'serif',
                        color: const Color(0xFF516B85),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
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
                              color: const Color(0xFF192A4C),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const _SunMark(size: 38),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('EEEE, d MMMM').format(now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'serif',
                        color: const Color(0xFF526B8C),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      attention == 0
                          ? "You're all caught up for today."
                          : 'You have $attention thing${attention == 1 ? '' : 's'} to take care of today.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontFamily: 'serif',
                        height: 1.28,
                        color: const Color(0xFF526B85),
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

class _SunMark extends StatelessWidget {
  const _SunMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _SunMarkPainter()),
      );
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

  @override
  Widget build(BuildContext context) {
    final sections = homeWidgets.where(HomeWidgets.sections.contains).toList();
    final children = <Widget>[];
    for (var index = 0; index < sections.length; index++) {
      final id = sections[index];
      final next = index + 1 < sections.length ? sections[index + 1] : null;
      if (next != null &&
          {id, next}.length == 2 &&
          {id, next}.contains(HomeWidgets.todaysSchedule) &&
          {id, next}.contains(HomeWidgets.needsAttention)) {
        children.add(LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 360
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: id == HomeWidgets.todaysSchedule ? 3 : 2,
                      child: _SectionContent(
                        id: id,
                        dashboard: dashboard,
                        now: now,
                        onDestination: onDestination,
                        onRefresh: onRefresh,
                        homeWidgets: homeWidgets,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: next == HomeWidgets.todaysSchedule ? 3 : 2,
                      child: _SectionContent(
                        id: next,
                        dashboard: dashboard,
                        now: now,
                        onDestination: onDestination,
                        onRefresh: onRefresh,
                        homeWidgets: homeWidgets,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _SectionContent(
                      id: id,
                      dashboard: dashboard,
                      now: now,
                      onDestination: onDestination,
                      onRefresh: onRefresh,
                      homeWidgets: homeWidgets,
                    ),
                    const SizedBox(height: 12),
                    _SectionContent(
                      id: next,
                      dashboard: dashboard,
                      now: now,
                      onDestination: onDestination,
                      onRefresh: onRefresh,
                      homeWidgets: homeWidgets,
                    ),
                  ],
                ),
        ));
        children.add(const SizedBox(height: 12));
        index++;
      } else {
        children.add(_SectionContent(
          id: id,
          dashboard: dashboard,
          now: now,
          onDestination: onDestination,
          onRefresh: onRefresh,
          homeWidgets: homeWidgets,
        ));
        children.add(const SizedBox(height: 12));
      }
    }
    if (!hubPinned)
      children.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => onDestination?.call('HUB'),
          icon: const Icon(Icons.grid_view_outlined),
          label: const Text('Explore Hub'),
        ),
      ));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
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
    return Column(
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
              final columns = constraints.maxWidth >= 350 ? 4 : 2;
              final textScale =
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
              return GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio:
                    (columns == 4 ? .72 : 1.05) / textScale,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final metric in metrics.availableMetrics)
                    _MetricCard(
                      label: metric.label,
                      value: metric.value,
                      detail: metric.detail,
                      icon: metric.icon,
                      onTap: () => onDestination?.call(metric.destination),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule({
    required this.dashboard,
    required this.now,
    required this.onDestination,
  });

  final DashboardResponse dashboard;
  final DateTime now;
  final void Function(String destinationId)? onDestination;

  @override
  Widget build(BuildContext context) {
    final items = buildTimeline(dashboard, now: now, limit: 5);
    return _Panel(
      title: "Today's schedule",
      icon: Icons.calendar_today_outlined,
      trailing: _SeeAll(onTap: () => onDestination?.call('PLANNER/TODAY')),
      child: items.isEmpty
          ? const _EmptyState(message: 'Your day is clear.')
          : Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _ScheduleRow(
                    item: items[i],
                    showDivider: i != items.length - 1,
                    onTap: () => onDestination?.call(items[i].destination),
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
    final items = buildAttentionItems(dashboard, now: now, limit: 3);
    return _Panel(
      title: 'Needs your attention',
      icon: Icons.notifications_active_outlined,
      child: items.isEmpty
          ? const _EmptyState(message: "You're caught up for now.")
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

  List<String> get modules => [
        for (final id in homeWidgets)
          if (HomeWidgets.modules.contains(id)) id,
      ];

  @override
  Widget build(BuildContext context) {
    final selected = modules;
    return _Panel(
      title: 'Your life',
      icon: Icons.auto_awesome_mosaic_outlined,
      child: selected.isEmpty
          ? const _EmptyState(message: 'No modules selected.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 650
                    ? 5
                    : constraints.maxWidth >= 350
                        ? 3
                        : 1;
                final textScale =
                    MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio:
                      (columns == 1 ? 1.7 : columns == 3 ? .95 : 1.35) /
                          textScale,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final id in selected)
                      _ModuleCard(
                        id: id,
                        dashboard: dashboard,
                        onDestination: onDestination,
                        onRefresh: onRefresh,
                      ),
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
        : (value.completedTasks / value.tasksDue)
            .clamp(0.0, 1.0)
            .toDouble();
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
        onTap: () => onDestination?.call('HABITS/STATS'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth < 310 ? 88.0 : 112.0;
          return Row(
            children: [
              SizedBox(
                height: 104,
                width: chartWidth,
                child: CustomPaint(
                   painter: _WeekProgressPainter(
                     habitProgress: habitProgress,
                     taskProgress: taskProgress,
                     textDirection: Directionality.of(context),
                   ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WeekDetails(
                  habitProgress: habitProgress,
                  taskProgress: taskProgress,
                  activeDays: value.activeDays,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _WeekDetail(
          value: '${(habitProgress * 100).round()}%',
          label: 'Habits completed',
        ),
        Container(width: 1, height: 46, color: const Color(0xFFE6E5E3)),
        _WeekDetail(
          value: '${(taskProgress * 100).round()}%',
          label: 'Tasks completed',
        ),
        Container(width: 1, height: 46, color: const Color(0xFFE6E5E3)),
        _WeekDetail(
          value: '$activeDays / 7',
          label: 'Days active',
        ),
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
    if (value.error) {
      return _ModuleCardShell(
        id: id,
        icon: _moduleIcon(id),
        value: 'Unavailable',
        detail: 'Could not load this module.',
        action: IconButton(
          onPressed: onRefresh,
          tooltip: 'Retry',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 24, height: 24),
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
          final aDate = DateTime.tryParse(a.measuredAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(b.measuredAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        final item = measurements.isEmpty ? null : measurements.first;
        return _ModuleValue(
          item?.value ?? 'No readings',
          item == null
              ? 'No health readings'
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
  const _ModuleValue(this.value, this.detail, {this.error = false});
  const _ModuleValue.error() : this('Unavailable', '', error: true);

  final String value;
  final String detail;
  final bool error;
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
    return Card(
      color: style.background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: style.iconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: style.foreground, size: 20),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      HomeWidgets.label(id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Padding(
                      padding: EdgeInsets.only(left: 1),
                      child: Icon(Icons.chevron_right, size: 16),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 4),
                action!,
              ],
            ],
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
    return Card(
      color: Colors.white.withValues(alpha: .94),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFF0EAE3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 21, color: const Color(0xFF174A3B)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF20375E),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _metricStyle(label, theme.colorScheme);
    return Card(
      color: style.background,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: style.iconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: style.foreground),
                  ),
                  const Icon(Icons.chevron_right, size: 19),
                ],
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'serif',
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'serif',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item, required this.onTap, this.showDivider = true});

  final TimelineItem item;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _timelineColor(item.status, theme.colorScheme);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 54,
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
                  color: const Color(0xFF60769A),
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
                      child: Container(width: 1, color: const Color(0xFFD8E1DF)),
                    ),
                  Semantics(
                    label: _timelineStatusLabel(item.status),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _timelineIcon(item.status),
              size: 19,
              color: statusColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onTap, this.showDivider = true});

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
                child: Icon(_attentionIcon(item.detail), size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      item.detail,
                      maxLines: 1,
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
              moduleError ? 'Some Home data could not be loaded.' : 'Try again to load Home.',
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
              Text('Home is unavailable', style: Theme.of(context).textTheme.titleMedium),
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

class _AmbientLeaves extends StatelessWidget {
  const _AmbientLeaves();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _AmbientPainter());
}

class _LeafMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF4F8A57)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .28, size.height * .9),
      Offset(size.width * .78, size.height * .25),
      stem,
    );
    final left = Path()
      ..moveTo(size.width * .38, size.height * .7)
      ..quadraticBezierTo(.05 * size.width, .72 * size.height, .1 * size.width, .36 * size.height)
      ..quadraticBezierTo(.42 * size.width, .35 * size.height, .38 * size.height, .7 * size.height);
    final right = Path()
      ..moveTo(size.width * .58, size.height * .46)
      ..quadraticBezierTo(.54 * size.width, .08 * size.height, .88 * size.width, .04 * size.height)
      ..quadraticBezierTo(.94 * size.width, .34 * size.height, .58 * size.height, .46 * size.height);
    canvas.drawPath(left, Paint()..color = const Color(0xFF7DB787));
    canvas.drawPath(right, Paint()..color = const Color(0xFF4D9861));
    canvas.drawLine(
      Offset(size.width * .17, size.height * .42),
      Offset(size.width * .37, size.height * .66),
      stem..strokeWidth = 1.2,
    );
    canvas.drawLine(
      Offset(size.width * .83, size.height * .12),
      Offset(size.width * .61, size.height * .43),
      stem..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SunMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .54);
    final ray = Paint()
      ..color = const Color(0xFFFFB62E)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, size.width * .24, Paint()..color = const Color(0xFFFFBD35));
    for (var index = 0; index < 8; index++) {
      final angle = index * 3.1415926535 / 4;
      final start = Offset(
        center.dx + (size.width * .32) * math.cos(angle),
        center.dy + (size.width * .32) * math.sin(angle),
      );
      final end = Offset(
        center.dx + (size.width * .42) * math.cos(angle),
        center.dy + (size.width * .42) * math.sin(angle),
      );
      canvas.drawLine(start, end, ray);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LandscapePainter extends CustomPainter {
  const _LandscapePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDEFF0), Color(0xFFFFF2D8)],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(size.width * .72, size.height * .42),
      size.width * .2,
      Paint()..color = const Color(0xFFF6B766).withValues(alpha: .42),
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
    canvas.drawPath(far, Paint()..color = const Color(0xFF8EB7C4));
    final near = Path()
      ..moveTo(0, size.height * .64)
      ..lineTo(size.width * .28, size.height * .45)
      ..lineTo(size.width * .5, size.height * .66)
      ..lineTo(size.width * .74, size.height * .47)
      ..lineTo(size.width, size.height * .64)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF4F8090));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .64, size.width, size.height * .36),
      Paint()..color = const Color(0xFF78B4C2),
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
    final treePaint = Paint()..color = const Color(0xFF245E4B);
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
      Rect.fromLTWH(size.width * .56, size.height * .84, size.width * .6, size.height * .12),
      const Radius.circular(12),
    );
    canvas.drawRRect(table, Paint()..color = const Color(0xFF9B6444));
    canvas.drawRect(
      Rect.fromLTWH(size.width * .82, size.height * .9, 4, size.height * .1),
      Paint()..color = const Color(0xFF70462F),
    );
    final cup = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .75, size.height * .72, size.width * .17, size.height * .15),
      const Radius.circular(8),
    );
    canvas.drawRRect(cup, Paint()..color = const Color(0xFFD7A778));
    canvas.drawArc(
      Rect.fromLTWH(size.width * .86, size.height * .74, size.width * .12, size.height * .1),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4F8A57).withValues(alpha: .06);
    void leaf(Offset origin, double length, double angle, Paint color) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angle);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(length * .45, -length * .4, length, 0)
          ..quadraticBezierTo(length * .5, length * .4, 0, 0),
        color,
      );
      canvas.restore();
    }

    final top = size.height * .13;
    leaf(Offset(size.width - 5, top), 52, -1.2, paint);
    leaf(Offset(size.width - 26, top + 45), 42, -.7, paint);
    leaf(Offset(size.width - 58, top + 14), 38, -1.6, paint);
    leaf(Offset(size.width - 18, top + 91), 36, -.4, paint);
    leaf(Offset(0, size.height * .72), 64, .35, paint);
    leaf(Offset(18, size.height * .81), 48, .65, paint);
    leaf(Offset(size.width - 8, size.height * .88), 52, -1.8, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeekProgressPainter extends CustomPainter {
  const _WeekProgressPainter({
    required this.habitProgress,
    required this.taskProgress,
    required this.textDirection,
  });

  final double habitProgress;
  final double taskProgress;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .3, size.height * .5);
    final radius = (size.height * .31).clamp(18.0, 34.0).toDouble();
    final track = Paint()
      ..color = const Color(0xFFE5ECE8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final habit = Paint()
      ..color = const Color(0xFF8AC5A3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final tasks = Paint()
      ..color = const Color(0xFF0B6B4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final outer = Rect.fromCircle(center: center, radius: radius);
    final inner = Rect.fromCircle(center: center, radius: radius - 11);
    canvas.drawArc(outer, -1.6, 4.9, false, habit);
    canvas.drawArc(
      outer,
      -1.6,
      4.9 * habitProgress.clamp(0.0, 1.0).toDouble(),
      false,
      tasks,
    );
    canvas.drawArc(inner, -1.6, 4.9, false, track);
    canvas.drawArc(
      inner,
      -1.6,
      4.9 * habitProgress.clamp(0.0, 1.0).toDouble(),
      false,
      habit,
    );
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final labelStyle = const TextStyle(
      color: Color(0xFF5A6D69),
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );
    for (var index = 0; index < labels.length; index++) {
      final x = size.width * .62 + (index % 2) * 15;
      final y = size.height * .12 + (index ~/ 2) * 27;
      final painter = TextPainter(
        text: TextSpan(text: labels[index], style: labelStyle),
        textDirection: textDirection,
      )..layout();
      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _WeekProgressPainter oldDelegate) =>
      habitProgress != oldDelegate.habitProgress ||
      taskProgress != oldDelegate.taskProgress;
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

Color _timelineColor(TimelineStatus status, ColorScheme scheme) => switch (status) {
      TimelineStatus.completed => const Color(0xFF18A768),
      TimelineStatus.overdue || TimelineStatus.missed => const Color(0xFFE24545),
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

class TimelineItem {
  TimelineItem({
    required this.at,
    required this.title,
    required this.meta,
    required this.status,
    required this.destination,
    this.anytime = false,
  });

  final DateTime at;
  final String title;
  final String meta;
  final TimelineStatus status;
  final String destination;
  final bool anytime;

  bool get done => status == TimelineStatus.completed;
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
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final String destination;
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
    final remaining = [...planner.todayTasks, ...planner.overdueTasks]
        .where((task) {
          final status = (task.status ?? '').toUpperCase();
          return status != 'COMPLETED' && status != 'CANCELLED';
        }).length;
    metrics.add(HomeMetric(
      label: 'Tasks remaining',
      value: '$remaining',
      detail: 'Today',
      icon: Icons.checklist,
      destination: 'PLANNER/TODAY',
    ));
  }
  final medicines = dashboard.medicines;
  if (medicines != null && !medicines.unavailable) {
    final expected = medicines.dosesToday.length;
    final taken = medicines.dosesToday.where(_isTaken).length;
    metrics.add(HomeMetric(
      label: 'Medicines',
      value: '$taken of $expected',
      detail: 'Taken today',
      icon: Icons.medication_outlined,
      destination: 'MEDICINES',
    ));
  }
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    metrics.add(HomeMetric(
      label: 'Habits',
      value: '${habits.completedToday} of ${habits.expectedToday}',
      detail: 'Done today',
      icon: Icons.repeat,
      destination: 'HABITS',
    ));
  }
  final finance = dashboard.finance;
  if (finance != null && !finance.unavailable && finance.today != null) {
    final currencies = finance.today!.currencies;
    if (currencies.isEmpty) {
      metrics.add(HomeMetric(
        label: 'Spending today',
        value: 'No spending',
        detail: 'No activity today',
        icon: Icons.account_balance_wallet_outlined,
        destination: 'FINANCE',
      ));
    } else {
      final expense = currencies.length == 1
        ? currencies.first.expense
        : null;
    metrics.add(HomeMetric(
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
    ));
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
      if (task.id.isEmpty || status == 'COMPLETED' || status == 'CANCELLED' || at == null || !at.isBefore(current)) {
        continue;
      }
      result.add(AttentionItem(
        title: task.title,
        detail: 'Task is overdue',
        destination: 'PLANNER/TASK/${task.id}',
      ));
    }
  }
  final medicines = dashboard.medicines;
  if (medicines != null && !medicines.unavailable) {
    for (final dose in medicines.dosesToday) {
      final status = dose.status.toUpperCase();
      final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
      if (dose.medicineId.isEmpty || _isTaken(dose) || status == 'CANCELLED' || status == 'SKIPPED' || at == null) {
        continue;
      }
      final isAttention = status == 'PENDING' || status == 'MISSED' ||
          at.isBefore(current);
      if (!isAttention) {
        continue;
      }
      result.add(AttentionItem(
        title: dose.medicineName,
        detail: status == 'MISSED'
            ? 'Medicine dose was missed'
            : 'Medicine dose is still pending',
        destination: 'MEDICINES/${dose.medicineId}',
      ));
    }
  }
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    final incomplete = habits.todayHabits.where((habit) => !habit.completedToday).toList();
    if (incomplete.isNotEmpty) {
      for (final habit in incomplete) {
        if (habit.id.isEmpty) continue;
        result.add(AttentionItem(
          title: habit.name,
          detail: 'Habit is still due today',
          destination: 'HABITS/${habit.id}',
        ));
      }
    } else if (habits.expectedToday > habits.completedToday) {
      result.add(AttentionItem(
        title: 'Incomplete habits',
        detail: '${habits.expectedToday - habits.completedToday} due today',
        destination: 'HABITS',
      ));
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
      items.add(TimelineItem(
        at: start,
        title: event.title,
        meta: 'Event · ${_time(start)}${end == null ? '' : ' – ${_time(end)}'}',
        status: _eventStatus(start, end, now),
        destination: 'PLANNER/EVENT/${event.id}',
      ));
    }
    for (final task in [...planner.todayTasks, ...planner.overdueTasks]) {
      final status = (task.status ?? '').toUpperCase();
      if (status == 'CANCELLED') continue;
      final at = DateTime.tryParse(task.dueAt ?? task.startAt ?? '')?.toLocal();
      if (at == null || task.id.isEmpty) continue;
      items.add(TimelineItem(
        at: at,
        title: task.title,
        meta: 'Task · ${_time(at)}',
        status: status == 'COMPLETED'
            ? TimelineStatus.completed
            : at.isBefore(now)
                ? TimelineStatus.overdue
                : TimelineStatus.upcoming,
        destination: 'PLANNER/TASK/${task.id}',
      ));
    }
  }
  final medicines = dashboard.medicines;
  if (medicines != null && !medicines.unavailable) {
    for (final dose in medicines.dosesToday) {
      final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
      if (at == null || dose.medicineId.isEmpty) continue;
      final status = dose.status.toUpperCase();
      items.add(TimelineItem(
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
      ));
    }
  }
  final diet = dashboard.diet;
  if (diet != null && !diet.unavailable) {
    for (final meal in diet.meals) {
      final at = DateTime.tryParse(meal.consumedAt ?? '')?.toLocal();
      if (at == null || meal.id.isEmpty) continue;
      items.add(TimelineItem(
        at: at,
        title: _mealTitle(meal.type),
        meta: 'Diet · ${_time(at)}',
        status: TimelineStatus.completed,
        destination: 'DIET/MEAL/${meal.id}',
      ));
    }
  }
  final health = dashboard.health;
  if (health != null && !health.unavailable) {
    for (final appointment in health.upcomingAppointments) {
      final at = DateTime.tryParse(appointment.scheduledAt)?.toLocal();
      if (at == null || !_sameDay(at, now)) continue;
      final status = (appointment.status ?? '').toUpperCase();
      items.add(TimelineItem(
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
      ));
    }
  }
  final habits = dashboard.habits;
  if (habits != null && !habits.unavailable) {
    for (final habit in habits.todayHabits.where((habit) => !habit.completedToday && habit.id.isNotEmpty)) {
      final anchor = DateTime(now.year, now.month, now.day);
      items.add(TimelineItem(
        at: anchor,
        title: habit.name,
        meta: 'Habit · Any time today',
        status: TimelineStatus.upcoming,
        destination: 'HABITS/${habit.id}',
        anytime: true,
      ));
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

String _mealTitle(String? value) {
  if (value == null || value.isEmpty) return 'Meal';
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _timelineStatusLabel(TimelineStatus status) => switch (status) {
      TimelineStatus.upcoming => 'Upcoming',
      TimelineStatus.due => 'Due',
      TimelineStatus.completed => 'Completed',
      TimelineStatus.missed => 'Missed',
      TimelineStatus.overdue => 'Overdue',
      TimelineStatus.cancelled => 'Cancelled',
    };

TimelineStatus _eventStatus(DateTime start, DateTime? end, DateTime now) {
  if ((end ?? start).isBefore(now)) return TimelineStatus.completed;
  if (!start.isAfter(now)) return TimelineStatus.due;
  return TimelineStatus.upcoming;
}
