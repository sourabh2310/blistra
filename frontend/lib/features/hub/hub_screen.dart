/// Hub: the map of the app. A 2-column grid of module tiles, each with one
/// live line from the dashboard summary, then tools and recent activity.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/module_guard.dart';
import '../../core/widgets/page_header.dart';
import '../ai/ai_api.dart';
import '../ai/ai_screen.dart';
import '../app_scope.dart';
import '../dashboard/models/dashboard_response.dart';
import '../documents/documents_page.dart';
import '../documents/upload_document_page.dart';
import '../notifications/screens/notification_settings_screen.dart';
import '../notifications/screens/reminders_screen.dart';
import '../preferences/screens/customize_home_screen.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({
    super.key,
    required this.onDestination,
    required this.onRefreshNotifications,
    this.onCustomizeNavigation,
  });

  final void Function(String destinationId) onDestination;
  final Future<void> Function() onRefreshNotifications;
  final VoidCallback? onCustomizeNavigation;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.dashboard, scope.authState]),
      builder: (context, _) {
        final dashboard = scope.dashboard.dashboard;
        final now = DateTime.now();
        final modules = _moduleData
            .where((module) => _matches(module.title, module.subtitle))
            .toList();
        final tools = _tools()
            .where((tool) => _matches(tool.title, tool.subtitle))
            .toList();
        final activities = _buildActivities(dashboard, now);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () {
                final offset = now.timeZoneOffset.inMinutes;
                return scope.dashboard.refresh(date: now, offsetMinutes: offset);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BlistraPageHeader(
                          eyebrow: 'Hub',
                          title: 'Everything',
                          subtitle:
                              "All your modules, with what's happening in each.",
                          actions: [
                            GlassIconButton(
                              tooltip: 'Search modules',
                              icon: _searching
                                  ? Icons.close_rounded
                                  : Icons.search_rounded,
                              onTap: _toggleSearch,
                            ),
                          ],
                        ),
                        if (_searching)
                          PagePad(
                            top: 8,
                            _SearchField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onChanged: (value) =>
                                  setState(() => _query = value.trim()),
                              onClear: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                _searchFocus.requestFocus();
                              },
                            ),
                          ),
                        PagePad(
                          top: 16,
                          modules.isEmpty
                              ? const EmptyCard(
                                  message: 'No modules match your search.',
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: modules.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    mainAxisExtent: 124,
                                  ),
                                  itemBuilder: (context, index) {
                                    final module = modules[index];
                                    return _ModuleTile(
                                      data: module,
                                      line: _liveLine(module, dashboard, now),
                                      onTap: () => _openModule(context, module),
                                    );
                                  },
                                ),
                        ),
                        if (tools.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'Tools'),
                          PagePad(
                            GlassList(
                              children: [
                                for (final tool in tools)
                                  GlassRow(
                                    leading: IconWell(tool.icon),
                                    title: tool.title,
                                    subtitle: tool.subtitle,
                                    trailing: const _Chevron(),
                                    onTap: tool.onTap,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (_query.isEmpty) ...[
                          const SizedBox(height: 24),
                          SectionHeader(
                            title: 'Recent activity',
                            actionLabel: activities.isEmpty ? null : 'Home ›',
                            onAction: activities.isEmpty
                                ? null
                                : () => widget.onDestination('HOME'),
                          ),
                          PagePad(
                            activities.isEmpty
                                ? const EmptyCard(
                                    message:
                                        'Your logged meals, health records, doses, habits and more will appear here.',
                                  )
                                : GlassList(
                                    children: [
                                      for (final activity in activities)
                                        GlassRow(
                                          leading: IconWell(
                                            activity.icon,
                                            color: onGlass(
                                              context,
                                              activity.accent,
                                            ),
                                          ),
                                          title: activity.title,
                                          subtitle: activity.subtitle,
                                          trailing: RowMeta(activity.when),
                                          onTap: () => widget.onDestination(
                                            activity.destination,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
    if (_searching) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

  bool _matches(String title, String subtitle) {
    if (_query.isEmpty) return true;
    final value = '$title $subtitle'.toLowerCase();
    return _query.toLowerCase().split(RegExp(r'\s+')).every(value.contains);
  }

  List<_ToolData> _tools() => [
        _ToolData(
          title: 'Blistra AI',
          subtitle: 'Ask, plan, or add entries by chat',
          icon: Icons.auto_awesome_rounded,
          onTap: () => _openAi(context),
        ),
        _ToolData(
          title: 'Customize Home',
          subtitle: 'Choose which sections and modules show',
          icon: Icons.dashboard_customize_outlined,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustomizeHomeScreen()),
          ),
        ),
        if (widget.onCustomizeNavigation != null)
          _ToolData(
            title: 'Customize navigation',
            subtitle: 'Pick what sits in the bottom bar',
            icon: Icons.tune_rounded,
            onTap: widget.onCustomizeNavigation!,
          ),
        _ToolData(
          title: 'Notifications',
          subtitle: 'Preferences and devices',
          icon: Icons.notifications_none_rounded,
          onTap: () => _openNotifications(context),
        ),
      ];

  void _openModule(BuildContext context, _ModuleData module) {
    switch (module.id) {
      case 'DOCUMENTS':
        _openDocuments(context);
      case 'REMINDERS':
        _openReminders(context);
      default:
        widget.onDestination(module.id);
    }
  }

  void _openAi(BuildContext context) {
    final api = AiApi(context.read<ApiClient>());
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AiScreen(
          api: api,
          authState: scope.authState,
          onUploadDocument: () => navigator.push(
            MaterialPageRoute(builder: (_) => const UploadDocumentPage()),
          ),
          onEntrySaved: () {
            final now = DateTime.now();
            return scope.dashboard.refresh(
              date: now,
              offsetMinutes: now.timeZoneOffset.inMinutes,
            );
          },
          onViewEntry: (module) {
            navigator.pop();
            if (module == 'Reminders') {
              _openReminders(context);
            } else {
              widget.onDestination(module.toUpperCase());
            }
          },
        ),
      ),
    );
  }

  Future<void> _openDocuments(BuildContext context) async {
    await pushModulePage(
      context,
      const DocumentsPage(),
      title: 'Documents',
    );
  }

  Future<void> _openReminders(BuildContext context) async {
    await pushModulePage(
      context,
      RemindersScreen(onRefresh: widget.onRefreshNotifications),
      title: 'Reminders',
      ownAppBar: false,
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    await pushModulePage(
      context,
      NotificationSettingsScreen(
        onRefresh: widget.onRefreshNotifications,
      ),
      title: 'Notifications',
      ownAppBar: false,
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              style: TextStyle(color: colors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search modules and tools',
                hintStyle: TextStyle(color: colors.muted, fontSize: 14),
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, color: colors.muted, size: 18),
            ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: BlistraColors.resolve(context).muted,
      );
}

/// Module icon colour from the design's per-module hue, readable on glass in
/// both light and dark.
Color _hueColor(BlistraColors colors, double hue) => HSLColor.fromAHSL(
      1,
      hue,
      0.8,
      colors.isDark ? 0.7 : 0.42,
    ).toColor();

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.data,
    required this.line,
    required this.onTap,
  });

  final _ModuleData data;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Semantics(
      button: true,
      label: '${data.title}, $line',
      excludeSemantics: true,
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconWell(data.icon, color: _hueColor(colors, data.hue)),
            const Spacer(),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BlistraText.serif(16, colors.text),
            ),
            const SizedBox(height: 3),
            Text(
              line,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleData {
  const _ModuleData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hue,
  });

  final String id;
  final String title;

  /// Static description, shown when there is no live data for the module.
  final String subtitle;
  final IconData icon;
  final double hue;
}

class _ToolData {
  const _ToolData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

const List<_ModuleData> _moduleData = [
  _ModuleData(
    id: 'PLANNER',
    title: 'Planner',
    subtitle: 'Tasks, events and your schedule',
    icon: Icons.calendar_month_rounded,
    hue: 168,
  ),
  _ModuleData(
    id: 'MEDICINES',
    title: 'Medicines',
    subtitle: 'Manage medicines and stay consistent',
    icon: Icons.medication_rounded,
    hue: 215,
  ),
  _ModuleData(
    id: 'HABITS',
    title: 'Habits',
    subtitle: 'Build better habits for a better you',
    icon: Icons.repeat_rounded,
    hue: 40,
  ),
  _ModuleData(
    id: 'DIET',
    title: 'Diet',
    subtitle: 'Log your meals and nutrition',
    icon: Icons.restaurant_rounded,
    hue: 22,
  ),
  _ModuleData(
    id: 'HEALTH',
    title: 'Health',
    subtitle: 'Track your health and measurements',
    icon: Icons.favorite_rounded,
    hue: 335,
  ),
  _ModuleData(
    id: 'FINANCE',
    title: 'Finance',
    subtitle: 'Track your spending and stay on top',
    icon: Icons.account_balance_wallet_rounded,
    hue: 146,
  ),
  _ModuleData(
    id: 'DOCUMENTS',
    title: 'Documents',
    subtitle: 'Files, reports and PDFs',
    icon: Icons.folder_copy_outlined,
    hue: 262,
  ),
  _ModuleData(
    id: 'REMINDERS',
    title: 'Reminders',
    subtitle: 'Alerts and schedules',
    icon: Icons.notifications_active_outlined,
    hue: 190,
  ),
];

/// One live line for a module tile, from the dashboard summary the app
/// already has. Falls back to the module description when there is no data.
String _liveLine(_ModuleData module, DashboardResponse? d, DateTime now) {
  if (d == null) return module.subtitle;
  String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
  switch (module.id) {
    case 'PLANNER':
      final p = d.planner;
      if (p == null || p.unavailable) break;
      bool open(TaskSummary t) {
        final s = (t.status ?? '').toUpperCase();
        return s != 'COMPLETED' && s != 'CANCELLED';
      }
      final overdue = p.overdueTasks.where(open).length;
      final left = p.todayTasks.where(open).length + overdue;
      if (overdue > 0) return '${plural(left, 'task')} left · $overdue overdue';
      if (left > 0) return '${plural(left, 'task')} left';
      if (p.todayEvents.isNotEmpty) {
        return '${plural(p.todayEvents.length, 'event')} today';
      }
      return 'Nothing due today';
    case 'MEDICINES':
      final m = d.medicines;
      if (m == null || m.unavailable) break;
      final pending = m.dosesToday.where((dose) {
        final s = dose.status.toUpperCase();
        return s != 'TAKEN' && s != 'CANCELLED' && s != 'SKIPPED';
      }).toList();
      final upcoming = pending
          .map((dose) => DateTime.tryParse(dose.scheduledAt)?.toLocal())
          .whereType<DateTime>()
          .where((at) => !at.isBefore(now))
          .toList()
        ..sort();
      if (upcoming.isNotEmpty) {
        return 'Next ${DateFormat.jm().format(upcoming.first)}';
      }
      if (pending.isNotEmpty) return '${plural(pending.length, 'dose')} due';
      if (m.dosesToday.isNotEmpty) return 'All doses taken';
      if (m.activeMedicineCount > 0) {
        return '${m.activeMedicineCount} active';
      }
      return 'No medicines yet';
    case 'HABITS':
      final h = d.habits;
      if (h == null || h.unavailable) break;
      if (h.expectedToday > 0) {
        return h.remainingToday > 0
            ? '${h.remainingToday} left today'
            : 'All done today';
      }
      if (h.activeHabitCount > 0) return '${h.activeHabitCount} active';
      return 'No habits yet';
    case 'DIET':
      final diet = d.diet;
      if (diet == null || diet.unavailable) break;
      final kcal = double.tryParse(diet.nutrition?.caloriesKcal?.total ?? '');
      if (kcal != null && kcal > 0) {
        return '${NumberFormat.decimalPattern().format(kcal.round())} kcal today';
      }
      if (diet.mealCount > 0) return '${plural(diet.mealCount, 'meal')} today';
      return 'Nothing logged today';
    case 'HEALTH':
      final health = d.health;
      if (health == null || health.unavailable) break;
      if (health.upcomingAppointments.isNotEmpty) {
        final next = health.upcomingAppointments.first;
        final at = DateTime.tryParse(next.scheduledAt)?.toLocal();
        return at == null
            ? next.title
            : '${next.title} · ${DateFormat('EEE').format(at)}';
      }
      if (health.latestMeasurements.isNotEmpty) {
        final m = health.latestMeasurements.first;
        final value = [
          m.valueDiastolic == null ? m.value : '${m.value}/${m.valueDiastolic}',
          m.unit,
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
        return value.isEmpty
            ? _titleCase(m.type)
            : '${_titleCase(m.type)} $value';
      }
      return 'No records yet';
    case 'FINANCE':
      final f = d.finance;
      if (f == null || f.unavailable || f.currencies.isEmpty) break;
      final c = f.currencies.first;
      final spent = double.tryParse(c.expense) ?? 0;
      if (spent <= 0) return 'Nothing spent yet';
      String amount;
      try {
        amount = NumberFormat.compactSimpleCurrency(name: c.currency)
            .format(spent);
      } catch (_) {
        amount = '${c.expense} ${c.currency}';
      }
      return '$amount spent';
  }
  return module.subtitle;
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.when,
    required this.destination,
    required this.icon,
    required this.background,
    required this.accent,
    this.timestamp,
  });

  final String title;
  final String subtitle;
  final String when;
  final String destination;
  final IconData icon;
  final Color background;
  final Color accent;
  final DateTime? timestamp;
}


List<_ActivityItem> _buildActivities(
  DashboardResponse? dashboard,
  DateTime now,
) {
  if (dashboard == null) return const [];
  final items = <_ActivityItem>[];

  for (final meal in dashboard.diet?.meals ?? const <MealSummary>[]) {
    final itemNames = meal.items
        .where((item) => item.name.trim().isNotEmpty)
        .map((item) => item.name)
        .take(2)
        .join(', ');
    final time = DateTime.tryParse(meal.consumedAt ?? '');
    items.add(
      _ActivityItem(
        title: 'Logged ${_titleCase(meal.type ?? 'meal')}',
        subtitle: itemNames.isEmpty ? 'Diet' : itemNames,
        when: _relativeTime(time, now),
        destination: meal.id.isEmpty
            ? 'DIET'
            : 'DIET/MEAL/${meal.id}',
        icon: Icons.restaurant_rounded,
        background: const Color(0xFFFFEBD8),
        accent: const Color(0xFFF0640E),
        timestamp: time,
      ),
    );
  }

  for (final water in dashboard.diet?.water ?? const <WaterSummary>[]) {
    final time = DateTime.tryParse(water.consumedAt ?? '');
    final amount = [water.amount, water.unit]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    items.add(
      _ActivityItem(
        title: 'Logged water',
        subtitle: amount.isEmpty ? 'Diet' : amount,
        when: _relativeTime(time, now),
        destination: 'DIET',
        icon: Icons.water_drop_rounded,
        background: const Color(0xFFDFF1FA),
        accent: const Color(0xFF318BC1),
        timestamp: time,
      ),
    );
  }

  for (final dose in dashboard.medicines?.dosesToday ??
      const <DoseSummary>[]) {
    if (dose.status.toUpperCase() != 'TAKEN') continue;
    final time = DateTime.tryParse(dose.takenAt ?? '');
    final amount = [dose.doseAmount, dose.doseUnit]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    items.add(
      _ActivityItem(
        title: 'Took ${dose.medicineName}',
        subtitle: amount.isEmpty ? 'Medicine' : 'Medicine • $amount',
        when: _relativeTime(time, now),
        destination: dose.medicineId.isEmpty
            ? 'MEDICINES'
            : 'MEDICINES/${dose.medicineId}',
        icon: Icons.medication_rounded,
        background: const Color(0xFFFFE1E6),
        accent: const Color(0xFFE5384A),
        timestamp: time,
      ),
    );
  }

  for (final habit in dashboard.habits?.todayHabits ??
      const <HabitSummary>[]) {
    if (!habit.completedToday) continue;
    final target = [habit.targetValue, habit.targetUnit]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    items.add(
      _ActivityItem(
        title: 'Completed ${habit.name}',
        subtitle: target.isEmpty ? 'Habit' : 'Habit • $target',
        when: 'Today',
        destination:
            habit.id.isEmpty ? 'HABITS' : 'HABITS/${habit.id}',
        icon: Icons.check_rounded,
        background: const Color(0xFFE3F3E5),
        accent: const Color(0xFF2A9A50),
      ),
    );
  }

  final planner = dashboard.planner;
  if (planner != null) {
    for (final task in [...planner.overdueTasks, ...planner.todayTasks]) {
      if (task.status?.toUpperCase() != 'COMPLETED') continue;
      final due = DateTime.tryParse(task.dueAt ?? '');
      items.add(
        _ActivityItem(
          title: task.title.trim().isEmpty
              ? 'Completed a task'
              : 'Completed ${task.title}',
          subtitle: task.listName?.trim().isNotEmpty == true
              ? 'Planner • ${task.listName}'
              : 'Planner task',
          when: due == null ? 'Today' : 'Due ${_relativeTime(due, now)}',
          destination:
              task.id.isEmpty ? 'PLANNER' : 'PLANNER/task/${task.id}',
          icon: Icons.task_alt_rounded,
          background: const Color(0xFFDDEEFF),
          accent: const Color(0xFF237DD0),
          timestamp: due,
        ),
      );
    }
  }

  for (final measurement
      in dashboard.health?.latestMeasurements ?? const <MeasurementSummary>[]) {
    final time = DateTime.tryParse(measurement.measuredAt ?? '');
    final value = [measurement.value, measurement.unit]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    items.add(
      _ActivityItem(
        title: 'Recorded ${_titleCase(measurement.type)}',
        subtitle: value.isEmpty ? 'Health' : value,
        when: _relativeTime(time, now),
        destination: 'HEALTH',
        icon: Icons.favorite_rounded,
        background: const Color(0xFFFFE0E5),
        accent: const Color(0xFFE23A4E),
        timestamp: time,
      ),
    );
  }

  for (final currency
      in dashboard.finance?.currencies ?? const <CurrencySection>[]) {
    for (final category in currency.topCategories.take(1)) {
      items.add(
        _ActivityItem(
          title: 'Spent in ${category.categoryName}',
          subtitle: 'Finance • ${category.amount} ${currency.currency}'.trim(),
          when: 'This period',
          destination: 'FINANCE',
          icon: Icons.account_balance_wallet_rounded,
          background: const Color(0xFFFFE7C0),
          accent: const Color(0xFFD67B0D),
        ),
      );
    }
  }

  items.sort((a, b) {
    final left = a.timestamp;
    final right = b.timestamp;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  });
  return items.take(6).toList();
}

String _titleCase(String value) {
  final clean = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (clean.isEmpty) return '';
  return clean
      .split(RegExp(r'\s+'))
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _relativeTime(DateTime? value, DateTime now) {
  if (value == null) return 'Today';
  final local = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) {
    final minutes = now.difference(local).inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  if (difference == 1) return 'Yesterday';
  if (difference > 1 && difference < 7) {
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];
  }
  return '${_monthName(local.month)} ${local.day}';
}

String _monthName(int month) => const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];

