import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../planner/planner_controller.dart';
import 'events_screen.dart';
import 'lists_screen.dart';
import 'tasks_screen.dart';
import 'today_screen.dart';

/// The app shell after authentication: bottom navigation with four tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  static const _titles = ['Today', 'Tasks', 'Lists', 'Events'];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final planner = scope.planner;
    final auth = scope.auth;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentTab]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                auth.logout();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [Icon(Icons.logout), SizedBox(width: 8), Text('Log out')],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          const TodayScreen(),
          const TasksScreen(),
          const ListsScreen(),
          const EventsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) {
          setState(() => _currentTab = index);
          _onTabSelected(planner, index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.label), label: 'Lists'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
        ],
      ),
    );
  }

  void _onTabSelected(PlannerController planner, int index) {
    switch (index) {
      case 0:
        planner.loadToday();
      case 1:
        planner.loadTasks();
      case 2:
        planner.loadTaskLists();
      case 3:
        planner.loadEvents();
    }
  }
}