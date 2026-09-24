import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/module_guard.dart';
import '../app_scope.dart';
import '../dashboard/models/dashboard_response.dart';
import '../documents/documents_page.dart';
import '../notifications/screens/notification_settings_screen.dart';
import '../notifications/screens/reminders_screen.dart';

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
        final name = resolveDisplayName(
          user: dashboard?.user,
          email: scope.authState.userEmail,
        );
        final modules = _moduleData
            .where((module) => _matches(module.title, module.subtitle))
            .toList();
        final tools = _toolData
            .where((tool) => _matches(tool.title, tool.subtitle))
            .toList();
        final activities = _buildActivities(dashboard, now);
        return Scaffold(
          backgroundColor: const Color(0xFFFFFBF6),
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
                          _BrandHeader(
                            displayName: name,
                            onSearch: () => _searchFocus.requestFocus(),
                            onReminders: () => _openReminders(context),
                            onDocuments: () => _openDocuments(context),
                            onProfile: () => widget.onDestination('PROFILE'),
                          ),
                          const SizedBox(height: 24),
                          const _Hero(),
                          const SizedBox(height: 18),
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
                          const SizedBox(height: 26),
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
                                    cardWidth.clamp(142.0, 205.0).toDouble();
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
                            const Text(
                              'More',
                              style: TextStyle(
                                color: Color(0xFF0B1F35),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.displayName,
    required this.onSearch,
    required this.onReminders,
    required this.onDocuments,
    required this.onProfile,
  });

  final String displayName;
  final VoidCallback onSearch;
  final VoidCallback onReminders;
  final VoidCallback onDocuments;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Blistra',
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(
                        color: Color(0xFF075A48),
                        fontFamily: 'serif',
                        fontSize: 33,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF20A474),
                    size: 30,
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const Text(
                'EVERYTHING YOU NEED. ONE APP.',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: Color(0xFF4B6680),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _ActionCircle(
          tooltip: 'Search modules',
          icon: Icons.search_rounded,
          onTap: onSearch,
        ),
        const SizedBox(width: 7),
        _ActionCircle(
          tooltip: 'Reminders',
          icon: Icons.notifications_none_rounded,
          onTap: onReminders,
          showDot: true,
        ),
        const SizedBox(width: 7),
        _ActionCircle(
          tooltip: 'Documents',
          icon: Icons.calendar_today_outlined,
          onTap: onDocuments,
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'Open profile',
          button: true,
          child: InkWell(
            onTap: onProfile,
            customBorder: const CircleBorder(),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD6ECE4), Color(0xFF85BCA8)],
                ),
              ),
              child: Text(
                displayName.trim().isEmpty ? 'B' : initialsForName(displayName),
                style: const TextStyle(
                  color: Color(0xFF075A48),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFFF1F2F6),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: const Color(0xFF0B2038), size: 23),
              if (showDot)
                Positioned(
                  right: 8,
                  top: 7,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE63546),
                      shape: BoxShape.circle,
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

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _HeroPainter())),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hub',
                    style: TextStyle(
                      color: Color(0xFF0B2038),
                      fontFamily: 'serif',
                      fontSize: 43,
                      height: 0.95,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'All parts of your life, in one place.',
                    maxLines: 2,
                    style: TextStyle(
                      color: Color(0xFF4B6079),
                      fontSize: 16,
                      height: 1.22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search modules, tasks, health and more…',
        hintStyle: const TextStyle(
          color: Color(0xFF71829A),
          fontSize: 14.5,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF233C5A),
          size: 27,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFFF0EBE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Color(0xFF84C8B5, width: 1.4),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0B1F35),
              fontFamily: 'serif',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF075A48),
              visualDensity: VisualDensity.compact,
            ),
            icon: Icon(actionIcon, size: 19),
            label: Text(
              actionLabel!,
              style: const TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: data.background,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -10,
              child: CustomPaint(
                size: const Size(112, 94),
                painter: _ModulePainter(
                  variant: data.variant,
                  accent: data.accent,
                  secondary: data.secondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: data.iconBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(data.icon, color: data.accent, size: 25),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFF193B50),
                        size: 27,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0B1F35),
                      fontFamily: 'serif',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      data.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF516986),
                        fontFamily: 'serif',
                        fontSize: 12.5,
                        height: 1.08,
                      ),
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
}

class _ConnectedBanner extends StatelessWidget {
  const _ConnectedBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _ConnectedPainter()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF075A48),
                      size: 38,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Everything connected',
                            style: TextStyle(
                              color: const Color(0xFF0B1F35).withValues(
                                alpha: 0.96,
                              ),
                              fontFamily: 'serif',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your tasks, health, habits, diet and finance work together for a clearer picture.',
                            maxLines: 2,
                            style: TextStyle(
                              color: const Color(0xFF3E5872).withValues(
                                alpha: 0.88,
                              ),
                              fontFamily: 'serif',
                              fontSize: 12.5,
                              height: 1.12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF075A48),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    if (activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          'Your logged meals, health records, doses, habits and more will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF667B92), height: 1.35),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            _ActivityRow(
              activity: activities[index],
              onTap: () => onDestination(activities[index].destination),
            ),
            if (index != activities.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 72,
                color: Color(0xFFF0EEE9),
              ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: activity.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(activity.icon, color: activity.accent, size: 22),
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
                      style: const TextStyle(
                        color: Color(0xFF0B1F35),
                        fontFamily: 'serif',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5A7190),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                activity.when,
                style: const TextStyle(
                  color: Color(0xFF6A7F99),
                  fontFamily: 'serif',
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF35516D),
                size: 23,
              ),
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
      color: data.background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
          child: Column(
            children: [
              Icon(data.icon, color: data.accent, size: 25),
              const SizedBox(height: 7),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0B1F35),
                  fontFamily: 'serif',
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
        color: const Color(0xFFF5F3EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFF60758D)),
          SizedBox(height: 8),
          Text(
            'No modules match your search.',
            style: TextStyle(color: Color(0xFF405A73)),
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

const List<_ModuleData> _moduleData = [
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

const List<_ToolData> _toolData = [
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

class _HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..color = const Color(0xFFFFE8D8);
    canvas.drawCircle(Offset(size.width * 0.79, size.height * 0.45), 64, wash);
    canvas.drawCircle(
      Offset(size.width * 0.98, size.height * 0.74),
      38,
      Paint()..color = const Color(0xFFFFDCC7),
    );
    final backHill = Path()
      ..moveTo(size.width * 0.47, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.67,
        size.height * 0.28,
        size.width * 0.87,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.5,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.45, size.height)
      ..close();
    canvas.drawPath(backHill, Paint()..color = const Color(0xFFB8DCD9));
    final frontHill = Path()
      ..moveTo(size.width * 0.53, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.55,
        size.width * 0.9,
        size.height * 0.77,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.48, size.height)
      ..close();
    canvas.drawPath(frontHill, Paint()..color = const Color(0xFF74ACA9));
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.38),
      17,
      Paint()..color = const Color(0xFFFFCB73),
    );
    _plant(
      canvas,
      Offset(size.width * 0.68, size.height * 0.96),
      0.82,
      const Color(0xFF176B5B),
      const Color(0xFF4D8B6B),
    );
    _plant(
      canvas,
      Offset(size.width * 0.98, size.height * 0.95),
      1.0,
      const Color(0xFF1C665B),
      const Color(0xFF6D9E7C),
    );
  }

  void _plant(
    Canvas canvas,
    Offset origin,
    double scale,
    Color dark,
    Color light,
  ) {
    final stem = Paint()
      ..color = dark
      ..strokeWidth = 2.4 * scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      origin,
      origin.translate(-8 * scale, -72 * scale),
      stem,
    );
    canvas.drawLine(
      origin.translate(-4 * scale, -42 * scale),
      origin.translate(18 * scale, -58 * scale),
      stem,
    );
    _leaf(
      canvas,
      origin.translate(-8 * scale, -69 * scale),
      const Size(23, 48),
      -0.35,
      dark,
    );
    _leaf(
      canvas,
      origin.translate(17 * scale, -57 * scale),
      const Size(21, 44),
      0.7,
      light,
    );
    _leaf(
      canvas,
      origin.translate(-5 * scale, -39 * scale),
      const Size(19, 41),
      -0.75,
      light,
    );
  }

  void _leaf(
    Canvas canvas,
    Offset center,
    Size leafSize,
    double angle,
    Color color,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(0, leafSize.height / 2)
      ..quadraticBezierTo(
        -leafSize.width / 2,
        0,
        0,
        -leafSize.height / 2,
      )
      ..quadraticBezierTo(
        leafSize.width / 2,
        0,
        0,
        leafSize.height / 2,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      Offset(0, leafSize.height / 2),
      Offset(0, -leafSize.height / 2 + 4),
      Paint()
        ..color = const Color(0xFFB9D6B5)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModulePainter extends CustomPainter {
  const _ModulePainter({
    required this.variant,
    required this.accent,
    required this.secondary,
  });

  final int variant;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = secondary.withValues(alpha: 0.32);
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.78), 43, soft);
    switch (variant) {
      case 0:
        _calendar(canvas, size);
      case 1:
        _health(canvas, size);
      case 2:
        _medicine(canvas, size);
      case 3:
        _diet(canvas, size);
      case 4:
        _habits(canvas, size);
      default:
        _finance(canvas, size);
    }
  }

  void _calendar(Canvas canvas, Size size) {
    final x = size.width * 0.42;
    final y = size.height * 0.23;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 52, 59),
      const Radius.circular(7),
    );
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 52, 15),
        const Radius.circular(7),
      ),
      Paint()..color = const Color(0xFFF0A35B),
    );
    final line = Paint()
      ..color = const Color(0xFFB2B9B2)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x + 14, y - 4), Offset(x + 14, y + 7), line);
    canvas.drawLine(Offset(x + 38, y - 4), Offset(x + 38, y + 7), line);
    final dot = Paint()..color = const Color(0xFFD8DDD7);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x + 7 + col * 10,
              y + 23 + row * 11,
              6,
              6,
            ),
            const Radius.circular(1.5),
          ),
          dot,
        );
      }
    }
  }

  void _health(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF226754)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final base = Offset(size.width * 0.67, size.height * 0.96);
    canvas.drawLine(base, base.translate(-5, -54), stem);
    final leaves = [
      (Offset(base.dx - 6, base.dy - 55), -0.5, const Color(0xFF2B7A61)),
      (Offset(base.dx + 12, base.dy - 36), 0.75, const Color(0xFF6EA57A)),
      (Offset(base.dx - 5, base.dy - 23), -0.8, const Color(0xFF4A8B6A)),
    ];
    for (final leaf in leaves) {
      canvas.save();
      canvas.translate(leaf.$1.dx, leaf.$1.dy);
      canvas.rotate(leaf.$2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 19, height: 39),
        Paint()..color = leaf.$3,
      );
      canvas.restore();
    }
  }

  void _medicine(Canvas canvas, Size size) {
    final x = size.width * 0.56;
    final y = size.height * 0.35;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 32, 45),
        const Radius.circular(7),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 6, y - 7, 20, 10),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF377FC6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y + 20, 32, 12),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF9FC5E8),
    );
    final pill = Paint()..color = accent;
    canvas.save();
    canvas.translate(x - 7, y + 28);
    canvas.rotate(-0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 22, height: 10),
        const Radius.circular(6),
      ),
      pill,
    );
    canvas.restore();
  }

  void _diet(Canvas canvas, Size size) {
    final bowl = Path()
      ..moveTo(size.width * 0.45, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.91,
        size.width * 0.87,
        size.height * 0.91,
      )
      ..quadraticBezierTo(
        size.width * 0.97,
        size.height * 0.84,
        size.width,
        size.height * 0.58,
      )
      ..close();
    canvas.drawPath(bowl, Paint()..color = const Color(0xFFFFF9ED));
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.44,
        size.height * 0.49,
        size.width * 0.58,
        size.height * 0.31,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFD5A66C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final greens = Paint()..color = const Color(0xFF4D9564);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.52), 12, greens);
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.47), 13, greens);
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.53),
      10,
      Paint()..color = const Color(0xFFF2A23C),
    );
  }

  void _habits(Canvas canvas, Size size) {
    final y = size.height * 0.52;
    final paint = Paint()
      ..color = const Color(0xFFB18B55)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.42, y), Offset(size.width * 0.9, y), paint);
    canvas.drawLine(
      Offset(size.width * 0.49, y - 10),
      Offset(size.width * 0.49, y + 10),
      Paint()
        ..color = const Color(0xFF7A6246)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(size.width * 0.84, y - 10),
      Offset(size.width * 0.84, y + 10),
      Paint()
        ..color = const Color(0xFF7A6246)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  void _finance(Canvas canvas, Size size) {
    final bars = [
      (0.0, 30.0, const Color(0xFFF1B966)),
      (0.25, 47.0, const Color(0xFFE59A42)),
      (0.5, 64.0, const Color(0xFFD97A29)),
    ];
    for (final bar in bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.42 + size.width * bar.$1,
            size.height - bar.$2,
            15,
            bar.$2,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = bar.$3,
      );
    }
    final arrow = Paint()
      ..color = const Color(0xFF2A8E68)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final start = Offset(size.width * 0.4, size.height * 0.38);
    final end = Offset(size.width * 0.92, size.height * 0.2);
    canvas.drawLine(start, end, arrow);
    canvas.drawLine(
      end,
      Offset(end.dx - 10, end.dy + 2),
      arrow,
    );
    canvas.drawLine(
      end,
      Offset(end.dx - 1, end.dy + 10),
      arrow,
    );
  }

  @override
  bool shouldRepaint(covariant _ModulePainter oldDelegate) =>
      oldDelegate.variant != variant ||
      oldDelegate.accent != accent ||
      oldDelegate.secondary != secondary;
}

class _ConnectedPainter extends CustomPainter {
  const _ConnectedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..color = const Color(0xFFE4F3F0);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.76), 65, glow);
    final hill = Path()
      ..moveTo(size.width * 0.59, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.2,
        size.width,
        size.height * 0.72,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.57, size.height)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFFB7DDD2));
    final stem = Paint()
      ..color = const Color(0xFF2A775D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final base = Offset(size.width * 0.86, size.height * 0.98);
    canvas.drawLine(base, base.translate(0, -48), stem);
    for (final data in [
      (Offset(-2, -45), -0.45, const Color(0xFF4A8A68)),
      (Offset(10, -31), 0.65, const Color(0xFF3B765C)),
      (Offset(-2, -20), -0.65, const Color(0xFF75A97D)),
    ]) {
      canvas.save();
      canvas.translate(base.dx + data.$1.dx, base.dy + data.$1.dy);
      canvas.rotate(data.$2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 13, height: 29),
        Paint()..color = data.$3,
      );
      canvas.restore();
    }
    final flower = Paint()..color = const Color(0xFFF2BB55);
    canvas.drawCircle(base.translate(0, -52), 4, flower);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
