/// Blistra application shell: single navigation strategy for all features.
///
/// Mobile-first bottom navigation with a responsive [NavigationRail] on wide
/// screens. Every feature tab is mounted once (IndexedStack) so per-feature
/// state survives tab switches. Feature controllers are exposed via
/// [AppScope] (dashboard/planner/session) and `provider` (everything else).
library;

import 'package:flutter/material.dart';

import '../core/widgets/module_guard.dart';
import '../core/widgets/quick_add.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/diet/screens/today_screen.dart' as diet;
import '../features/documents/documents_page.dart';
import '../features/finance/finance_home.dart';
import '../features/finance/finance_scope.dart';
import '../features/habits/habits_home.dart';
import '../features/habits/habits_scope.dart';
import '../features/health/presentation/health_home_screen.dart';
import '../features/medicines/pages/medicine_list_page.dart';
import '../features/notifications/screens/notification_settings_screen.dart';
import '../features/notifications/screens/reminders_screen.dart';
import '../features/planner/screens/home_screen.dart' as planner;
import '../features/profile/profile_screen.dart';
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
  int _lastTab = 0;
  bool _booted = false;
  bool _quickAddOpen = false;

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
    // Providers live at the app root (BlistraApp, above MaterialApp) so that
    // module routes pushed on the root Navigator resolve the same instances.
    // The shell only owns the tab scaffold.
    return _buildScaffold(context);
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
              onDestinationSelected: _onSelect,
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
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _BlistraBottomBar(
        index: _index,
        onSelect: _onSelect,
        addOpen: _quickAddOpen,
      ),
    );
  }

  void _onSelect(int i) {
    if (i == 2) {
      _openQuickAdd(context);
      return;
    }
    _lastTab = i == 2 ? _lastTab : i;
    setState(() => _index = i);
    if (i == 0) {
      // Home re-opens: refresh so records created in other modules appear.
      // ignore: discarded_futures
      _d.dashboard.refresh(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    }
    if (i == 1) {
      // Planner re-opens: reload the date-navigable schedule plus the
      // planner-owned today view so cross-module rows (medicines, habits,
      // meals) reflect the latest dashboard payload.
      // ignore: discarded_futures
      _d.planner.loadSchedule();
      // ignore: discarded_futures
      _d.planner.loadToday();
    }
  }

  /// Global Quick Add: one premium overlay for every tab. Actions route to
  /// the owning module's existing creation flow; the overlay closes first so
  /// the center button returns to "+" before navigation.
  Future<void> _openQuickAdd(BuildContext context) async {
    if (_quickAddOpen) return;
    setState(() => _quickAddOpen = true);
    final selected = await showQuickAdd(context);
    if (!mounted) return;
    setState(() => _quickAddOpen = false);
    if (selected != null) {
      goToTab(selected.tab);
    }
  }

  /// Homepage.png destinations: Home, Planner, Add, Modules, Profile.
  List<_Tab> get _tabs => const [
        _Tab('Home', Icons.home_outlined, Icons.home),
        _Tab('Planner', Icons.calendar_today_outlined, Icons.calendar_today),
        _Tab('Add', Icons.add, Icons.add),
        _Tab('Modules', Icons.grid_view_outlined, Icons.grid_view_rounded),
        _Tab('Profile', Icons.person_outline, Icons.person),
      ];

  void goToTab(int index) {
    if (index == 2) {
      _openQuickAdd(context);
      return;
    }
    if (index < 0 || index >= _tabs.length) return;
    setState(() => _index = index);
    if (index == 0) {
      // ignore: discarded_futures
      _d.dashboard.refresh(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    }
    if (index == 1) {
      // ignore: discarded_futures
      _d.planner.loadSchedule();
      // ignore: discarded_futures
      _d.planner.loadToday();
    }
  }

  List<Widget> _pages() => [
        DashboardScreen(onNavigate: goToTab),
        const planner.HomeScreen(),
        const SizedBox.shrink(), // index 2 = Add action, no page
        _MoreTab(
          onLogout: () => _d.authState.logout(),
          onRefreshNotifications: _refreshNotifications,
          dietController: _d.diet,
          habitsController: _d.habits,
          onNavigatePrimary: goToTab,
        ),
        const ProfileScreen(),
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
    // Same visual language as Home/Planner: warm off-white, deep ink type,
    // teal accent, soft semantic tiles, generous spacing.
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: const Text(
          'Modules',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        backgroundColor: const Color(0xFFFFFBF6),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => onLogout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          const Text(
            'Your life, organized',
            style: TextStyle(fontSize: 14.5, color: Color(0xFF8A94A6)),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              _ModuleCard(
                color: const Color(0xFFFFECEC),
                iconBg: const Color(0xFFFFD9D9),
                iconColor: const Color(0xFFE5484D),
                icon: Icons.favorite_outline,
                title: 'Health',
                subtitle: 'Activity, sleep, measurements',
                onTap: () => _openHealth(context),
              ),
              _ModuleCard(
                color: const Color(0xFFEAF5FF),
                iconBg: Colors.white,
                iconColor: const Color(0xFF3E9BE9),
                icon: Icons.medication_outlined,
                title: 'Medicines',
                subtitle: 'Schedules, doses, refills',
                onTap: () => pushModulePage(
                  context,
                  const MedicineListPage(),
                  title: 'Medicines',
                ),
              ),
              _ModuleCard(
                color: const Color(0xFFEDF9E8),
                iconBg: const Color(0xFFD9F0D2),
                iconColor: const Color(0xFF3E8E41),
                icon: Icons.restaurant_outlined,
                title: 'Diet',
                subtitle: 'Meals, water, nutrition',
                onTap: () => pushModulePage(
                  context,
                  const diet.TodayScreen(),
                  title: 'Diet',
                ),
              ),
              _ModuleCard(
                color: const Color(0xFFF1EAFE),
                iconBg: const Color(0xFFDCCBFF),
                iconColor: const Color(0xFF7C3AED),
                icon: Icons.check_circle_outline,
                title: 'Habits',
                subtitle: 'Streaks, daily progress',
                onTap: () => _openHabits(context),
              ),
              _ModuleCard(
                color: const Color(0xFFE9F8F1),
                iconBg: const Color(0xFFC9EBDD),
                iconColor: const Color(0xFF0C6B6B),
                icon: Icons.account_balance_wallet_outlined,
                title: 'Finance',
                subtitle: 'Expenses, accounts, transactions',
                onTap: () => _openFinance(context),
              ),
              _ModuleCard(
                color: const Color(0xFFFFF4E3),
                iconBg: const Color(0xFFFFE3B3),
                iconColor: const Color(0xFFE8890C),
                icon: Icons.folder_outlined,
                title: 'Documents',
                subtitle: 'Files, reports, PDFs',
                onTap: () => pushModulePage(
                  context,
                  const DocumentsPage(),
                  title: 'Documents',
                ),
              ),
              _ModuleCard(
                color: const Color(0xFFF1F4F6),
                iconBg: Colors.white,
                iconColor: const Color(0xFF3E4A5A),
                icon: Icons.notifications_outlined,
                title: 'Reminders',
                subtitle: 'Alerts and schedules',
                onTap: () => pushModulePage(
                  context,
                  RemindersScreen(onRefresh: onRefreshNotifications),
                  title: 'Reminders',
                  ownAppBar: false,
                ),
              ),
              _ModuleCard(
                color: const Color(0xFFF1F4F6),
                iconBg: Colors.white,
                iconColor: const Color(0xFF3E4A5A),
                icon: Icons.settings_outlined,
                title: 'Notifications',
                subtitle: 'Preferences and devices',
                onTap: () => pushModulePage(
                  context,
                  NotificationSettingsScreen(
                      onRefresh: onRefreshNotifications),
                  title: 'Notifications',
                  ownAppBar: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openHealth(BuildContext context) {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final repo = shell?._d.health;
    if (repo == null) return;
    pushModulePage(
      context,
      HealthHomeScreen(
        repository: repo,
        onLogout: () => onLogout(),
      ),
      title: 'Health',
    );
  }

  void _openFinance(BuildContext context) {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    final ctrl = shell?._d.finance;
    if (ctrl == null) return;
    pushModulePage(
      context,
      FinanceScope(controller: ctrl, child: const FinanceHome()),
      title: 'Finance',
    );
  }

  void _openHabits(BuildContext context) {
    // HabitsHome reads HabitsScope; provide it explicitly for the pushed route.
    pushModulePage(
      context,
      HabitsScope(controller: habitsController, child: const HabitsHome()),
      title: 'Habits',
    );
  }
}

/// Rounded module card in the Home design language.
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.color,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF3E5A6B),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Text(
                  'Open',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C6B6B),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Color(0xFF0C6B6B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded bottom bar replica from Homepage.png:
/// Home | Planner | (big +) | Modules | Profile.
class _BlistraBottomBar extends StatelessWidget {
  const _BlistraBottomBar(
      {required this.index, required this.onSelect, this.addOpen = false});

  final int index;
  final void Function(int) onSelect;
  final bool addOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BarItem(
            label: 'Home',
            icon: Icons.home,
            selected: index == 0,
            onTap: () => onSelect(0),
          ),
          _BarItem(
            label: 'Planner',
            icon: Icons.calendar_today_outlined,
            selected: index == 1,
            onTap: () => onSelect(1),
          ),
          GestureDetector(
            onTap: () => onSelect(2),
            child: Semantics(
              label: addOpen ? 'Close quick add' : 'Add',
              button: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF0E8A8A), Color(0xFF0A5656)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          RotationTransition(
                        turns: animation.drive(Tween(
                            begin: 0.25, end: 0.0)),
                        child: FadeTransition(
                            opacity: animation, child: child),
                      ),
                      child: Icon(
                        addOpen ? Icons.close : Icons.add,
                        key: ValueKey(addOpen),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(addOpen ? 'Close' : 'Add',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF667085))),
                ],
              ),
            ),
          ),
          _BarItem(
            label: 'Modules',
            icon: Icons.grid_view_rounded,
            selected: index == 3,
            onTap: () => onSelect(3),
          ),
          _BarItem(
            label: 'Profile',
            icon: Icons.person_outline,
            selected: index == 4,
            onTap: () => onSelect(4),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFF0C6B6B) : const Color(0xFF98A2B3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }
}


