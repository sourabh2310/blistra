/// Habits home shell: header, section tabs and shared loading / error states.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/page_header.dart';
import 'habit_insights.dart';
import 'habits_controller.dart';
import 'habits_scope.dart';

import 'screens/today_screen.dart';
import 'screens/habits_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/habit_form_screen.dart';

class HabitsHome extends StatefulWidget {
  const HabitsHome({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HabitsHome> createState() => _HabitsHomeState();
}

class _HabitsHomeState extends State<HabitsHome> {
  late int _tabIndex = widget.initialTab.clamp(0, 2).toInt();
  HabitInsights? _insights;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = HabitsScope.of(context);
      if (controller.status == HabitsLoadStatus.idle) unawaited(_reload());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final HabitsController controller = HabitsScope.of(context);
    if (_insights?.controller != controller) {
      _insights?.dispose();
      _insights = HabitInsights(controller);
    }
  }

  @override
  void dispose() {
    _insights?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await HabitsScope.of(context).loadAll();
    if (mounted) _insights!.reset();
  }

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);
    final HabitInsights insights = _insights!;
    if (controller.status == HabitsLoadStatus.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) insights.ensure();
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: insights,
          builder: (BuildContext context, _) => Column(
            children: [
              BlistraPageHeader(
                eyebrow: 'Habits',
                title: _title(controller),
                subtitle: _subtitle(controller, insights),
                actions: [
                  GlassIconButton(
                    tooltip: 'New habit',
                    icon: Icons.add_rounded,
                    onTap: () => showHabitFormSheet(context),
                  ),
                  GlassIconButton(
                    tooltip: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onTap: controller.isLoading ? null : _reload,
                  ),
                ],
              ),
              BlistraSegmentedTabs(
                labels: const ['Today', 'Habits', 'Statistics'],
                icons: const [
                  Icons.today_outlined,
                  Icons.list_alt_outlined,
                  Icons.show_chart_outlined,
                ],
                selected: _tabIndex,
                onSelected: (index) => setState(() => _tabIndex = index),
              ),
              Expanded(child: _body(controller, insights)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(HabitsController controller, HabitInsights insights) {
    if (controller.status == HabitsLoadStatus.error && controller.habits.isEmpty) {
      return _ErrorState(
        message: controller.errorMessage ?? 'Failed to load your habits',
        onRetry: _reload,
      );
    }
    if (controller.status == HabitsLoadStatus.loading && controller.habits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: IndexedStack(
        index: _tabIndex,
        children: [
          TodayScreen(
            insights: insights,
            onManage: () => setState(() => _tabIndex = 1),
          ),
          const HabitsListScreen(),
          const StatisticsScreen(),
        ],
      ),
    );
  }

  String _title(HabitsController controller) {
    switch (_tabIndex) {
      case 0:
        final int total = controller.todayHabits.length;
        if (total == 0) return 'Habits';
        return '${controller.doneToday.length} of $total today';
      case 1:
        return 'All habits';
      case 2:
        return 'Statistics';
      default:
        return 'Habits';
    }
  }

  String? _subtitle(HabitsController controller, HabitInsights insights) {
    if (controller.status == HabitsLoadStatus.loading &&
        controller.habits.isEmpty) {
      return 'Loading your habits…';
    }
    switch (_tabIndex) {
      case 0:
        final int total = controller.todayHabits.length;
        final int left = controller.dueToday.length;
        final String lead = total == 0
            ? 'Nothing due today.'
            : left == 0
                ? 'All done for today.'
                : '$left left.';
        final int? streak = insights.longestStreak;
        if (streak == null || streak == 0) return lead;
        return '$lead Your longest streak is ${pluralDays(streak)}.';
      case 1:
        final int active = controller.activeHabits.length;
        final int total = controller.habits.length;
        return total == 0
            ? 'Create your first habit to get started.'
            : '$active active of $total';
      case 2:
        final int active = controller.activeHabits.length;
        return active == 1
            ? 'Streaks and completion for 1 active habit.'
            : 'Streaks and completion for $active active habits.';
      default:
        return null;
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 8, kPageGutter, 28),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconWell(Icons.cloud_off_outlined, color: colors.danger),
              const SizedBox(height: 12),
              Text(
                "Habits couldn't load",
                style: BlistraText.serif(19, colors.text),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(fontSize: 12.5, color: colors.muted),
              ),
              const SizedBox(height: 14),
              Pill('Retry', onTap: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}
