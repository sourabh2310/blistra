
import 'package:flutter/material.dart';

import '../../core/widgets/module_guard.dart';
import '../app_scope.dart';
import '../dashboard/models/dashboard_response.dart';
import '../documents/documents_page.dart';
import '../notifications/screens/notification_settings_screen.dart';
import '../notifications/screens/reminders_screen.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/glass.dart';

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
        final tools = _toolData
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlistraPageHeader(
                            title: 'Hub',
                            subtitle: 'All parts of your life, in one place.',
                            padding: EdgeInsets.zero,
                            actions: [
                              GlassIconButton(
                                tooltip: 'Search modules',
                                icon: Icons.search_rounded,
                                onTap: () => _searchFocus.requestFocus(),
                              ),
                              GlassIconButton(
                                tooltip: 'Reminders',
                                icon: Icons.notifications_none_rounded,
                                onTap: () => _openReminders(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 18),
                          _SectionHeading(
                            title: 'Your modules',
                            actionLabel: 'Customize',
                            actionIcon: Icons.tune,
                            onAction: widget.onCustomizeNavigation,
                          ),
                          const SizedBox(height: 12),
                          if (modules.isNotEmpty)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final cardWidth = (constraints.maxWidth - 12) / 2;
                                final cardHeight =
                                    cardWidth.clamp(118.0, 150.0).toDouble();
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: modules.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: cardWidth / cardHeight,
                                  ),
                                  itemBuilder: (context, index) {
                                    final module = modules[index];
                                    return _ModuleCard(
                                      data: module,
                                      onTap: () =>
                                          widget.onDestination(module.id),
                                    );
                                  },
                                );
                              },
                            )
                          else
                            const _NoMatches(),
                          const SizedBox(height: 22),
                          _ConnectedBanner(
                            onTap: () => widget.onDestination('HOME'),
                          ),
                          const SizedBox(height: 26),
                          _SectionHeading(
                            title: 'Recent activity',
                            actionLabel: activities.isEmpty ? null : 'See all',
                            actionIcon: Icons.arrow_forward,
                            onAction: activities.isEmpty
                                ? null
                                : () => widget.onDestination('HOME'),
                          ),
                          const SizedBox(height: 10),
                          _ActivityCard(
                            activities: activities,
                            onDestination: widget.onDestination,
                          ),
                          const SizedBox(height: 26),
                          if (tools.isNotEmpty) ...[
                            Text(
                              'More',
                              style: TextStyle(
                                color: BlistraColors.resolve(context).text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ToolRow(
                              tools: tools,
                              onDocuments: () => _openDocuments(context),
                              onReminders: () => _openReminders(context),
                              onNotifications: () => _openNotifications(context),
                            ),
                          ],
                        ],
                      ),
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

  bool _matches(String title, String subtitle) {
    if (_query.isEmpty) return true;
    final value = '$title $subtitle'.toLowerCase();
    return _query.toLowerCase().split(RegExp(r'\s+')).every(value.contains);
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
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      style: TextStyle(color: colors.text, fontSize: 14.5),
      decoration: InputDecoration(
        hintText: 'Search modules, tasks, health and more…',
        hintStyle: TextStyle(color: colors.muted, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: colors.muted, size: 22),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: colors.glassFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.accent, width: 1.4),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final String title;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontFamily: 'Sora',
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.accentText,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.data, required this.onTap});

  final _ModuleData data;
  final VoidCallback onTap;

  static Color colorFor(String id) => switch (id) {
    'PLANNER' => ModuleColors.planner,
    'HEALTH' => ModuleColors.health,
    'MEDICINES' => ModuleColors.medicines,
    'DIET' => ModuleColors.diet,
    'HABITS' => ModuleColors.habits,
    'FINANCE' => ModuleColors.finance,
    _ => const Color(0xFF64748B),
  };

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final color = colorFor(data.id);
    return GlassCard(
      padding: EdgeInsets.zero,
      radius: 24,
      tint: color,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.chevron_right_rounded, color: colors.muted, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(data.icon, color: Colors.white, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontFamily: 'Sora',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 12, height: 1.25),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedBanner extends StatelessWidget {
  const _ConnectedBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: colors.accentText, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything connected',
                  style: TextStyle(
                    color: colors.text,
                    fontFamily: 'Sora',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your tasks, health, habits, diet and finance work together for a clearer picture.',
                  maxLines: 2,
                  style: TextStyle(color: colors.muted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.muted, size: 20),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activities,
    required this.onDestination,
  });

  final List<_ActivityItem> activities;
  final void Function(String destinationId) onDestination;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    if (activities.isEmpty) {
      return GlassCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            'Your logged meals, health records, doses, habits and more will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, height: 1.35),
          ),
        ),
      );
    }
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            _ActivityRow(
              activity: activities[index],
              onTap: () => onDestination(activities[index].destination),
            ),
            if (index != activities.length - 1)
              Divider(height: 1, thickness: 1, indent: 62, color: colors.glassBorder),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onTap});

  final _ActivityItem activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: activity.accent.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(activity.icon, color: onGlass(context, activity.accent), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                activity.when,
                style: TextStyle(color: colors.muted, fontSize: 11.5),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, color: colors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.tools,
    required this.onDocuments,
    required this.onReminders,
    required this.onNotifications,
  });

  final List<_ToolData> tools;
  final VoidCallback onDocuments;
  final VoidCallback onReminders;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < tools.length; index++) ...[
          Expanded(
            child: _ToolCard(
              data: tools[index],
              onTap: switch (tools[index].id) {
                'DOCUMENTS' => onDocuments,
                'REMINDERS' => onReminders,
                _ => onNotifications,
              },
            ),
          ),
          if (index != tools.length - 1) const SizedBox(width: 9),
        ],
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.data, required this.onTap});

  final _ToolData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: softBg(context, data.background),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
          child: Column(
            children: [
              Icon(data.icon, color: onGlass(context, data.accent), size: 25),
              const SizedBox(height: 7),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: BlistraColors.resolve(context).text,
                  fontFamily: 'Sora',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: softBg(context, Color(0xFFF5F3EF)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: BlistraColors.resolve(context).muted),
          SizedBox(height: 8),
          Text(
            'No modules match your search.',
            style: TextStyle(color: BlistraColors.resolve(context).muted),
          ),
        ],
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
    required this.background,
    required this.iconBackground,
    required this.accent,
    required this.secondary,
    required this.variant,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color iconBackground;
  final Color accent;
  final Color secondary;
  final int variant;
}

class _ToolData {
  const _ToolData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.accent,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color accent;
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

List<_ModuleData> _moduleData = [
  _ModuleData(
    id: 'PLANNER',
    title: 'Planner',
    subtitle: 'Tasks, events and your schedule',
    icon: Icons.calendar_month_rounded,
    background: Color(0xFFE3F4EB),
    iconBackground: Color(0xFFC9ECD9),
    accent: Color(0xFF008B57),
    secondary: Color(0xFFB9DCC8),
    variant: 0,
  ),
  _ModuleData(
    id: 'HEALTH',
    title: 'Health',
    subtitle: 'Track your health and measurements',
    icon: Icons.favorite_rounded,
    background: Color(0xFFFBE7EA),
    iconBackground: Color(0xFFF8D5DA),
    accent: Color(0xFFED3347),
    secondary: Color(0xFFECAAB3),
    variant: 1,
  ),
  _ModuleData(
    id: 'MEDICINES',
    title: 'Medicines',
    subtitle: 'Manage medicines and stay consistent',
    icon: Icons.medication_rounded,
    background: Color(0xFFE3EFFB),
    iconBackground: Color(0xFFD1E2F7),
    accent: Color(0xFF1F78DC),
    secondary: Color(0xFFAACDEB),
    variant: 2,
  ),
  _ModuleData(
    id: 'DIET',
    title: 'Diet',
    subtitle: 'Log your meals and nutrition',
    icon: Icons.restaurant_rounded,
    background: Color(0xFFFFF0DF),
    iconBackground: Color(0xFFFFE0BD),
    accent: Color(0xFFF16B14),
    secondary: Color(0xFFE5A356),
    variant: 3,
  ),
  _ModuleData(
    id: 'HABITS',
    title: 'Habits',
    subtitle: 'Build better habits for a better you',
    icon: Icons.fitness_center_rounded,
    background: Color(0xFFF0E8FC),
    iconBackground: Color(0xFFE2D2F8),
    accent: Color(0xFF9B3CE3),
    secondary: Color(0xFF9BC98A),
    variant: 4,
  ),
  _ModuleData(
    id: 'FINANCE',
    title: 'Finance',
    subtitle: 'Track your spending and stay on top',
    icon: Icons.account_balance_wallet_rounded,
    background: Color(0xFFFFF2D9),
    iconBackground: Color(0xFFFFE3AD),
    accent: Color(0xFFD68A18),
    secondary: Color(0xFF2B9C73),
    variant: 5,
  ),
];

List<_ToolData> _toolData = [
  _ToolData(
    id: 'DOCUMENTS',
    title: 'Documents',
    subtitle: 'Files, reports and PDFs',
    icon: Icons.folder_copy_outlined,
    background: Color(0xFFFFF1D9),
    accent: Color(0xFFD78113),
  ),
  _ToolData(
    id: 'REMINDERS',
    title: 'Reminders',
    subtitle: 'Alerts and schedules',
    icon: Icons.notifications_active_outlined,
    background: Color(0xFFECEAF8),
    accent: Color(0xFF6D58B5),
  ),
  _ToolData(
    id: 'NOTIFICATIONS',
    title: 'Notifications',
    subtitle: 'Preferences and devices',
    icon: Icons.tune_rounded,
    background: Color(0xFFE1F2EE),
    accent: Color(0xFF087A67),
  ),
];

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

