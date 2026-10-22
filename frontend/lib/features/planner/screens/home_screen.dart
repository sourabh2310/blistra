import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../../../features/app_scope.dart';
import '../models/schedule_view.dart';
import '../planner_controller.dart';
import '../widgets/event_card.dart';
import 'event_detail_screen.dart';
import 'events_screen.dart';
import 'list_detail_screen.dart';
import 'lists_screen.dart';
import 'task_detail_screen.dart';
import 'tasks_screen.dart';
import 'today_screen.dart';

/// Planner tabs. Names are kept for deep links: [tasks] is the Upcoming tab
/// and [events] is the Calendar tab.
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
        await Future.wait([planner.loadSchedule(), planner.loadToday(), planner.loadTaskLists()]);
        return;
      case PlannerSection.tasks:
        await Future.wait([planner.loadTasks(), planner.loadTaskLists(), planner.loadEvents()]);
        return;
      case PlannerSection.lists:
        await planner.loadTaskLists();
        return;
      case PlannerSection.events:
        await Future.wait([planner.loadEvents(), planner.loadTasks()]);
        return;
    }
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
                  ? ListenableBuilder(
                      listenable: planner,
                      builder: (context, _) => _searchResults(context, planner),
                    )
                  : Column(
                      children: [
                        AnimatedBuilder(
                          animation: _tabs,
                          builder: (context, _) => BlistraSegmentedTabs(
                            labels: const ['Today', 'Upcoming', 'Lists', 'Calendar'],
                            selected: _tabs.index,
                            onSelected: (index) => _showSection(PlannerSection.values[index]),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              TodayScreen(onShowLists: () => _showSection(PlannerSection.lists)),
                              const TasksScreen(),
                              const ListsScreen(),
                              const EventsScreen(),
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
    return BlistraPageHeader(
      title: 'Planner',
      actions: [
        GlassIconButton(
          tooltip: _searching ? 'Close Planner search' : 'Search Planner',
          icon: _searching ? Icons.close_rounded : Icons.search_rounded,
          onTap: () => _toggleSearch(context, planner),
        ),
        PopupMenuButton<_MoreAction>(
          tooltip: 'More Planner actions',
          onSelected: (action) => _handleMore(context, planner, action),
          itemBuilder: (context) => [
            const PopupMenuItem(value: _MoreAction.chooseDate, child: Text('Choose date')),
            const PopupMenuItem(value: _MoreAction.today, child: Text('Jump to today')),
            PopupMenuItem(
              value: _MoreAction.toggleScope,
              child: Text(planner.scope == ScheduleScope.week ? 'Show one day' : 'Show the week'),
            ),
            const PopupMenuItem(value: _MoreAction.clearSearch, child: Text('Clear Planner search')),
          ],
          child: const IgnorePointer(
            child: GlassIconButton(
              tooltip: null,
              icon: Icons.more_horiz,
              onTap: null,
            ),
          ),
        ),
      ],
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
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 8, kPageGutter, 0),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 14, color: colors.text),
          decoration: InputDecoration(
            hintText: 'Search tasks, events and lists',
            hintStyle: TextStyle(color: colors.muted),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            icon: Icon(Icons.search_rounded, size: 19, color: colors.muted),
          ),
          onChanged: planner.setSearchQuery,
        ),
      ),
    );
  }

  Widget _searchResults(BuildContext context, PlannerController planner) {
    final colors = BlistraColors.resolve(context);
    final query = planner.searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(kPageGutter, 16, kPageGutter, 110),
        children: const [EmptyCard(message: 'Search only within Planner-owned tasks, events and lists.')],
      );
    }
    final tasks = planner.tasks.where((task) => _matches(task.title, task.description, task.taskListName, query)).toList();
    final events = planner.events.where((event) => _matches(event.title, event.description, event.location, query)).toList();
    final lists = planner.taskLists.where((list) => _matches(list.name, list.description, null, query)).toList();
    if (tasks.isEmpty && events.isEmpty && lists.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(kPageGutter, 16, kPageGutter, 110),
        children: const [EmptyCard(message: 'No Planner items match your search.')],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 110),
      children: [
        if (tasks.isNotEmpty) ...[
          SectionHeader(title: 'Tasks · ${tasks.length}'),
          PagePad(
            GlassList(children: [
              for (final task in tasks)
                GlassRow(
                  leading: IconWell(Icons.task_alt_rounded, color: colors.accentText),
                  title: task.title,
                  subtitle: 'Task',
                  trailing: const RowMeta('›'),
                  onTap: () => _openTask(context, planner, task.id),
                ),
            ]),
          ),
          const SizedBox(height: 22),
        ],
        if (events.isNotEmpty) ...[
          SectionHeader(title: 'Events · ${events.length}'),
          PagePad(
            GlassList(children: [
              for (final event in events)
                GlassRow(
                  leading: IconWell(Icons.event_outlined, color: plannerEventColor(colors)),
                  title: event.title,
                  subtitle: 'Event',
                  trailing: const RowMeta('›'),
                  onTap: () => _openEvent(context, planner, event.id),
                ),
            ]),
          ),
          const SizedBox(height: 22),
        ],
        if (lists.isNotEmpty) ...[
          SectionHeader(title: 'Lists · ${lists.length}'),
          PagePad(
            GlassList(children: [
              for (final list in lists)
                GlassRow(
                  leading: const IconWell(Icons.checklist_rtl_rounded),
                  title: list.name,
                  subtitle: 'List',
                  trailing: const RowMeta('›'),
                  onTap: () => _openList(context, planner, list.id),
                ),
            ]),
          ),
        ],
      ],
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

  void _handleMore(BuildContext context, PlannerController planner, _MoreAction action) {
    switch (action) {
      case _MoreAction.chooseDate:
        _pickDate(context, planner);
        return;
      case _MoreAction.today:
        planner.goToToday();
        _showSection(PlannerSection.today);
        return;
      case _MoreAction.toggleScope:
        final week = planner.scope == ScheduleScope.week;
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

enum _MoreAction { chooseDate, today, toggleScope, clearSearch }
