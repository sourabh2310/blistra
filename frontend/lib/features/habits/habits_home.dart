/// Habits home shell: bottom navigation and shared loading / error states.
library;

import 'package:flutter/material.dart';

import 'habits_controller.dart';
import 'habits_scope.dart';

import 'screens/today_screen.dart';
import 'screens/habits_list_screen.dart';
import 'screens/statistics_screen.dart';

class HabitsHome extends StatefulWidget {
  const HabitsHome({super.key});

  @override
  State<HabitsHome> createState() => _HabitsHomeState();
}

class _HabitsHomeState extends State<HabitsHome> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle(controller)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: controller.isLoading ? null : controller.loadAll,
          ),
        ],
      ),
      body: _body(controller),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (int index) =>
            setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Statistics',
          ),
        ],
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