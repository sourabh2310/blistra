import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/reminders_controller.dart';
import '../state/settings_controller.dart';
import 'auth_screen.dart';
import 'notification_settings_screen.dart';
import 'reminders_screen.dart';

/// Root widget after authentication. Provides a bottom navigation bar between
/// the reminders list and settings.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.authController,
    required this.remindersController,
    required this.settingsController,
  });

  final AuthController authController;
  final RemindersController remindersController;
  final SettingsController settingsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages = [
    RemindersScreen(onRefresh: _syncAll),
    NotificationSettingsScreen(onRefresh: _syncAll),
  ];

  Future<void> _syncAll() async {
    await widget.remindersController.load();
    await widget.settingsController.load();
  }

  @override
  void initState() {
    super.initState();
    _syncAll();
  }

  Future<void> _logout() async {
    await widget.authController.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blistra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            selectedIcon: Icon(Icons.notifications_active),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}