/// Blistra application shell: single navigation strategy for all features.
///
/// Mobile-first bottom navigation with a responsive [NavigationRail] on wide
/// screens. Every feature tab is mounted once (IndexedStack) so per-feature
/// state survives tab switches. Feature controllers are exposed via
/// [AppScope] (dashboard/planner/session) and `provider` (everything else).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_state.dart';
import '../features/dashboard/dashboard_controller.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/diet/diet_controller.dart';
import '../features/diet/screens/today_screen.dart' as diet;
import '../features/documents/documents_page.dart';
import '../features/documents/providers/documents_provider.dart';
import '../features/finance/finance_controller.dart';
import '../features/finance/finance_home.dart';
import '../features/finance/finance_scope.dart';
import '../features/habits/habits_controller.dart';
import '../features/habits/habits_home.dart';
import '../features/habits/habits_scope.dart';
import '../features/health/health_repository.dart';
import '../features/health/presentation/health_home_screen.dart';
import '../features/medicines/pages/medicine_list_page.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/notifications/screens/reminders_screen.dart';
import '../features/notifications/state/reminders_controller.dart';
import '../features/notifications/state/settings_controller.dart';
import '../features/planner/planner_controller.dart';
import '../features/planner/screens/home_screen.dart' as planner;
import 'app_dependencies.dart';
import 'app_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.deps});

  final AppDependencies deps;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _booted = false;

  AppDependencies get _d => widget.deps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_booted) return;
    _booted = true;
    // Scheduler warms up only (no permission prompt at startup).
    try {
      await _d.scheduler.initialize();
    } catch (_) {
      // Notifications stay unavailable; the app remains usable.
    }
    if (!mounted) return;
    await _d.dashboard.loadDashboard(
      date: DateTime.now(),
      offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
    if (!mounted) return;
    await _d.planner.loadToday();
  }

  Future<void> _refreshNotifications() async {
    await _d.reminders.load();
    await _d.settings.load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      authState: _d.authState,
      dashboard: _d.dashboard,
      planner: _d.planner,
      child: MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: _d.apiClient),
          ChangeNotifierProvider<AuthState>.value(value: _d.authState),
          ChangeNotifierProvider<DashboardController>.value(
              value: _d.dashboard),
          ChangeNotifierProvider<PlannerController>.value(value: _d.planner),
          ChangeNotifierProvider<DietController>.value(value: _d.diet),
          ChangeNotifierProvider<HabitsController>.value(value: _d.habits),
          ChangeNotifierProvider<FinanceController>.value(
              value: _d.finance),
          ChangeNotifierProvider<HealthRepository>.value(value: _d.health),
          ChangeNotifierProvider<DocumentsProvider>.value(
              value: _d.documents),
          ChangeNotifierProvider<RemindersController>.value(
              value: _d.reminders),
          ChangeNotifierProvider<SettingsController>.value(
              value: _d.settings),
        ],
        child: Builder(
          builder: (context) => _buildScaffold(context),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final wide = MediaQuery.widthOf(context) >= 900;
    final pages = _pages();
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final t in _tabs)
                  NavigationRailDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }

  List<_Tab> get _tabs => const [
        _Tab('Home', Icons.dashboard_outlined, Icons.dashboard),
        _Tab('Planner', Icons.event_note_outlined, Icons.event_note),
        _Tab('Health', Icons.favorite_outline, Icons.favorite),
        _Tab('Meds', Icons.medication_outlined, Icons.medication),
        _Tab('Diet', Icons.restaurant_outlined, Icons.restaurant),
        _Tab('Habits', Icons.check_circle_outline, Icons.check_circle),
        _Tab('Finance', Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet),
        _Tab('More', Icons.more_horiz, Icons.more_horiz),
      ];

  List<Widget> _pages() => [
        const DashboardScreen(),
        const planner.HomeScreen(),
        HealthHomeScreen(
          repository: _d.health,
          onLogout: () => _d.authState.logout(),
        ),
        const MedicineListPage(),
        const diet.TodayScreen(),
        HabitsScope(controller: _d.habits, child: const HabitsHome()),
        FinanceScope(controller: _d.finance, child: const FinanceHome()),
        _MoreTab(
          onLogout: () => _d.authState.logout(),
          onRefreshNotifications: _refreshNotifications,
        ),
      ];
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _MoreTab extends StatefulWidget {
  const _MoreTab({required this.onLogout, required this.onRefreshNotifications});

  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshNotifications;

  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  int _sub = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRefreshNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Documents', 'Reminders', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_sub]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => widget.onLogout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _sub,
        children: [
          const DocumentsPage(),
          RemindersScreen(onRefresh: widget.onRefreshNotifications),
          NotificationSettingsScreen(
              onRefresh: widget.onRefreshNotifications),
        ],
      ),
      bottomNavigationBar: SegmentedButton<int>(
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
        segments: const [
          ButtonSegment(
              value: 0, icon: Icon(Icons.folder_outlined), label: Text('Docs')),
          ButtonSegment(
              value: 1,
              icon: Icon(Icons.notifications_outlined),
              label: Text('Alerts')),
          ButtonSegment(
              value: 2,
              icon: Icon(Icons.settings_outlined),
              label: Text('Prefs')),
        ],
        selected: {_sub},
        onSelectionChanged: (s) => setState(() => _sub = s.first),
      ),
    );
  }
}
