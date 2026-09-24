/// Blistra application shell: single navigation strategy for all features.
///
/// Bottom navigation is user-customizable (max 5, HOME + ADD mandatory) and
/// persisted per user via [PreferencesController]. Profile is never a tab —
/// it opens from the Home avatar. Every feature tab is mounted once
/// (IndexedStack) so per-feature state survives tab switches. Feature
/// controllers are exposed via [AppScope] (dashboard/planner/session) and
/// `provider` (everything else).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/routing/routes.dart';
import '../core/widgets/module_guard.dart';
import '../core/widgets/quick_add.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/diet/screens/today_screen.dart' as diet;
import '../features/documents/documents_page.dart';
import '../features/documents/document_detail_page.dart';
import '../features/documents/providers/documents_provider.dart';
import '../features/finance/finance_home.dart';
import '../features/finance/finance_scope.dart';
import '../features/habits/habits_home.dart';
import '../features/habits/habits_scope.dart';
import '../features/habits/screens/habit_detail_screen.dart';
import '../features/health/presentation/health_home_screen.dart';
import '../features/hub/hub_screen.dart';
import '../features/diet/screens/meal_detail_screen.dart';
import '../features/medicines/pages/medicine_detail_page.dart';
import '../features/medicines/pages/medicine_list_page.dart';
import '../features/notifications/screens/reminders_screen.dart';
import '../features/preferences/screens/customize_nav_screen.dart';
import '../features/preferences/shell_destinations.dart';
import '../features/planner/models/task_view.dart';
import '../features/planner/screens/home_screen.dart' as planner;
import '../features/planner/screens/planner_search_detail_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/search/search_api.dart';
import 'app_dependencies.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.deps});

  final AppDependencies deps;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedDestination = ShellDestinations.home;
  planner.PlannerSection _plannerSection = planner.PlannerSection.today;
  bool _booted = false;
  bool _quickAddOpen = false;

  AppDependencies get _d => widget.deps;

  /// Stable preference owner: backend user id, falling back to email.
  /// Server data is keyed by user id, so email changes never orphan prefs.
  String get _prefsOwner {
    final id = _d.authState.account?.id;
    if (id != null && id.isNotEmpty) return id;
    return _d.authState.userEmail;
  }

  @override
  void initState() {
    super.initState();
    _d.authState.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bind preferences to the signed-in user (cached first, backend next).
    // ignore: discarded_futures
    _d.preferences.bindUser(_prefsOwner);
  }

  @override
  void dispose() {
    _d.authState.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    // Login/logout switches the preference owner; per-user server data +
    // per-user local cache keep configurations independent.
    // ignore: discarded_futures
    _d.preferences.bindUser(_prefsOwner);
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
    try {
      await _d.syncService.refresh();
    } catch (_) {
    }
  }

  Future<void> _refreshNotifications() async {
    await _d.reminders.load();
    await _d.settings.load();
  }

  /// Current bottom-navigation destinations (HOME + ADD mandatory, max 5).
  List<String> get _destinations {
    try {
      return ShellDestinations.normalizeNav(_d.preferences.bottomNav);
    } catch (_) {
      return List.of(ShellDestinations.defaults);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Providers live at the app root (BlistraApp, above MaterialApp) so that
    // module routes pushed on the root Navigator resolve the same instances.
    // The shell only owns the tab scaffold; it rebuilds when preferences
    // change so navigation customization applies immediately.
    return ListenableBuilder(
      listenable: _d.preferences,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final wide = MediaQuery.widthOf(context) >= 900;
    final destinations = _destinations;
    final pages = _pages(destinations);
    var selected = destinations.indexOf(_selectedDestination);
    if (selected < 0) selected = destinations.indexOf(ShellDestinations.home);
    if (selected < 0) selected = 0;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (i) => _onSelect(destinations, i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final id in destinations)
                  NavigationRailDestination(
                    icon: Icon(id == ShellDestinations.add
                        ? Icons.add_circle_outline
                        : ShellDestinations.icon(id)),
                    selectedIcon: Icon(id == ShellDestinations.add
                        ? Icons.add_circle
                        : ShellDestinations.selectedIcon(id)),
                    label: Text(ShellDestinations.label(id)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
                child: IndexedStack(index: selected, children: pages)),
          ],
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: _BlistraBottomBar(
        destinations: destinations,
        index: selected,
        onSelect: (i) => _onSelect(destinations, i),
        addOpen: _quickAddOpen,
      ),
    );
  }

  void _onSelect(List<String> destinations, int i) {
    final id = destinations[i];
    if (id == ShellDestinations.add) {
      _openQuickAdd(context);
      return;
    }
    setState(() => _selectedDestination = id);
    _refreshForDestination(id);
  }

  /// Central destination router: tab-select when pinned, otherwise push the
  /// owning screen. Used by Home, Hub, search results and customization.
  void goToDestination(String rawId) {
    final parts = rawId.trim().split('/');
    final id = parts.first.toUpperCase();
    if (id == ShellDestinations.add) {
      _openQuickAdd(context);
      return;
    }
    if (id == 'PROFILE') {
      _openProfile();
      return;
    }
    if (id == ShellDestinations.planner) {
      final requested = parts.length > 1 ? parts[1].toLowerCase() : 'today';
      final section = switch (requested) {
        'task' || 'tasks' => planner.PlannerSection.tasks,
        'list' || 'lists' => planner.PlannerSection.lists,
        'event' || 'events' => planner.PlannerSection.events,
        _ => planner.PlannerSection.today,
      };
      if (section == planner.PlannerSection.tasks &&
          parts.length > 2 &&
          parts[2].toUpperCase() == 'TODAY') {
        _d.planner.selectTaskView(TaskView.today);
      }
      _showPlanner(section);
      if (parts.length >= 3 &&
          const {'task', 'event', 'list'}.contains(parts[1].toLowerCase())) {
        final route = 'planner/${parts[1].toLowerCase()}/${parts[2]}';
        pushModulePage(
          context,
          PlannerSearchDetailScreen(route: route),
          title: 'Planner details',
        );
      }
      return;
    }
    if (id == ShellDestinations.medicines && parts.length >= 2) {
      final tabIndex = _destinations.indexOf(ShellDestinations.medicines);
      if (tabIndex >= 0) {
        setState(() => _selectedDestination = ShellDestinations.medicines);
        _refreshForDestination(ShellDestinations.medicines);
      }
      pushModulePage(
        context,
        MedicineDetailPage(medicineId: parts[1]),
        title: 'Medicine details',
      );
      return;
    }
    if (id == ShellDestinations.habits &&
        parts.length > 1 &&
        parts[1].toUpperCase() != 'STATS') {
      final tabIndex = _destinations.indexOf(ShellDestinations.habits);
      if (tabIndex >= 0) {
        setState(() => _selectedDestination = ShellDestinations.habits);
      }
      pushModulePage(
        context,
        HabitsScope(
          controller: _d.habits,
          child: HabitDetailScreen(habitId: parts[1]),
        ),
        title: 'Habit details',
      );
      return;
    }
    if (id == ShellDestinations.habits &&
        parts.length > 1 &&
        parts[1].toUpperCase() == 'STATS') {
      final tabIndex = _destinations.indexOf(ShellDestinations.habits);
      if (tabIndex >= 0) {
        setState(() => _selectedDestination = ShellDestinations.habits);
      }
      pushModulePage(
        context,
        HabitsScope(
          controller: _d.habits,
          child: const HabitsHome(initialTab: 2),
        ),
        title: 'Habit statistics',
      );
      return;
    }
    if (id == ShellDestinations.diet && parts.length >= 3 && parts[1].toUpperCase() == 'MEAL') {
      final tabIndex = _destinations.indexOf(ShellDestinations.diet);
      if (tabIndex >= 0) {
        setState(() => _selectedDestination = ShellDestinations.diet);
        _refreshForDestination(ShellDestinations.diet);
      }
      pushModulePage(
        context,
        MealDetailScreen(mealId: parts[2]),
        title: 'Meal details',
      );
      return;
    }
    final destinations = _destinations;
    final tabIndex = destinations.indexOf(id);
    if (tabIndex >= 0) {
      setState(() => _selectedDestination = id);
      _refreshForDestination(id);
      return;
    }
    _pushDestination(id);
  }

  void _showPlanner(planner.PlannerSection section) {
    final destinations = _destinations;
    final tabIndex = destinations.indexOf(ShellDestinations.planner);
    if (tabIndex >= 0) {
      setState(() {
        _selectedDestination = ShellDestinations.planner;
        _plannerSection = section;
      });
      _refreshForDestination(ShellDestinations.planner);
      return;
    }
    pushModulePage(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Planner')),
        body: planner.HomeScreen(initialSection: section),
      ),
      title: 'Planner',
    );
  }

  void _refreshForDestination(String id) {
    if (id == ShellDestinations.home) {
      // Home re-opens: refresh so records created in other modules appear.
      // ignore: discarded_futures
      _d.dashboard.refresh(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    }
    if (id == ShellDestinations.planner) {
      // Planner re-opens: reload the date-navigable schedule plus the
      // planner-owned today view so cross-module rows reflect the latest
      // dashboard payload.
      // ignore: discarded_futures
      _d.planner.loadSchedule();
      // ignore: discarded_futures
      _d.planner.loadToday();
    }
  }

  void _pushDestination(String id) {
    switch (id) {
      case ShellDestinations.home:
        setState(() => _selectedDestination = ShellDestinations.home);
        return;
      case ShellDestinations.planner:
        pushModulePage(
          context,
          Scaffold(
            appBar: AppBar(title: const Text('Planner')),
            body: planner.HomeScreen(initialSection: _plannerSection),
          ),
          title: 'Planner',
        );
        return;
      case ShellDestinations.hub:
        _openHub();
        return;
      case ShellDestinations.health:
        pushModulePage(
          context,
          HealthHomeScreen(
            repository: _d.health,
            onLogout: () => _d.authState.logout(),
          ),
          title: 'Health',
        );
        return;
      case ShellDestinations.medicines:
        pushModulePage(context, const MedicineListPage(),
            title: 'Medicines');
        return;
      case ShellDestinations.diet:
        pushModulePage(context, const diet.TodayScreen(), title: 'Diet');
        return;
      case ShellDestinations.habits:
        pushModulePage(
          context,
          HabitsScope(controller: _d.habits, child: const HabitsHome()),
          title: 'Habits',
        );
        return;
      case ShellDestinations.finance:
        pushModulePage(
          context,
          FinanceScope(controller: _d.finance, child: const FinanceHome()),
          title: 'Finance',
        );
        return;
      default:
        _openHub();
        return;
    }
  }

  /// Global Quick Add: one premium overlay for every tab. Actions route to
  /// the owning module's existing creation flow; the overlay closes first so
  /// the center button returns to "+" before navigation. Failures never leave
  /// the button stuck: state resets in a finally block.
  Future<void> _openQuickAdd(BuildContext context) async {
    if (_quickAddOpen) return;
    setState(() => _quickAddOpen = true);
    QuickAddAction? selected;
    try {
      selected = await showQuickAdd(context);
    } finally {
      if (mounted) setState(() => _quickAddOpen = false);
    }
    if (!mounted || selected == null) return;
    // Open the existing domain creation flow. Each flow owns its errors and
    // dashboard refresh is quiet + non-blocking (see openQuickAddCreation).
    await openQuickAddCreation(context, selected);
  }

  void _openProfile() {
    pushModulePage(context, const ProfileScreen(), title: 'Profile');
  }

  void _openHub() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HubScreen(
          onDestination: goToDestination,
          onRefreshNotifications: _refreshNotifications,
          onCustomizeNavigation: _openCustomizeNav,
        ),
      ),
    );
  }

  void _openSearch() {
    final apiClient = context.read<ApiClient>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          api: SearchApi(apiClient),
          onOpenRoute: _openSearchRoute,
        ),
      ),
    );
  }

  /// Search result routing through the real route contract: switch to the
  /// owning tab when pinned (or push the module), then push the detail page.
  Future<void> _openSearchRoute(String route) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    final dest = AppRoutes.resolveSearchRoute(route);
    if (route.startsWith('planner/')) {
      final parts = route.split('/');
      final type = parts.length > 1 ? parts[1] : '';
      _plannerSection = switch (type) {
        'task' => planner.PlannerSection.tasks,
        'event' => planner.PlannerSection.events,
        'list' => planner.PlannerSection.lists,
        _ => _plannerSection,
      };
    }
    if (dest.documentId != null) {
      final document = await context.read<DocumentsProvider>().getById(dest.documentId!);
      if (!context.mounted) return;
      if (document != null) {
        pushModulePage(
          context,
          DocumentDetailPage(document: document),
          title: 'Document details',
        );
      } else {
        pushModulePage(context, const DocumentsPage(), title: 'Documents');
      }
      return;
    }
    final tab = dest.tab;
    if (tab != null) {
      if (tab == AppTab.planner) {
        _showPlanner(_plannerSection);
      } else {
        goToDestination(switch (tab) {
          AppTab.dashboard => ShellDestinations.home,
          AppTab.planner => ShellDestinations.home,
          AppTab.health => ShellDestinations.health,
          AppTab.medicines => ShellDestinations.medicines,
          AppTab.diet => ShellDestinations.diet,
          AppTab.habits => ShellDestinations.habits,
          AppTab.finance => ShellDestinations.finance,
        });
      }
    }
    final detail = dest.detail;
    if (detail != null) {
      // Habit detail requires an explicit scope outside HabitsHome.
      final page = route.startsWith('habits/')
          ? HabitsScope(controller: _d.habits, child: Builder(builder: detail))
          : Builder(builder: detail);
      pushModulePage(context, page, title: 'Details');
    }
  }

  void _openNotifications() {
    pushModulePage(
      context,
      RemindersScreen(onRefresh: _refreshNotifications),
      title: 'Reminders',
      ownAppBar: false,
    );
  }

  void _openCustomizeNav() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomizeNavScreen()),
    );
  }

  List<Widget> _pages(List<String> destinations) => [
        for (final id in destinations) _pageFor(id),
      ];

  Widget _pageFor(String id) {
    switch (id) {
      case ShellDestinations.home:
        return DashboardScreen(
          onDestination: goToDestination,
          onSearch: _openSearch,
          onNotifications: _openNotifications,
          onProfile: _openProfile,
          hubPinned: _destinations.contains(ShellDestinations.hub),
          homeWidgets: _d.preferences.homeWidgets,
        );
      case ShellDestinations.planner:
        return planner.HomeScreen(initialSection: _plannerSection);
      case ShellDestinations.add:
        return const SizedBox.shrink(); // Add action, no page
      case ShellDestinations.hub:
        return HubScreen(
          onDestination: goToDestination,
          onRefreshNotifications: _refreshNotifications,
          onCustomizeNavigation: _openCustomizeNav,
        );
      case ShellDestinations.health:
        return HealthHomeScreen(
          repository: _d.health,
          onLogout: () => _d.authState.logout(),
        );
      case ShellDestinations.medicines:
        return const MedicineListPage();
      case ShellDestinations.diet:
        return const diet.TodayScreen();
      case ShellDestinations.habits:
        return HabitsScope(
            controller: _d.habits, child: const HabitsHome());
      case ShellDestinations.finance:
        return FinanceScope(
            controller: _d.finance, child: const FinanceHome());
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Rounded bottom bar: Home | Planner | (prominent Add) | … | Hub, driven by
/// the user's saved destinations (max 5, Home + Add mandatory).
class _BlistraBottomBar extends StatelessWidget {
  const _BlistraBottomBar({
    required this.destinations,
    required this.index,
    required this.onSelect,
    this.addOpen = false,
  });

  final List<String> destinations;
  final int index;
  final void Function(int) onSelect;
  final bool addOpen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xFFF0F2F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B2B28).withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 1,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            children: [
              for (int i = 0; i < destinations.length; i++)
                if (destinations[i] == ShellDestinations.add)
                  SizedBox(
                    width: 72,
                    child: _AddButton(open: addOpen, onTap: () => onSelect(i)),
                  )
                else
                  Expanded(
                    child: _BarItem(
                      label: ShellDestinations.label(destinations[i]),
                      icon: ShellDestinations.icon(destinations[i]),
                      selectedIcon:
                          ShellDestinations.selectedIcon(destinations[i]),
                      selected: index == i,
                      onTap: () => onSelect(i),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Add',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Transform.translate(
          offset: const Offset(0, -8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF087D70), Color(0xFF07584F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A665A).withValues(alpha: 0.24),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Icon(
                open ? Icons.close : Icons.add,
                key: ValueKey(open),
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color selectedColor = Color(0xFF07594F);
    const Color unselectedColor = Color(0xFF66758A);
    final Color color = selected ? selectedColor : unselectedColor;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 190),
                curve: Curves.easeOutCubic,
                height: 44,
                constraints: const BoxConstraints(minWidth: 54),
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 10 : 4,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE5F2EE)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: selected
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(selectedIcon, color: color, size: 22),
                          const SizedBox(height: 1),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: selectedColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : Icon(icon, color: color, size: 24),
              ),
              if (!selected) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: unselectedColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              SizedBox(
                height: 6,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 5, height: 5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
