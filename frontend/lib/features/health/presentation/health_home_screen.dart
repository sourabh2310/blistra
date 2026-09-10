import 'package:flutter/material.dart';

import '../health_models.dart';
import '../health_repository.dart';
import 'widgets.dart';
import 'appointments_screen.dart';
import 'events_screen.dart';
import 'measurements_screen.dart';
import 'profile_screen.dart';
import 'sleep_screen.dart';
import 'activity_screen.dart';
import 'logs_screen.dart';

/// Root screen for the authenticated Health feature.
///
/// Shows a compact profile summary and a card per owned resource. Logging out
/// clears the session so the parent widget returns to the login screen.
class HealthHomeScreen extends StatefulWidget {
  const HealthHomeScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final HealthRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<HealthHomeScreen> createState() => _HealthHomeScreenState();
}

class _ResourceEntry {
  const _ResourceEntry(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _HealthHomeScreenState extends State<HealthHomeScreen> {
  static const List<_ResourceEntry> _resources = [
    _ResourceEntry(Icons.person_outline, 'Profile'),
    _ResourceEntry(Icons.monitor_weight_outlined, 'Measurements'),
    _ResourceEntry(Icons.bedtime_outlined, 'Sleep'),
    _ResourceEntry(Icons.directions_run, 'Activity'),
    _ResourceEntry(Icons.assignment_outlined, 'Health logs'),
    _ResourceEntry(Icons.event_note_outlined, 'Events'),
    _ResourceEntry(Icons.calendar_month_outlined, 'Appointments'),
  ];

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    try {
      await widget.repository.loadProfile();
    } catch (_) {
      // A profile GET that fails (e.g. transient network) should not block the
      // home screen; the summary simply stays hidden and retry happens on the
      // next refresh.
    }
  }

  Future<void> _openResource(int index) async {
    switch (index) {
      case 0:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileScreen(repository: widget.repository),
          ),
        );
        return;
      case 1:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MeasurementsScreen(repository: widget.repository),
          ),
        );
        return;
      case 2:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SleepScreen(repository: widget.repository),
          ),
        );
        return;
      case 3:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityScreen(repository: widget.repository),
          ),
        );
        return;
      case 4:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LogsScreen(repository: widget.repository),
          ),
        );
        return;
      case 5:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EventsScreen(repository: widget.repository),
          ),
        );
        return;
      case 6:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AppointmentsScreen(repository: widget.repository),
          ),
        );
        return;
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Sign out of this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final HealthRepository repository = widget.repository;
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Health'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: _confirmLogout,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshProfile,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (repository.profile != null)
                  _ProfileCard(profile: repository.profile!),
                const SizedBox(height: 8),
                ..._buildResourceRows(context, repository),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildResourceRows(BuildContext context, HealthRepository repository) {
    final List<Widget> rows = [];
    for (int i = 0; i < _resources.length; i++) {
      final _ResourceEntry entry = _resources[i];
      rows.add(
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(entry.icon, color: Theme.of(context).colorScheme.primary),
            title: Text(entry.label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openResource(i),
          ),
        ),
      );
    }
    return rows;
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _summary(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(ThemeData theme) {
    final List<String> parts = [];
    final double? height = profile.heightCm;
    final String birthDate = formatDate(profile.dateOfBirth);
    if (height != null) {
      parts.add('${formatDouble(height)} cm');
    }
    if (birthDate.isNotEmpty) {
      parts.add('Born $birthDate');
    }
    if (parts.isEmpty) {
      return Text(
        'Tap Profile to set your details.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}