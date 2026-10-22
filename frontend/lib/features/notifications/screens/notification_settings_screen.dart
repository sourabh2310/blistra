import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../models/reminder_type.dart';
import '../state/settings_controller.dart';
import 'reminder_visuals.dart';

/// Notification delivery settings backed by the backend preferences endpoint.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<SettingsController>().load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<SettingsController>();
    final preferences = controller.preferences;
    // Callers may wrap this in a Scaffold with its own AppBar.
    final hasAppBar = Scaffold.maybeOf(context)?.hasAppBar ?? false;

    void set(Future<void> Function() change) =>
        change().then((_) => widget.onRefresh());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (!hasAppBar)
            const BlistraPageHeader(
              eyebrow: 'Notifications',
              title: 'Settings',
              showAvatar: false,
            ),
          if (controller.loading) ...[
            const SizedBox(height: 16),
            const SkeletonLoader(rows: 4),
          ] else ...[
            PagePad(
              GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: colors.accentText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reminders use this device and may be delayed by battery settings. '
                        'The next 60 alerts are scheduled; medicine alerts cover the next 7 days. '
                        'Open Blistra regularly to refresh them.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              top: 10,
            ),
            const SizedBox(height: 14),
            PagePad(GlassList(
              children: [
                SwitchRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Enable notifications',
                  subtitle: 'Master switch for all reminder delivery',
                  value: preferences.enabled,
                  onChanged: (value) =>
                      set(() => controller.update(enabled: value)),
                ),
              ],
            )),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Categories'),
            PagePad(GlassList(
              children: [
                SwitchRow(
                  icon: reminderIcon(ReminderType.medicine),
                  color: reminderColor(context, ReminderType.medicine),
                  title: 'Medicine',
                  value: preferences.medicineEnabled,
                  onChanged: (value) =>
                      set(() => controller.update(medicineEnabled: value)),
                ),
                SwitchRow(
                  icon: reminderIcon(ReminderType.habit),
                  color: reminderColor(context, ReminderType.habit),
                  title: 'Habits',
                  value: preferences.habitEnabled,
                  onChanged: (value) =>
                      set(() => controller.update(habitEnabled: value)),
                ),
                SwitchRow(
                  icon: reminderIcon(ReminderType.planner),
                  color: reminderColor(context, ReminderType.planner),
                  title: 'Planner',
                  value: preferences.plannerEnabled,
                  onChanged: (value) =>
                      set(() => controller.update(plannerEnabled: value)),
                ),
                SwitchRow(
                  icon: reminderIcon(ReminderType.health),
                  color: reminderColor(context, ReminderType.health),
                  title: 'Health',
                  value: preferences.healthEnabled,
                  onChanged: (value) =>
                      set(() => controller.update(healthEnabled: value)),
                ),
                SwitchRow(
                  icon: reminderIcon(ReminderType.general),
                  color: reminderColor(context, ReminderType.general),
                  title: 'General reminders',
                  value: preferences.generalEnabled,
                  onChanged: (value) =>
                      set(() => controller.update(generalEnabled: value)),
                ),
              ],
            )),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Privacy'),
            PagePad(GlassList(
              children: [
                SwitchRow(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide sensitive content',
                  subtitle: 'Generic lock-screen titles for medicine, health, '
                      'habit and planner reminders',
                  value: preferences.hideSensitiveContent,
                  onChanged: (value) =>
                      set(() => controller.update(hideSensitiveContent: value)),
                ),
              ],
            )),
            if (controller.error != null)
              PagePad(
                Text(
                  controller.error!,
                  style: TextStyle(fontSize: 12, color: colors.danger),
                ),
                top: 12,
              ),
          ],
        ],
      ),
    );
  }
}
