import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import '../planner_controller.dart';
import 'events_screen.dart';
import 'lists_screen.dart';
import 'tasks_screen.dart';
import 'today_screen.dart';

/// Planner tab of the app shell: one header, one pill tab switcher.
///
/// The application bottom navigation is owned by [AppShell]; this screen must
/// not add a second bottom navigation bar, a second global Add button, or any
/// account actions (logout lives in Profile). Today/Tasks/Lists/Events switch
/// via the pill switcher under the single header.
///
/// Visual language matches Home: warm off-white background, deep ink type,
/// teal accent, rounded cards, generous whitespace.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _teal = Color(0xFF0C6B6B);
  static const _cream = Color(0xFFFFFBF6);

  late final TabController _tabs;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _searchCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) {
      _loadForTab(AppScope.of(context).planner, _tabs.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final planner = scope.planner;
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, planner),
            if (_searching) _searchField(planner),
            _pillSwitcher(planner),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  TodayScreen(),
                  TasksScreen(),
                  ListsScreen(),
                  EventsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Single Planner header. Planner-relevant actions only: search + calendar.
  // No account/logout menu — that belongs to Profile.
  Widget _header(BuildContext context, PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planner',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Color(0xFF101828),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your day, organized.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          _HeaderButton(
            icon: _searching ? Icons.close : Icons.search,
            tooltip: 'Search',
            onTap: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchCtrl.clear();
                planner.setSearchQuery('');
              }
            },
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: Icons.calendar_today_outlined,
            tooltip: 'Pick a date',
            onTap: () => _pickDate(context, planner),
          ),
        ],
      ),
    );
  }

  Widget _searchField(PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search tasks, events, lists',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: planner.setSearchQuery,
      ),
    );
  }

  Widget _pillSwitcher(PlannerController planner) {
    const tabs = [
      (Icons.today_outlined, 'Today'),
      (Icons.check_circle_outline, 'Tasks'),
      (Icons.checklist_outlined, 'Lists'),
      (Icons.event_outlined, 'Events'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) => Row(
            children: [
              for (int i = 0; i < tabs.length; i++)
                Expanded(child: _pill(i, tabs[i].$1, tabs[i].$2, planner)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(
      int index, IconData icon, String label, PlannerController planner) {
    final selected = _tabs.index == index;
    return InkWell(
      onTap: () {
        _tabs.animateTo(index);
        _loadForTab(planner, index);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _teal : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17,
                color: selected ? Colors.white : const Color(0xFF667085)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(
      BuildContext context, PlannerController planner) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: planner.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      await planner.selectDate(picked);
      // Jump to Today tab so the picked date's schedule is visible.
      _tabs.animateTo(0);
    }
  }

  void _loadForTab(PlannerController planner, int index) {
    switch (index) {
      case 0:
        planner.loadToday();
        planner.loadSchedule();
      case 1:
        planner.loadTasks();
      case 2:
        planner.loadTaskLists();
      case 3:
        planner.loadEvents();
    }
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton(
      {required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 22, color: const Color(0xFF3E4A5A)),
      ),
    );
  }
}
