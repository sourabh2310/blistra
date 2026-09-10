import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';

/// Notification delivery settings backed by the backend preferences endpoint.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.onRefresh,
  });

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
    final controller = context.watch<SettingsController>();
    final preferences = controller.preferences;

    return RefreshIndicator(
      onRefresh: _load,
      child: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SwitchListTile(
                  title: const Text('Enable notifications'),
                  subtitle: const Text(
                      'Master switch for all reminder delivery'),
                  value: preferences.enabled,
                  onChanged: (value) {
                    controller.update(enabled: value).then((_) => widget.onRefresh());
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Categories',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Medicine'),
                  value: preferences.medicineEnabled,
                  onChanged: (value) {
                    controller
                        .update(medicineEnabled: value)
                        .then((_) => widget.onRefresh());
                  },
                ),
                SwitchListTile(
                  title: const Text('Habits'),
                  value: preferences.habitEnabled,
                  onChanged: (value) {
                    controller
                        .update(habitEnabled: value)
                        .then((_) => widget.onRefresh());
                  },
                ),
                SwitchListTile(
                  title: const Text('Planner'),
                  value: preferences.plannerEnabled,
                  onChanged: (value) {
                    controller
                        .update(plannerEnabled: value)
                        .then((_) => widget.onRefresh());
                  },
                ),
                SwitchListTile(
                  title: const Text('Health'),
                  value: preferences.healthEnabled,
                  onChanged: (value) {
                    controller
                        .update(healthEnabled: value)
                        .then((_) => widget.onRefresh());
                  },
                ),
                SwitchListTile(
                  title: const Text('General reminders'),
                  value: preferences.generalEnabled,
                  onChanged: (value) {
                    controller
                        .update(generalEnabled: value)
                        .then((_) => widget.onRefresh());
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Hide sensitive content'),
                  subtitle: const Text(
                      'Show generic titles for medicine, health, habit and '
                      'planner reminders on the lock screen'),
                  value: preferences.hideSensitiveContent,
                  onChanged: (value) {
                    controller
                        .update(hideSensitiveContent: value)
                        .then((_) => widget.onRefresh());
                  },
                ),
                const SizedBox(height: 8),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      controller.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}