import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
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
        final refresh = () => controller.refresh(
              date: now,
              offsetMinutes: now.timeZoneOffset.inMinutes,
            );
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            displayName: name,
                            onSearch: onSearch,
                            onNotifications: onNotifications,
                            onProfile: onProfile,
                          ),
                          const SizedBox(height: 24),
                          _Greeting(name: name, now: now, dashboard: controller.dashboard),
                          const SizedBox(height: 24),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            'Blistra',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        IconButton(
          onPressed: onSearch,
          tooltip: 'Search',
          icon: const Icon(Icons.search),
        ),
        IconButton(
          onPressed: onNotifications,
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_outlined),
        ),
        Semantics(
          label: 'Profile',
          button: true,
          child: InkWell(
            onTap: onProfile,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Text(
                  initialsForName(displayName),
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.now, required this.dashboard});

  final String name;
  final DateTime now;
  final DashboardResponse? dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attention = buildAttentionItems(dashboard, now: now, limit: 1000).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greetingForHour(now.hour)},',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          DateFormat('EEEE, d MMMM').format(now),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (attention > 0) ...[
          const SizedBox(height: 6),
          Text(
            '$attention thing${attention == 1 ? '' : 's'} need${attention == 1 ? 's' : ''} your attention.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final id in homeWidgets)
          if (HomeWidgets.sections.contains(id)) ...[
            _SectionContent(
              id: id,
              dashboard: dashboard,
              now: now,
              onDestination: onDestination,
              onRefresh: onRefresh,
              homeWidgets: homeWidgets,
            ),
            const SizedBox(height: 16),
          ],
        if (!hubPinned)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onDestination?.call('HUB'),
                icon: const Icon(Icons.grid_view_outlined),
                label: const Text('Explore Hub'),
              ),
            ),
          ),
      ],
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
    return _Panel(
      title: 'Today overview',
      child: metrics.availableMetrics.isEmpty
          ? _ErrorState(onRetry: onRefresh, moduleError: true)
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 4 : 2;
                final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: (columns == 2 ? 1.0 : 1.12) / textScale,
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
      title: 'Needs attention',
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
      child: selected.isEmpty
          ? const _EmptyState(message: 'No modules selected.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 2 : 1;
                final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
                return GridView.count(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: (columns == 1 ? 1.7 : 1.55) / textScale,
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
        child: _ErrorState(onRetry: onRefresh, moduleError: true),
      );
    }
    final total = value == null
        ? 0
        : value.tasksDue + value.habitOccurrences;
    if (value == null || total == 0) {
      return const _Panel(
        title: 'This week',
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
      trailing: _SeeAll(onTap: () => onDestination?.call('HABITS/STATS')),
      child: Column(
        children: [
          _WeekStat(
            label: 'Tasks completed',
            value: '${value.completedTasks} of ${value.tasksDue}',
            progress: taskProgress,
          ),
          const SizedBox(height: 12),
          _WeekStat(
            label: 'Habit occurrences',
            value: '${value.habitCompletions} of ${value.habitOccurrences}',
            progress: habitProgress,
          ),
          const SizedBox(height: 12),
          Text(
            '${value.activeDays} active day${value.activeDays == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyMedium,
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
        action: TextButton(onPressed: onRefresh, child: const Text('Retry')),
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
        final item = section.latestMeasurements.isEmpty
            ? null
            : [...section.latestMeasurements]..sort((a, b) {
                final aDate = DateTime.tryParse(a.measuredAt ?? '') ?? DateTime.min;
                final bDate = DateTime.tryParse(b.measuredAt ?? '') ?? DateTime.min;
                return bDate.compareTo(aDate);
              }).first;
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
        return _ModuleValue(
          '${section.mealCount} meal${section.mealCount == 1 ? '' : 's'}',
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(HomeWidgets.label(id),
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (onTap != null) const Icon(Icons.chevron_right),
                ],
              ),
              const Spacer(),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 4),
              Text(detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              if (action != null) ...[
                const SizedBox(height: 8),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({required this.label, required this.value, required this.progress});

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleMedium),
        ]),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const Spacer(),
              Text(label, style: theme.textTheme.bodySmall),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
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
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Semantics(
            label: _timelineStatusLabel(item.status),
            child: Icon(_timelineIcon(item.status), color: theme.colorScheme.primary),
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.meta),
          trailing: Text(item.anytime ? 'Anytime' : DateFormat('h:mm a').format(item.at)),
          onTap: onTap,
        ),
        if (showDivider) const Divider(),
      ],
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
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(item.title),
          subtitle: Text(item.detail),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        if (showDivider) const Divider(),
      ],
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_forward, size: 16),
        label: const Text('See all'),
      );
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
