/// Habits home shell: bottom navigation and shared loading / error states.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/page_header.dart';
import 'habits_controller.dart';
import 'habits_scope.dart';

import 'screens/today_screen.dart';
import 'screens/habits_list_screen.dart';
import 'screens/statistics_screen.dart';

class HabitsHome extends StatefulWidget {
  const HabitsHome({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HabitsHome> createState() => _HabitsHomeState();
}

class _HabitsHomeState extends State<HabitsHome> {
  late int _tabIndex = widget.initialTab.clamp(0, 2).toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = HabitsScope.of(context);
      if (controller.status == HabitsLoadStatus.idle) unawaited(controller.loadAll());
    });
  }

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BlistraPageHeader(
              title: 'Habits',
              subtitle: _appBarTitle(controller),
              actions: [
                GlassIconButton(
                  tooltip: 'Refresh',
                  icon: Icons.refresh_rounded,
                  onTap: controller.isLoading ? null : controller.loadAll,
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
            Expanded(child: _body(controller)),
          ],
        ),
      ),
    );
  }

  Widget _body(HabitsController controller) {
    if (controller.status == HabitsLoadStatus.error && controller.habits.isEmpty) {
      return _ErrorState(
        message: controller.errorMessage ?? 'Failed to load your habits',
        onRetry: controller.loadAll,
      );
    }
    if (controller.status == HabitsLoadStatus.loading && controller.habits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: controller.loadAll,
      child: IndexedStack(
        index: _tabIndex,
        children: const [
          TodayScreen(),
          HabitsListScreen(),
          StatisticsScreen(),
        ],
      ),
    );
  }

  String _appBarTitle(HabitsController controller) {
    switch (_tabIndex) {
      case 0:
        return 'Today';
      case 1:
        return 'Habits';
      case 2:
        return 'Statistics';
      default:
        return 'Blistra';
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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