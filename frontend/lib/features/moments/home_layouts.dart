/// Additional Home tab layouts beyond Classic, EasyReach and Large.
///
/// Each widget reads the same [DashboardResponse] that the existing layouts
/// use and renders it in a distinct visual style. All accept the same three
/// callbacks as the existing home screens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../core/theme/accent_palette.dart' show ModuleColors;
import '../../core/theme/app_theme.dart';
import '../dashboard/models/dashboard_response.dart';
import '../dashboard/screens/dashboard_screen.dart'
    show HomeSource, TimelineItem, buildTimeline;
import '../preferences/shell_destinations.dart';
import 'moments_data.dart';

// ─── Shared helpers ──────────────────────────────────────────────────────────

const _modules = [
  (ShellDestinations.planner, 'Planner', Icons.event_note_rounded,
      ModuleColors.planner),
  (ShellDestinations.medicines, 'Meds', Icons.medication_rounded,
      ModuleColors.medicines),
  (ShellDestinations.habits, 'Habits', Icons.check_circle_outline_rounded,
      ModuleColors.habits),
  (ShellDestinations.diet, 'Diet', Icons.restaurant_rounded, ModuleColors.diet),
  (ShellDestinations.health, 'Health', Icons.favorite_rounded,
      ModuleColors.health),
  (ShellDestinations.finance, 'Finance', Icons.account_balance_wallet_rounded,
      ModuleColors.finance),
];

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String _todayLabel() =>
    DateFormat('EEEE, d MMM').format(DateTime.now());

Widget _glassCard({
  required BuildContext context,
  required Widget child,
  double? radius,
  EdgeInsets? padding,
  VoidCallback? onTap,
}) {
  final colors = BlistraColors.resolve(context);
  final r = radius ?? colors.cardRadius;
  Widget card = DecoratedBox(
    decoration: BoxDecoration(
      color: colors.glassFill,
      borderRadius: BorderRadius.circular(r),
      border: colors.borderWidth > 0
          ? Border.all(color: colors.glassBorder, width: colors.borderWidth)
          : null,
    ),
    child: Padding(
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    ),
  );
  if (onTap != null) {
    card = GestureDetector(onTap: onTap, child: card);
  }
  return card;
}

Widget _headerRow(BuildContext context, {VoidCallback? onProfile}) {
  final colors = BlistraColors.resolve(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                _todayLabel(),
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
            ],
          ),
        ),
        if (onProfile != null)
          GestureDetector(
            onTap: onProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.accent.withValues(alpha: .18),
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: colors.accentText,
              ),
            ),
          ),
      ],
    ),
  );
}

// ─── BentoHome ────────────────────────────────────────────────────────────────

/// 2-column bento grid with glanceable module tiles.
class BentoHome extends StatelessWidget {
  const BentoHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);
        return Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: _headerRow(context, onProfile: onProfile),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _BentoTile(
                        icon: Icons.event_note_rounded,
                        color: ModuleColors.planner,
                        label: 'Planner',
                        value: '${(d?.planner?.todayTasks.length ?? 0) + (d?.planner?.todayEvents.length ?? 0)}',
                        sub: '${d?.planner?.overdueTasks.length ?? 0} overdue',
                        onTap: () => onDestination(ShellDestinations.planner),
                        colors: colors,
                      ),
                      _BentoTile(
                        icon: Icons.medication_rounded,
                        color: ModuleColors.medicines,
                        label: 'Meds',
                        value: '${d?.medicines?.dosesTakenToday ?? 0}/${(d?.medicines?.dosesTakenToday ?? 0) + (d?.medicines?.dosesRemainingToday ?? 0)}',
                        sub: '${d?.medicines?.dosesRemainingToday ?? 0} remaining',
                        onTap: () => onDestination(ShellDestinations.medicines),
                        colors: colors,
                      ),
                      _BentoTile(
                        icon: Icons.check_circle_outline_rounded,
                        color: ModuleColors.habits,
                        label: 'Habits',
                        value: '${d?.habits?.completedToday ?? 0}/${d?.habits?.expectedToday ?? 0}',
                        sub: '${d?.habits?.remainingToday ?? 0} left today',
                        onTap: () => onDestination(ShellDestinations.habits),
                        colors: colors,
                      ),
                      _BentoTile(
                        icon: Icons.restaurant_rounded,
                        color: ModuleColors.diet,
                        label: 'Diet',
                        value: '${d?.diet?.mealCount ?? 0}',
                        sub: 'meals logged',
                        onTap: () => onDestination(ShellDestinations.diet),
                        colors: colors,
                      ),
                      _BentoTile(
                        icon: Icons.favorite_rounded,
                        color: ModuleColors.health,
                        label: 'Health',
                        value: '${d?.health?.latestMeasurements.length ?? 0}',
                        sub: 'recent readings',
                        onTap: () => onDestination(ShellDestinations.health),
                        colors: colors,
                      ),
                      _BentoTile(
                        icon: Icons.account_balance_wallet_rounded,
                        color: ModuleColors.finance,
                        label: 'Finance',
                        value: d?.finance?.currencies.isNotEmpty == true
                            ? d!.finance!.currencies.first.currency
                            : '—',
                        sub: 'this month',
                        onTap: () => onDestination(ShellDestinations.finance),
                        colors: colors,
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;
  final BlistraColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(colors.cardRadius),
          border: colors.borderWidth > 0
              ? Border.all(
                  color: colors.glassBorder,
                  width: colors.borderWidth,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                  letterSpacing: -1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.accentText,
                ),
              ),
              Text(
                sub,
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TimelineHome ─────────────────────────────────────────────────────────────

/// Chronological scrolling timeline of today's items.
class TimelineHome extends StatelessWidget {
  const TimelineHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final now = DateTime.now();
        final items = buildTimeline(d, now: now, limit: 30);
        final colors = BlistraColors.resolve(context);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: _headerRow(context, onProfile: onProfile),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final isNow = !item.anytime &&
                          item.at.difference(now).inMinutes.abs() <= 30;
                      return _TimelineRow(
                        item: item,
                        now: now,
                        highlight: isNow,
                        colors: colors,
                        onTap: () => onDestination(
                          _destinationForSource(item.source),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _destinationForSource(HomeSource source) => switch (source) {
    HomeSource.task => ShellDestinations.planner,
    HomeSource.medicine => ShellDestinations.medicines,
    HomeSource.habit => ShellDestinations.habits,
    HomeSource.meal => ShellDestinations.diet,
    _ => ShellDestinations.home,
  };
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.now,
    required this.highlight,
    required this.colors,
    required this.onTap,
  });

  final TimelineItem item;
  final DateTime now;
  final bool highlight;
  final BlistraColors colors;
  final VoidCallback onTap;

  Color get _sourceColor => switch (item.source) {
    HomeSource.medicine => ModuleColors.medicines,
    HomeSource.habit => ModuleColors.habits,
    HomeSource.task => ModuleColors.planner,
    HomeSource.meal => ModuleColors.diet,
    _ => ModuleColors.health,
  };

  @override
  Widget build(BuildContext context) {
    final timeLabel = item.anytime
        ? 'Any time'
        : DateFormat('HH:mm').format(item.at);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.done
                        ? colors.muted
                        : highlight
                            ? _sourceColor
                            : _sourceColor.withValues(alpha: .6),
                  ),
                ),
                if (true) // connector line
                  Container(
                    width: 2,
                    height: 28,
                    color: colors.glassBorder,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: highlight
                      ? _sourceColor.withValues(alpha: .12)
                      : colors.glassFill,
                  borderRadius: BorderRadius.circular(colors.inputRadius),
                  border: highlight
                      ? Border.all(
                          color: _sourceColor.withValues(alpha: .4),
                          width: 1,
                        )
                      : colors.borderWidth > 0
                          ? Border.all(
                              color: colors.glassBorder,
                              width: colors.borderWidth,
                            )
                          : null,
                ),
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        highlight ? FontWeight.w600 : FontWeight.w500,
                    color: item.done
                        ? colors.muted
                        : highlight
                            ? _sourceColor
                            : colors.text,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FocusHome ────────────────────────────────────────────────────────────────

/// One important thing front and centre, with upcoming items below.
class FocusHome extends StatelessWidget {
  const FocusHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final now = DateTime.now();
        final focus = focusItem(d, now);
        final next = buildTimeline(d, now: now, limit: 10)
            .where((i) => !i.done && i != focus)
            .take(4)
            .toList();
        final colors = BlistraColors.resolve(context);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _headerRow(context, onProfile: onProfile),
                  const SizedBox(height: 24),
                  // Hero focus card
                  if (focus != null)
                    _FocusCard(item: focus, colors: colors,
                        onTap: () => onDestination(_destFor(focus.source)))
                  else
                    _AllDoneCard(colors: colors),
                  const SizedBox(height: 20),
                  if (next.isNotEmpty) ...[
                    Text(
                      'Up next',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in next)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _glassCard(
                          context: context,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          onTap: () => onDestination(_destFor(item.source)),
                          child: Row(
                            children: [
                              Icon(
                                _iconFor(item.source),
                                size: 16,
                                color: colors.muted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.text,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (!item.anytime)
                                Text(
                                  DateFormat('HH:mm').format(item.at),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _destFor(HomeSource s) => switch (s) {
    HomeSource.task => ShellDestinations.planner,
    HomeSource.medicine => ShellDestinations.medicines,
    HomeSource.habit => ShellDestinations.habits,
    HomeSource.meal => ShellDestinations.diet,
    _ => ShellDestinations.home,
  };

  static IconData _iconFor(HomeSource s) => switch (s) {
    HomeSource.task => Icons.event_note_rounded,
    HomeSource.medicine => Icons.medication_rounded,
    HomeSource.habit => Icons.check_circle_outline_rounded,
    HomeSource.meal => Icons.restaurant_rounded,
    _ => Icons.circle_outlined,
  };
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.item,
    required this.colors,
    required this.onTap,
  });
  final TimelineItem item;
  final BlistraColors colors;
  final VoidCallback onTap;

  Color get _color => switch (item.source) {
    HomeSource.medicine => ModuleColors.medicines,
    HomeSource.habit => ModuleColors.habits,
    HomeSource.task => ModuleColors.planner,
    HomeSource.meal => ModuleColors.diet,
    _ => ModuleColors.health,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _color.withValues(alpha: .18),
              _color.withValues(alpha: .06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(colors.cardRadius + 4),
          border: Border.all(
            color: _color.withValues(alpha: .3),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT UP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _color,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.text,
                letterSpacing: -0.5,
              ),
            ),
            if (!item.anytime) ...[
              const SizedBox(height: 6),
              Text(
                relativeLabel(item.at, DateTime.now()),
                style: TextStyle(fontSize: 14, color: _color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.colors});
  final BlistraColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(colors.cardRadius + 4),
        border: Border.all(
          color: colors.accent.withValues(alpha: .25),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.accent, size: 48),
          const SizedBox(height: 12),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          Text(
            'Nothing pending right now.',
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

// ─── StreamHome ───────────────────────────────────────────────────────────────

/// Scrolling insight cards — most urgent first.
class StreamHome extends StatelessWidget {
  const StreamHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);
        final cards = _buildCards(d);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: _headerRow(context, onProfile: onProfile),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: cards.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final card = cards[i];
                      return GestureDetector(
                        onTap: () => onDestination(card.dest),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: card.color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(colors.cardRadius),
                            border: Border.all(
                              color: card.color.withValues(alpha: .3),
                              width: colors.borderWidth > 0
                                  ? colors.borderWidth
                                  : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: card.color.withValues(alpha: .2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  card.icon,
                                  color: card.color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                      ),
                                    ),
                                    if (card.sub.isNotEmpty)
                                      Text(
                                        card.sub,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.muted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_StreamCard> _buildCards(DashboardResponse? d) {
    final cards = <_StreamCard>[];
    // Medicines
    final medsRemaining = d?.medicines?.dosesRemainingToday ?? 0;
    final medsTaken = d?.medicines?.dosesTakenToday ?? 0;
    cards.add(_StreamCard(
      title: medsRemaining > 0
          ? '$medsRemaining dose${medsRemaining != 1 ? 's' : ''} remaining'
          : '$medsTaken dose${medsTaken != 1 ? 's' : ''} taken today',
      sub: medsRemaining > 0 ? 'Tap to view your medicines' : 'All caught up!',
      icon: Icons.medication_rounded,
      color: ModuleColors.medicines,
      dest: ShellDestinations.medicines,
    ));
    // Habits
    final habitsLeft = d?.habits?.remainingToday ?? 0;
    final habitsDone = d?.habits?.completedToday ?? 0;
    cards.add(_StreamCard(
      title: habitsLeft > 0
          ? '$habitsLeft habit${habitsLeft != 1 ? 's' : ''} left today'
          : '$habitsDone habit${habitsDone != 1 ? 's' : ''} completed',
      sub: habitsLeft > 0 ? 'Keep the streak going' : '🔥 Great consistency!',
      icon: Icons.check_circle_outline_rounded,
      color: ModuleColors.habits,
      dest: ShellDestinations.habits,
    ));
    // Planner
    final overdue = d?.planner?.overdueTasks.length ?? 0;
    final todayTasks = d?.planner?.todayTasks.length ?? 0;
    cards.add(_StreamCard(
      title: overdue > 0
          ? '$overdue overdue task${overdue != 1 ? 's' : ''}'
          : '$todayTasks task${todayTasks != 1 ? 's' : ''} today',
      sub: overdue > 0 ? '⚠ These need attention' : 'View your planner',
      icon: Icons.event_note_rounded,
      color: ModuleColors.planner,
      dest: ShellDestinations.planner,
    ));
    // Diet
    final meals = d?.diet?.mealCount ?? 0;
    cards.add(_StreamCard(
      title: '$meals meal${meals != 1 ? 's' : ''} logged today',
      sub: 'Track nutrition and water',
      icon: Icons.restaurant_rounded,
      color: ModuleColors.diet,
      dest: ShellDestinations.diet,
    ));
    // Health
    final measurements = d?.health?.latestMeasurements.length ?? 0;
    cards.add(_StreamCard(
      title: '$measurements recent health reading${measurements != 1 ? 's' : ''}',
      sub: 'View vitals and appointments',
      icon: Icons.favorite_rounded,
      color: ModuleColors.health,
      dest: ShellDestinations.health,
    ));
    // Finance
    cards.add(const _StreamCard(
      title: 'Finance overview',
      sub: 'View income, expenses and budget',
      icon: Icons.account_balance_wallet_rounded,
      color: ModuleColors.finance,
      dest: ShellDestinations.finance,
    ));
    return cards;
  }
}

class _StreamCard {
  const _StreamCard({
    required this.title,
    required this.sub,
    required this.icon,
    required this.color,
    required this.dest,
  });
  final String title;
  final String sub;
  final IconData icon;
  final Color color;
  final String dest;
}

// ─── MinimalHome ──────────────────────────────────────────────────────────────

/// Just the key numbers — nothing else.
class MinimalHome extends StatelessWidget {
  const MinimalHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _headerRow(context, onProfile: onProfile),
                  const Spacer(),
                  Row(
                    children: [
                      _StatBlock(
                        value: '${(d?.planner?.todayTasks.length ?? 0) + (d?.planner?.todayEvents.length ?? 0)}',
                        label: 'tasks',
                        color: ModuleColors.planner,
                        onTap: () => onDestination(ShellDestinations.planner),
                        colors: colors,
                      ),
                      const SizedBox(width: 2),
                      _StatBlock(
                        value: '${d?.medicines?.dosesRemainingToday ?? 0}',
                        label: 'doses left',
                        color: ModuleColors.medicines,
                        onTap: () => onDestination(ShellDestinations.medicines),
                        colors: colors,
                      ),
                      const SizedBox(width: 2),
                      _StatBlock(
                        value: '${d?.habits?.remainingToday ?? 0}',
                        label: 'habits',
                        color: ModuleColors.habits,
                        onTap: () => onDestination(ShellDestinations.habits),
                        colors: colors,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatBlock(
                        value: '${d?.diet?.mealCount ?? 0}',
                        label: 'meals',
                        color: ModuleColors.diet,
                        onTap: () => onDestination(ShellDestinations.diet),
                        colors: colors,
                      ),
                      const SizedBox(width: 2),
                      _StatBlock(
                        value: '${d?.health?.latestMeasurements.length ?? 0}',
                        label: 'readings',
                        color: ModuleColors.health,
                        onTap: () => onDestination(ShellDestinations.health),
                        colors: colors,
                      ),
                      const SizedBox(width: 2),
                      _StatBlock(
                        value: '${d?.finance?.currencies.length ?? 0}',
                        label: 'currencies',
                        color: ModuleColors.finance,
                        onTap: () => onDestination(ShellDestinations.finance),
                        colors: colors,
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  Center(
                    child: FilledButton.tonal(
                      onPressed: onQuickAdd,
                      child: const Text('Quick add'),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
    required this.colors,
  });
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final BlistraColors colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(colors.inputRadius),
            border: Border.all(
              color: color.withValues(alpha: .2),
              width: math.max(colors.borderWidth, 0.5),
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -1,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── EditorialHome ────────────────────────────────────────────────────────────

/// Newspaper-style morning briefing.
class EditorialHome extends StatelessWidget {
  const EditorialHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);
        final tasks =
            (d?.planner?.todayTasks.length ?? 0) + (d?.planner?.todayEvents.length ?? 0);
        final meds = (d?.medicines?.dosesTakenToday ?? 0) +
            (d?.medicines?.dosesRemainingToday ?? 0);
        final habits = d?.habits?.expectedToday ?? 0;

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onProfile,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: colors.accent.withValues(alpha: .18),
                          child: Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: colors.accentText,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'BLISTRA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                          color: colors.accentText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('d MMM').format(DateTime.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    color: colors.borderWidth > 0
                        ? colors.glassBorder
                        : colors.muted.withValues(alpha: 0.3),
                    thickness: colors.borderWidth > 0 ? colors.borderWidth : 1,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _headline(tasks, meds, habits),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colors.text,
                      height: 1.2,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: colors.glassBorder,
                    thickness: colors.borderWidth > 0 ? colors.borderWidth : 1,
                  ),
                  const SizedBox(height: 16),
                  // Two-column module grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _EditorialSection(
                          title: 'HEALTH & MEDS',
                          lines: [
                            '${d?.medicines?.dosesTakenToday ?? 0} of $meds doses taken',
                            '${d?.health?.latestMeasurements.length ?? 0} recent readings',
                          ],
                          color: ModuleColors.medicines,
                          onTap: () =>
                              onDestination(ShellDestinations.medicines),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _EditorialSection(
                          title: 'PLANNER',
                          lines: [
                            '$tasks items today',
                            '${d?.planner?.overdueTasks.length ?? 0} overdue',
                          ],
                          color: ModuleColors.planner,
                          onTap: () => onDestination(ShellDestinations.planner),
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: colors.glassBorder,
                    thickness: colors.borderWidth > 0 ? colors.borderWidth : 1,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _EditorialSection(
                          title: 'HABITS',
                          lines: [
                            '${d?.habits?.completedToday ?? 0} of $habits done',
                            '${d?.habits?.remainingToday ?? 0} remaining',
                          ],
                          color: ModuleColors.habits,
                          onTap: () => onDestination(ShellDestinations.habits),
                          colors: colors,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _EditorialSection(
                          title: 'DIET & FINANCE',
                          lines: [
                            '${d?.diet?.mealCount ?? 0} meals logged',
                            '${d?.finance?.currencies.length ?? 0} currencies',
                          ],
                          color: ModuleColors.diet,
                          onTap: () => onDestination(ShellDestinations.diet),
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _headline(int tasks, int meds, int habits) {
    final parts = <String>[];
    if (tasks > 0) parts.add('$tasks task${tasks != 1 ? 's' : ''}');
    if (meds > 0) parts.add('$meds dose${meds != 1 ? 's' : ''}');
    if (habits > 0) parts.add('$habits habit${habits != 1 ? 's' : ''}');
    if (parts.isEmpty) return 'All clear today';
    return parts.join(' · ');
  }
}

class _EditorialSection extends StatelessWidget {
  const _EditorialSection({
    required this.title,
    required this.lines,
    required this.color,
    required this.onTap,
    required this.colors,
  });
  final String title;
  final List<String> lines;
  final Color color;
  final VoidCallback onTap;
  final BlistraColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: TextStyle(fontSize: 13, color: colors.text),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── BlisterHome ──────────────────────────────────────────────────────────────

/// Signature pill-blister pack layout.
class BlisterHome extends StatelessWidget {
  const BlisterHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);
        final taken = d?.medicines?.dosesTakenToday ?? 0;
        final remaining = d?.medicines?.dosesRemainingToday ?? 0;
        final total = taken + remaining;
        final blisterCount = math.max(total, 7);

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _headerRow(context, onProfile: onProfile),
                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => onDestination(ShellDestinations.medicines),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ModuleColors.medicines.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(colors.cardRadius),
                        border: Border.all(
                          color: ModuleColors.medicines.withValues(alpha: .3),
                          width: math.max(colors.borderWidth, 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.medication_rounded,
                                color: ModuleColors.medicines,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Medicines',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ModuleColors.medicines,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$taken / $total taken',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Blister pack grid
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (int i = 0; i < blisterCount; i++)
                                _BlisterCell(
                                  taken: i < taken,
                                  color: ModuleColors.medicines,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Module tiles
                  Row(
                    children: [
                      for (int i = 0;
                          i < _modules.length && i < 3;
                          i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _SmallModuleTile(
                            icon: _modules[i].$3,
                            label: _modules[i].$2,
                            color: _modules[i].$4,
                            onTap: () =>
                                onDestination(_modules[i].$1),
                            colors: colors,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (int i = 3;
                          i < _modules.length;
                          i++) ...[
                        if (i > 3) const SizedBox(width: 10),
                        Expanded(
                          child: _SmallModuleTile(
                            icon: _modules[i].$3,
                            label: _modules[i].$2,
                            color: _modules[i].$4,
                            onTap: () =>
                                onDestination(_modules[i].$1),
                            colors: colors,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BlisterCell extends StatelessWidget {
  const _BlisterCell({required this.taken, required this.color});
  final bool taken;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: taken
            ? color.withValues(alpha: .15)
            : color.withValues(alpha: .5),
        border: Border.all(
          color: taken ? color.withValues(alpha: .3) : color,
          width: 1.5,
        ),
      ),
      child: taken
          ? Icon(Icons.check, size: 16, color: color.withValues(alpha: .5))
          : null,
    );
  }
}

class _SmallModuleTile extends StatelessWidget {
  const _SmallModuleTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.colors,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final BlistraColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(colors.inputRadius),
          border: Border.all(
            color: color.withValues(alpha: .25),
            width: math.max(colors.borderWidth, 0.5),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SplitHome ────────────────────────────────────────────────────────────────

/// Score ring above, action list below.
class SplitHome extends StatelessWidget {
  const SplitHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final now = DateTime.now();
        final items = buildTimeline(d, now: now, limit: 12)
            .where((i) => !i.done)
            .toList();
        final colors = BlistraColors.resolve(context);

        final total = (d?.planner?.todayTasks.length ?? 0) +
            (d?.medicines?.dosesTakenToday ?? 0) +
            (d?.medicines?.dosesRemainingToday ?? 0) +
            (d?.habits?.expectedToday ?? 0);
        final done = (d?.medicines?.dosesTakenToday ?? 0) +
            (d?.habits?.completedToday ?? 0);
        final pct = total > 0 ? done / total : 0.0;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top split: ring
                Expanded(
                  flex: 4,
                  child: Center(
                    child: _ProgressRing(
                      progress: pct,
                      colors: colors,
                      onProfile: onProfile,
                    ),
                  ),
                ),
                // Bottom split: scrollable list
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: Text(
                          'Today\'s actions',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: items.length,
                          separatorBuilder: (context, i) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return _glassCard(
                              context: context,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              onTap: () {},
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.progress,
    required this.colors,
    required this.onProfile,
  });
  final double progress;
  final BlistraColors colors;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onProfile,
          child: SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: colors.accent,
                trackColor: colors.accent.withValues(alpha: .15),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'done',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _todayLabel(),
          style: TextStyle(fontSize: 13, color: colors.muted),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });
  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    // Track
    paint.color = trackColor;
    canvas.drawCircle(center, radius, paint);
    // Progress
    if (progress > 0) {
      paint.color = color;
      final sweep = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── CardDeckHome ─────────────────────────────────────────────────────────────

/// Swipeable full-screen module cards.
class CardDeckHome extends StatefulWidget {
  const CardDeckHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  State<CardDeckHome> createState() => _CardDeckHomeState();
}

class _CardDeckHomeState extends State<CardDeckHome> {
  final _pageController = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);
        final cards = _buildCards(d);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: _headerRow(context, onProfile: widget.onProfile),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: cards.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _ModuleCard(
                        card: cards[i],
                        colors: colors,
                        onTap: () => widget.onDestination(cards[i].dest),
                      ),
                    ),
                  ),
                ),
                // Dots
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < cards.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _page ? 20 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _page
                                ? colors.accent
                                : colors.muted.withValues(alpha: .4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ModuleCardData> _buildCards(DashboardResponse? d) => [
    _ModuleCardData(
      icon: Icons.event_note_rounded,
      color: ModuleColors.planner,
      label: 'Planner',
      value: '${(d?.planner?.todayTasks.length ?? 0) + (d?.planner?.todayEvents.length ?? 0)}',
      sub: '${d?.planner?.overdueTasks.length ?? 0} overdue tasks',
      dest: ShellDestinations.planner,
    ),
    _ModuleCardData(
      icon: Icons.medication_rounded,
      color: ModuleColors.medicines,
      label: 'Medicines',
      value: '${d?.medicines?.dosesTakenToday ?? 0}/${(d?.medicines?.dosesTakenToday ?? 0) + (d?.medicines?.dosesRemainingToday ?? 0)}',
      sub: '${d?.medicines?.dosesRemainingToday ?? 0} remaining today',
      dest: ShellDestinations.medicines,
    ),
    _ModuleCardData(
      icon: Icons.check_circle_outline_rounded,
      color: ModuleColors.habits,
      label: 'Habits',
      value: '${d?.habits?.completedToday ?? 0}/${d?.habits?.expectedToday ?? 0}',
      sub: '${d?.habits?.remainingToday ?? 0} left today',
      dest: ShellDestinations.habits,
    ),
    _ModuleCardData(
      icon: Icons.restaurant_rounded,
      color: ModuleColors.diet,
      label: 'Diet',
      value: '${d?.diet?.mealCount ?? 0}',
      sub: 'meals logged today',
      dest: ShellDestinations.diet,
    ),
    _ModuleCardData(
      icon: Icons.favorite_rounded,
      color: ModuleColors.health,
      label: 'Health',
      value: '${d?.health?.latestMeasurements.length ?? 0}',
      sub: 'recent measurements',
      dest: ShellDestinations.health,
    ),
    _ModuleCardData(
      icon: Icons.account_balance_wallet_rounded,
      color: ModuleColors.finance,
      label: 'Finance',
      value: '${d?.finance?.currencies.length ?? 0}',
      sub: 'currencies tracked',
      dest: ShellDestinations.finance,
    ),
  ];
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.dest,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;
  final String dest;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.card,
    required this.colors,
    required this.onTap,
  });
  final _ModuleCardData card;
  final BlistraColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              card.color.withValues(alpha: .2),
              card.color.withValues(alpha: .06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(colors.cardRadius + 4),
          border: Border.all(
            color: card.color.withValues(alpha: .35),
            width: math.max(colors.borderWidth, 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: card.color.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(card.icon, color: card.color, size: 28),
              ),
              const Spacer(),
              Text(
                card.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: card.color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.value,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: colors.text,
                  letterSpacing: -3,
                  height: 1,
                ),
              ),
              Text(
                card.sub,
                style: TextStyle(fontSize: 15, color: colors.muted),
              ),
              const Spacer(),
              Row(
                children: [
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: card.color,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── QuadHome ─────────────────────────────────────────────────────────────────

/// Four equal quadrants — one module per corner.
class QuadHome extends StatelessWidget {
  const QuadHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _headerRow(context, onProfile: onProfile),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _QuadTile(
                                icon: Icons.event_note_rounded,
                                color: ModuleColors.planner,
                                label: 'Planner',
                                primary: '${(d?.planner?.todayTasks.length ?? 0) + (d?.planner?.todayEvents.length ?? 0)}',
                                secondary: 'today',
                                badge: d?.planner?.overdueTasks.isNotEmpty == true
                                    ? '${d!.planner!.overdueTasks.length} overdue'
                                    : null,
                                onTap: () =>
                                    onDestination(ShellDestinations.planner),
                                colors: colors,
                              ),
                              const SizedBox(width: 8),
                              _QuadTile(
                                icon: Icons.medication_rounded,
                                color: ModuleColors.medicines,
                                label: 'Meds',
                                primary: '${d?.medicines?.dosesRemainingToday ?? 0}',
                                secondary: 'remaining',
                                badge: null,
                                onTap: () =>
                                    onDestination(ShellDestinations.medicines),
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            children: [
                              _QuadTile(
                                icon: Icons.check_circle_outline_rounded,
                                color: ModuleColors.habits,
                                label: 'Habits',
                                primary: '${d?.habits?.completedToday ?? 0}',
                                secondary: 'done',
                                badge: d?.habits?.remainingToday != null &&
                                        d!.habits!.remainingToday > 0
                                    ? '${d.habits!.remainingToday} left'
                                    : null,
                                onTap: () =>
                                    onDestination(ShellDestinations.habits),
                                colors: colors,
                              ),
                              const SizedBox(width: 8),
                              _QuadTile(
                                icon: Icons.restaurant_rounded,
                                color: ModuleColors.diet,
                                label: 'Diet',
                                primary: '${d?.diet?.mealCount ?? 0}',
                                secondary: 'meals',
                                badge: null,
                                onTap: () =>
                                    onDestination(ShellDestinations.diet),
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 64,
                          child: Row(
                            children: [
                              _QuadTile(
                                icon: Icons.favorite_rounded,
                                color: ModuleColors.health,
                                label: 'Health',
                                primary: '${d?.health?.latestMeasurements.length ?? 0}',
                                secondary: 'readings',
                                badge: null,
                                onTap: () =>
                                    onDestination(ShellDestinations.health),
                                colors: colors,
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              _QuadTile(
                                icon: Icons.account_balance_wallet_rounded,
                                color: ModuleColors.finance,
                                label: 'Finance',
                                primary: '—',
                                secondary: 'track',
                                badge: null,
                                onTap: () =>
                                    onDestination(ShellDestinations.finance),
                                colors: colors,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                      ],
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
}

class _QuadTile extends StatelessWidget {
  const _QuadTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.badge,
    required this.onTap,
    required this.colors,
    this.compact = false,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String primary;
  final String secondary;
  final String? badge;
  final VoidCallback onTap;
  final BlistraColors colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(colors.cardRadius),
            border: colors.borderWidth > 0
                ? Border.all(
                    color: color.withValues(alpha: .25),
                    width: colors.borderWidth,
                  )
                : null,
          ),
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: compact
              ? Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      primary,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        if (badge != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Text(
                      primary,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    ),
                    Text(
                      secondary,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── OrbitHome ────────────────────────────────────────────────────────────────

/// Circular module layout around a centre ring.
class OrbitHome extends StatelessWidget {
  const OrbitHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final colors = BlistraColors.resolve(context);
        final total = (d?.planner?.todayTasks.length ?? 0) +
            (d?.medicines?.dosesTakenToday ?? 0) +
            (d?.medicines?.dosesRemainingToday ?? 0) +
            (d?.habits?.expectedToday ?? 0);
        final done = (d?.medicines?.dosesTakenToday ?? 0) +
            (d?.habits?.completedToday ?? 0);
        final pct = total > 0 ? done / total : 0.0;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _headerRow(context, onProfile: onProfile),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight * 0.85,
                      );
                      return Center(
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Centre ring
                              _ProgressRing(
                                progress: pct,
                                colors: colors,
                                onProfile: onProfile,
                              ),
                              // Orbit items
                              for (int i = 0; i < _modules.length; i++)
                                _OrbitItem(
                                  index: i,
                                  total: _modules.length,
                                  orbitRadius: size * 0.38,
                                  icon: _modules[i].$3,
                                  label: _modules[i].$2,
                                  color: _modules[i].$4,
                                  onTap: () => onDestination(_modules[i].$1),
                                  colors: colors,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrbitItem extends StatelessWidget {
  const _OrbitItem({
    required this.index,
    required this.total,
    required this.orbitRadius,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.colors,
  });
  final int index;
  final int total;
  final double orbitRadius;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final BlistraColors colors;

  @override
  Widget build(BuildContext context) {
    final angle = -math.pi / 2 + (2 * math.pi * index / total);
    final x = orbitRadius * math.cos(angle);
    final y = orbitRadius * math.sin(angle);

    return Transform.translate(
      offset: Offset(x, y),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .15),
                border: Border.all(
                  color: color.withValues(alpha: .5),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SunArcHome ───────────────────────────────────────────────────────────────

/// Day visualised as a sun arc, tasks plotted along the arc.
class SunArcHome extends StatelessWidget {
  const SunArcHome({
    super.key,
    required this.onDestination,
    required this.onQuickAdd,
    required this.onProfile,
  });

  final void Function(String) onDestination;
  final VoidCallback onQuickAdd;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.dashboard,
      builder: (context, _) {
        final d = scope.dashboard.dashboard;
        final now = DateTime.now();
        final items =
            buildTimeline(d, now: now, limit: 20).where((i) => !i.anytime).toList();
        final colors = BlistraColors.resolve(context);
        // Day progress: 6am = 0, 10pm = 1
        final dayStart = DateTime(now.year, now.month, now.day, 6);
        final dayEnd = DateTime(now.year, now.month, now.day, 22);
        final dayPct = now.isBefore(dayStart)
            ? 0.0
            : now.isAfter(dayEnd)
                ? 1.0
                : now.difference(dayStart).inMinutes /
                    dayEnd.difference(dayStart).inMinutes;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _headerRow(context, onProfile: onProfile),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SunArcPainter(
                    dayProgress: dayPct,
                    items: items,
                    dayStart: dayStart,
                    dayEnd: dayEnd,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.take(6).length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _glassCard(
                          context: context,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Text(
                                DateFormat('HH:mm').format(item.at),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.muted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: item.done
                                        ? colors.muted
                                        : colors.text,
                                    decoration: item.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SunArcPainter extends StatelessWidget {
  const _SunArcPainter({
    required this.dayProgress,
    required this.items,
    required this.dayStart,
    required this.dayEnd,
    required this.colors,
  });
  final double dayProgress;
  final List<TimelineItem> items;
  final DateTime dayStart;
  final DateTime dayEnd;
  final BlistraColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _ArcPainterImpl(
          progress: dayProgress,
          accentColor: colors.accent,
          trackColor: colors.accent.withValues(alpha: .15),
          textColor: colors.muted,
          items: items,
          dayStart: dayStart,
          dayEnd: dayEnd,
          dotColor: ModuleColors.medicines,
        ),
      ),
    );
  }
}

class _ArcPainterImpl extends CustomPainter {
  const _ArcPainterImpl({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
    required this.textColor,
    required this.items,
    required this.dayStart,
    required this.dayEnd,
    required this.dotColor,
  });
  final double progress;
  final Color accentColor;
  final Color trackColor;
  final Color textColor;
  final List<TimelineItem> items;
  final DateTime dayStart;
  final DateTime dayEnd;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final centerY = h * 1.6;
    final radius = h * 1.7;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Track
    paint.color = trackColor;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      math.pi * 1.2,
      math.pi * 0.6 * -1 + math.pi,
      false,
      paint,
    );

    // Arc progress (left to right = sunrise to sunset)
    final startAngle = math.pi;
    final sweepAngle = -math.pi * progress;
    paint.color = accentColor;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    // Sun dot
    final sunAngle = startAngle + sweepAngle;
    final sx = centerX + radius * math.cos(sunAngle);
    final sy = centerY + radius * math.sin(sunAngle);
    paint
      ..style = PaintingStyle.fill
      ..color = accentColor;
    canvas.drawCircle(Offset(sx, sy), 10, paint);
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(Offset(sx, sy), 5, paint);
  }

  @override
  bool shouldRepaint(_ArcPainterImpl old) =>
      old.progress != progress || old.accentColor != accentColor;
}
