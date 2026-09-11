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
              tooltip: t.label,
            ),
        ],
      ),
    );
  }

  /// Primary destinations only — everything else lives under More.
  List<_Tab> get _tabs => const [
        _Tab('Home', Icons.dashboard_outlined, Icons.dashboard),
        _Tab('Planner', Icons.event_note_outlined, Icons.event_note),
        _Tab('Health', Icons.favorite_outline, Icons.favorite),
        _Tab('Finance', Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet),
        _Tab('More', Icons.grid_view_outlined, Icons.grid_view_rounded),
      ];

  void goToTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _index = index);
  }

  List<Widget> _pages() => [
        DashboardScreen(onNavigate: goToTab),
        const planner.HomeScreen(),
        HealthHomeScreen(
          repository: _d.health,
          onLogout: () => _d.authState.logout(),
        ),
        FinanceScope(controller: _d.finance, child: const FinanceHome()),
        _MoreTab(
          onLogout: () => _d.authState.logout(),
          onRefreshNotifications: _refreshNotifications,
          dietController: _d.diet,
          habitsController: _d.habits,
          onNavigatePrimary: goToTab,
        ),
      ];
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.onLogout,
    required this.onRefreshNotifications,
    required this.dietController,
    required this.habitsController,
    required this.onNavigatePrimary,
  });

  final Future<void> Function() onLogout;
  final Future<void> Function() onRefreshNotifications;
  final dynamic dietController;
  final dynamic habitsController;
  final void Function(int index) onNavigatePrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => onLogout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Your life, organized',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _MoreTile(
            icon: Icons.medication_outlined,
            title: 'Medicines',
            subtitle: 'Schedules, doses, refills',
            onTap: () => _open(context, const MedicineListPage(), 'Medicines'),
          ),
          _MoreTile(
            icon: Icons.restaurant_outlined,
            title: 'Diet',
            subtitle: 'Meals, water, nutrition',
            onTap: () =>
                _open(context, const diet.TodayScreen(), 'Diet'),
          ),
          _MoreTile(
            icon: Icons.check_circle_outline,
            title: 'Habits',
            subtitle: 'Streaks and daily progress',
            onTap: () => _openHabits(context),
          ),
          _MoreTile(
            icon: Icons.folder_outlined,
            title: 'Documents',
            subtitle: 'PDFs, reports, files',
            onTap: () =>
                _open(context, const DocumentsPage(), 'Documents'),
          ),
          _MoreTile(
            icon: Icons.notifications_outlined,
            title: 'Reminders',
            subtitle: 'Alerts and schedules',
            onTap: () => _open(
              context,
              RemindersScreen(onRefresh: onRefreshNotifications),
              'Reminders',
            ),
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: 'Notification settings',
            subtitle: 'Preferences and devices',
            onTap: () => _open(
              context,
              NotificationSettingsScreen(onRefresh: onRefreshNotifications),
              'Settings',
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: page,
        ),
      ),
    );
  }

  void _openHabits(BuildContext context) {
    // HabitsHome reads HabitsScope; provide it explicitly for the pushed route.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Habits')),
          body: HabitsScope(
              controller: habitsController, child: const HabitsHome()),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
