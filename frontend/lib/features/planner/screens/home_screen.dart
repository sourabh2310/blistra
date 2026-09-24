import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/app_scope.dart';
import '../models/schedule_view.dart';
import '../planner_controller.dart';
import 'event_detail_screen.dart';
import 'events_screen.dart';
import 'list_detail_screen.dart';
import 'lists_screen.dart';
import 'task_detail_screen.dart';
import 'tasks_screen.dart';
import 'today_screen.dart';

enum PlannerSection { today, tasks, lists, events }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialSection = PlannerSection.today});

  final PlannerSection initialSection;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  bool _searching = false;


  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: PlannerSection.values.length, vsync: this, initialIndex: widget.initialSection.index);
    _tabs.addListener(_tabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSection(widget.initialSection));
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _showSection(widget.initialSection);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _tabChanged() {
    if (!_tabs.indexIsChanging) _loadSection(PlannerSection.values[_tabs.index]);
  }

  void _showSection(PlannerSection section) {
    if (_tabs.index == section.index) {
      _loadSection(section);
      return;
    }
    _tabs.animateTo(section.index);
  }

  Future<void> _loadSection(PlannerSection section) async {
    final planner = AppScope.of(context).planner;

    switch (section) {
      case PlannerSection.today:
        await Future.wait([planner.loadSchedule(), planner.loadToday()]);
        return;
      case PlannerSection.tasks:
        await Future.wait([planner.loadTasks(), planner.loadTaskLists()]);
        return;
      case PlannerSection.lists:
        await planner.loadTaskLists();
        return;
      case PlannerSection.events:
        await planner.loadEvents();
        return;
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, planner),
            if (_searching) _searchField(planner),
            Expanded(
              child: _searching
                  ? _searchResults(context, planner)
                  : Column(
                      children: [
                        _sectionTabs(),
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
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Planner', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                const SizedBox(height: 2),
                Text('What needs doing and what is happening.', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          _HeaderButton(
            tooltip: _searching ? 'Close Planner search' : 'Search Planner',
            icon: _searching ? Icons.close : Icons.search,
            onTap: () => _toggleSearch(context, planner),
          ),
          const SizedBox(width: 6),
          _HeaderButton(
            tooltip: 'Choose date',
            icon: Icons.calendar_today_outlined,
            onTap: () => _pickDate(context, planner),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<_MoreAction>(
            tooltip: 'More Planner actions',
            icon: const Icon(Icons.more_horiz),
            onSelected: (action) => _handleMore(planner, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _MoreAction.today, child: Text('Jump to today')),
              PopupMenuItem(value: _MoreAction.toggleScope, child: Text('Switch day or week')),
              PopupMenuItem(value: _MoreAction.clearSearch, child: Text('Clear Planner search')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSearch(BuildContext context, PlannerController planner) async {
    if (_searching) {
      setState(() => _searching = false);
      _searchController.clear();
      planner.setSearchQuery('');
      return;
    }
    setState(() => _searching = true);
    await Future.wait([
      planner.loadTasks(),
      planner.loadEvents(),
      planner.loadTaskLists(),
    ]);
  }

  Widget _searchField(PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search Planner tasks, events and lists',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: planner.setSearchQuery,
      ),
    );
  }

  Widget _sectionTabs() {
    const tabs = [
      (Icons.today_outlined, 'Today'),
      (Icons.check_circle_outline, 'Tasks'),
      (Icons.checklist_outlined, 'Lists'),
      (Icons.event_outlined, 'Events'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) => Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: _tabs.index == index,
                    label: tabs[index].$2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showSection(PlannerSection.values[index]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _tabs.index == index ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tabs[index].$1, size: 17, color: _tabs.index == index ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                tabs[index].$2,
                                maxLines: 1,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _tabs.index == index ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchResults(BuildContext context, PlannerController planner) {
    final query = planner.searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Search only within Planner-owned tasks, events and lists.')));
    }
    final tasks = planner.tasks.where((task) => _matches(task.title, task.description, task.taskListName, query)).toList();
    final events = planner.events.where((event) => _matches(event.title, event.description, event.location, query)).toList();
    final lists = planner.taskLists.where((list) => _matches(list.name, list.description, null, query)).toList();
    if (tasks.isEmpty && events.isEmpty && lists.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No Planner items match your search.')));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        if (tasks.isNotEmpty) _searchSection('Tasks', tasks.length),
        for (final task in tasks)
          _SearchResult(
            icon: Icons.task_alt,
            title: task.title,
            subtitle: 'Task',
            onTap: () => _openTask(context, planner, task.id),
          ),
        if (events.isNotEmpty) _searchSection('Events', events.length),
        for (final event in events)
          _SearchResult(
            icon: Icons.event,
            title: event.title,
            subtitle: 'Event',
            onTap: () => _openEvent(context, planner, event.id),
          ),
        if (lists.isNotEmpty) _searchSection('Lists', lists.length),
        for (final list in lists)
          _SearchResult(
            icon: Icons.checklist_rtl,
            title: list.name,
            subtitle: 'List',
            onTap: () => _openList(context, planner, list.id),
          ),
      ],
    );
  }

  Widget _searchSection(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text('$label · $count', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  bool _matches(String title, String? description, String? location, String query) {
    return title.toLowerCase().contains(query) ||
        (description?.toLowerCase().contains(query) ?? false) ||
        (location?.toLowerCase().contains(query) ?? false);
  }

  Future<void> _openTask(BuildContext context, PlannerController planner, String id) async {
    setState(() => _searching = false);
    _searchController.clear();
    planner.setSearchQuery('');
    _showSection(PlannerSection.tasks);
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => TaskDetailScreen(planner: planner, taskId: id)));
  }

  Future<void> _openEvent(BuildContext context, PlannerController planner, String id) async {
    setState(() => _searching = false);
    _searchController.clear();
    planner.setSearchQuery('');
    _showSection(PlannerSection.events);
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => EventDetailScreen(planner: planner, eventId: id)));
  }

  Future<void> _openList(BuildContext context, PlannerController planner, String id) async {
    setState(() => _searching = false);
    _searchController.clear();
    planner.setSearchQuery('');
    _showSection(PlannerSection.lists);
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ListDetailScreen(planner: planner, listId: id)));
  }

  Future<void> _pickDate(BuildContext context, PlannerController planner) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: planner.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await planner.selectDate(picked);
    _showSection(PlannerSection.today);
  }

  void _handleMore(PlannerController planner, _MoreAction action) {
    switch (action) {
      case _MoreAction.today:
        planner.goToToday();
        _showSection(PlannerSection.today);
        return;
      case _MoreAction.toggleScope:
        final week = planner.scope.name == 'week';
        planner.setScope(week ? ScheduleScope.day : ScheduleScope.week);
        _showSection(PlannerSection.today);
        return;
      case _MoreAction.clearSearch:
        _searchController.clear();
        planner.setSearchQuery('');
        return;
    }
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(46, 46),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      ),
      icon: Icon(icon),
    );
  }
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

enum _MoreAction { today, toggleScope, clearSearch }
