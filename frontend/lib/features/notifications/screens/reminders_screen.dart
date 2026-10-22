import 'package:flutter/material.dart';
import 'package:frontend/features/notifications/models/reminder.dart';
import 'package:frontend/features/notifications/models/reminder_type.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';
import '../state/reminders_controller.dart';
import '../state/settings_controller.dart';
import 'notification_settings_screen.dart';
import 'reminder_form_screen.dart';
import 'reminder_visuals.dart';

/// Lists the current user's active reminders, allows creating new GENERAL
/// reminders and cancelling/editing existing ones. Pull-to-refresh also
/// re-synchronizes local notifications.
///
/// "Upcoming" groups future reminders by day; "All reminders" lists every
/// active reminder for editing. A settings card at the bottom holds the
/// master switch and links to per-module settings.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.onRefresh});

  /// Invoked after local mutation refreshes to re-sync scheduled notifications.
  final Future<void> Function() onRefresh;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _dateFormatter = DateFormat('EEE, MMM d · HH:mm');
  final _timeFormatter = DateFormat('h:mm a');
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<RemindersController>().load();
    await widget.onRefresh();
  }

  Future<void> _createOrEdit([Reminder? existing]) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReminderFormScreen(existing: existing)),
    );
    if (created == true) {
      await _load();
    }
  }

  Future<void> _cancel(Reminder reminder) async {
    await context.read<RemindersController>().cancel(reminder.id);
    await widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reminder cancelled')));
    }
  }

  void _open(Reminder reminder) {
    if (reminder.type == ReminderType.general) {
      _createOrEdit(reminder);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit this reminder in its medicine or task schedule.'),
        ),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: NotificationSettingsScreen(onRefresh: widget.onRefresh),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RemindersController>();
    // Callers usually wrap this screen in a Scaffold with an AppBar titled
    // "Reminders"; only draw our own header when there is none.
    final hasAppBar = Scaffold.maybeOf(context)?.hasAppBar ?? false;
    final reminders = [...controller.reminders]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (!hasAppBar)
            SafeArea(
              bottom: false,
              child: BlistraPageHeader(
                eyebrow: 'Notifications',
                title: 'Reminders',
                actions: [
                  GlassIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Notification settings',
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
          BlistraSegmentedTabs(
            labels: const ['Upcoming', 'All reminders'],
            selected: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
          if (controller.loading && controller.reminders.isEmpty) ...[
            const SizedBox(height: 16),
            const SkeletonLoader(rows: 3),
          ] else if (controller.error != null &&
              controller.reminders.isEmpty) ...[
            const SizedBox(height: 16),
            PagePad(UnavailableCard(name: 'Reminders', onRetry: _load)),
          ] else if (_tab == 0)
            ..._upcoming(controller, reminders)
          else
            ..._all(controller, reminders),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Settings'),
          PagePad(_SettingsCard(
            onRefresh: widget.onRefresh,
            onOpen: _openSettings,
          )),
        ],
      ),
    );
  }

  /// Future reminders grouped by local day.
  List<Widget> _upcoming(
    RemindersController controller,
    List<Reminder> reminders,
  ) {
    final now = DateTime.now();
    final upcoming =
        reminders.where((r) => r.scheduledAt.toLocal().isAfter(now)).toList();
    if (upcoming.isEmpty) {
      return [
        const SizedBox(height: 16),
        PagePad(EmptyCard(
          message: 'No upcoming reminders',
          action: 'Add',
          onAction: _createOrEdit,
        )),
      ];
    }
    final today = DateTime(now.year, now.month, now.day);
    final groups = <DateTime, List<Reminder>>{};
    for (final r in upcoming) {
      final t = r.scheduledAt.toLocal();
      groups.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(r);
    }
    String dayLabel(DateTime day) {
      final diff = day.difference(today).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Tomorrow';
      return DateFormat('EEEE, d MMM').format(day);
    }

    return [
      for (final entry in groups.entries) ...[
        const SizedBox(height: 22),
        SectionHeader(title: dayLabel(entry.key)),
        PagePad(GlassList(
          children: [
            for (final r in entry.value)
              GlassRow(
                leading: IconWell(
                  reminderIcon(r.type),
                  color: reminderColor(context, r.type),
                ),
                title: r.title,
                subtitle: '${controller.labelFor(r.type)} · '
                    '${_timeFormatter.format(r.scheduledAt.toLocal())}',
                trailing: _countdown(r.scheduledAt.toLocal(), now),
                onTap: () => _open(r),
              ),
          ],
        )),
      ],
    ];
  }

  /// "25 min" pill within the hour, otherwise a muted time or day count.
  Widget _countdown(DateTime at, DateTime now) {
    final diff = at.difference(now);
    if (diff.inMinutes < 60) {
      return Pill('${diff.inMinutes < 1 ? 1 : diff.inMinutes} min');
    }
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(at.year, at.month, at.day).difference(today).inDays;
    if (days == 0) return RowMeta(DateFormat('HH:mm').format(at));
    return RowMeta(days == 1 ? '1 day' : '$days days');
  }

  /// Every active reminder; GENERAL ones swipe to cancel and open the form.
  List<Widget> _all(RemindersController controller, List<Reminder> reminders) {
    final colors = BlistraColors.resolve(context);
    return [
      const SizedBox(height: 22),
      SectionHeader(
        title: 'All reminders',
        actionLabel: '+ New',
        onAction: _createOrEdit,
      ),
      PagePad(reminders.isEmpty
          ? EmptyCard(
              message: 'No upcoming reminders. Tap + New to add one.',
              action: 'Add',
              onAction: _createOrEdit,
            )
          : GlassList(
              children: [
                for (final reminder in reminders)
                  Dismissible(
                    key: ValueKey(reminder.id),
                    direction: reminder.type == ReminderType.general
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    background: Container(
                      color: colors.danger.withValues(alpha: 0.2),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: Icon(Icons.delete_outline, color: colors.danger),
                    ),
                    confirmDismiss: (_) async => true,
                    onDismissed: (_) => _cancel(reminder),
                    child: GlassRow(
                      leading: IconWell(
                        reminderIcon(reminder.type),
                        color: reminderColor(context, reminder.type),
                      ),
                      title: reminder.title,
                      subtitle:
                          '${_dateFormatter.format(reminder.scheduledAt.toLocal())}'
                          ' · ${controller.labelFor(reminder.type)}',
                      trailing: Icon(
                        reminder.type == ReminderType.general
                            ? Icons.chevron_right_rounded
                            : Icons.lock_outline,
                        size: 18,
                        color: colors.muted,
                      ),
                      onTap: () => _open(reminder),
                    ),
                  ),
              ],
            )),
      if (reminders.any((r) => r.type == ReminderType.general))
        PagePad(
          Text(
            'Swipe a general reminder left to cancel it.',
            style: TextStyle(fontSize: 11, color: colors.muted),
          ),
          top: 8,
        ),
    ];
  }
}

/// Master switch plus a link to per-module settings. Hidden when no
/// [SettingsController] is provided above this screen.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.onRefresh, required this.onOpen});

  final Future<void> Function() onRefresh;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    SettingsController? settings;
    try {
      settings = context.watch<SettingsController>();
    } catch (_) {
      settings = null;
    }
    if (settings == null) {
      return GlassList(
        children: [
          GlassRow(
            leading: const IconWell(Icons.tune_rounded),
            title: 'Notification settings',
            subtitle: 'Per-module switches',
            trailing: const RowMeta('›'),
            onTap: onOpen,
          ),
        ],
      );
    }
    final controller = settings;
    final p = controller.preferences;
    final modules = [
      p.medicineEnabled,
      p.habitEnabled,
      p.plannerEnabled,
      p.healthEnabled,
      p.generalEnabled,
    ];
    final on = modules.where((v) => v).length;
    return GlassList(
      children: [
        SwitchRow(
          icon: Icons.notifications_active_outlined,
          title: 'Enable notifications',
          subtitle: 'Master switch for all reminder delivery',
          value: p.enabled,
          onChanged: controller.loading || controller.saving
              ? null
              : (value) =>
                  controller.update(enabled: value).then((_) => onRefresh()),
        ),
        GlassRow(
          leading: const IconWell(Icons.tune_rounded),
          title: 'Per-module settings',
          subtitle: '$on of ${modules.length} categories on'
              '${p.hideSensitiveContent ? ' · sensitive content hidden' : ''}',
          trailing: const RowMeta('›'),
          onTap: onOpen,
        ),
      ],
    );
  }
}
