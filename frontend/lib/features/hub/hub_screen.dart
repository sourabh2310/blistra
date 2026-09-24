/// Hub: "Everything in one place."
///
/// Curated replacement for the technical "Modules" list. Groups only features
/// that actually exist in the app; tiles route through [onDestination] so the
/// shell decides tab-select vs push. Same warm/off-white + teal language as
/// Home. No account actions here — logout lives in Profile.
library;

import 'package:flutter/material.dart';

import '../../core/widgets/module_guard.dart';
import '../documents/documents_page.dart';
import '../notifications/screens/notification_settings_screen.dart';
import '../notifications/screens/reminders_screen.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({
    super.key,
    required this.onDestination,
    required this.onRefreshNotifications,
    this.onCustomizeNavigation,
  });

  /// Shell-level navigation: destination ids (HOME/PLANNER/HEALTH/...).
  final void Function(String destinationId) onDestination;
  final Future<void> Function() onRefreshNotifications;
  final VoidCallback? onCustomizeNavigation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: const Text(
          'Hub',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        backgroundColor: const Color(0xFFFFFBF6),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          const Text(
            'Everything in your life, organized.',
            style: TextStyle(fontSize: 14.5, color: Color(0xFF8A94A6)),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'WELLBEING',
            children: [
              _HubTile(
                color: const Color(0xFFFFECEC),
                iconBg: const Color(0xFFFFD9D9),
                iconColor: const Color(0xFFE5484D),
                icon: Icons.favorite_outline,
                title: 'Health',
                subtitle: 'Activity, sleep, measurements',
                onTap: () => onDestination('HEALTH'),
              ),
              _HubTile(
                color: const Color(0xFFEAF5FF),
                iconBg: Colors.white,
                iconColor: const Color(0xFF3E9BE9),
                icon: Icons.medication_outlined,
                title: 'Medicines',
                subtitle: 'Schedules, doses, refills',
                onTap: () => onDestination('MEDICINES'),
              ),
              _HubTile(
                color: const Color(0xFFEDF9E8),
                iconBg: const Color(0xFFD9F0D2),
                iconColor: const Color(0xFF3E8E41),
                icon: Icons.restaurant_outlined,
                title: 'Diet',
                subtitle: 'Meals, water, nutrition',
                onTap: () => onDestination('DIET'),
              ),
              _HubTile(
                color: const Color(0xFFF1EAFE),
                iconBg: const Color(0xFFDCCBFF),
                iconColor: const Color(0xFF7C3AED),
                icon: Icons.check_circle_outline,
                title: 'Habits',
                subtitle: 'Streaks, daily progress',
                onTap: () => onDestination('HABITS'),
              ),
            ],
          ),
          _Section(
            title: 'PLANNING',
            children: [
              _HubTile(
                color: const Color(0xFFE6F6F3),
                iconBg: Colors.white,
                iconColor: const Color(0xFF0C6B6B),
                icon: Icons.calendar_today_outlined,
                title: 'Planner',
                subtitle: 'Tasks, events, schedule',
                onTap: () => onDestination('PLANNER'),
              ),
              _HubTile(
                color: const Color(0xFFF1F4F6),
                iconBg: Colors.white,
                iconColor: const Color(0xFF3E4A5A),
                icon: Icons.notifications_outlined,
                title: 'Reminders',
                subtitle: 'Alerts and schedules',
                onTap: () => pushModulePage(
                  context,
                  RemindersScreen(onRefresh: onRefreshNotifications),
                  title: 'Reminders',
                  ownAppBar: false,
                ),
              ),
            ],
          ),
          _Section(
            title: 'MONEY',
            children: [
              _HubTile(
                color: const Color(0xFFE9F8F1),
                iconBg: const Color(0xFFC9EBDD),
                iconColor: const Color(0xFF0C6B6B),
                icon: Icons.account_balance_wallet_outlined,
                title: 'Finance',
                subtitle: 'Expenses, accounts, transactions',
                onTap: () => onDestination('FINANCE'),
              ),
            ],
          ),
          _Section(
            title: 'OTHER',
            children: [
              _HubTile(
                color: const Color(0xFFFFF4E3),
                iconBg: const Color(0xFFFFE3B3),
                iconColor: const Color(0xFFE8890C),
                icon: Icons.folder_outlined,
                title: 'Documents',
                subtitle: 'Files, reports, PDFs',
                onTap: () => pushModulePage(
                  context,
                  const DocumentsPage(),
                  title: 'Documents',
                ),
              ),
              _HubTile(
                color: const Color(0xFFF1F4F6),
                iconBg: Colors.white,
                iconColor: const Color(0xFF3E4A5A),
                icon: Icons.settings_outlined,
                title: 'Notifications',
                subtitle: 'Preferences and devices',
                onTap: () => pushModulePage(
                  context,
                  NotificationSettingsScreen(
                      onRefresh: onRefreshNotifications),
                  title: 'Notifications',
                  ownAppBar: false,
                ),
              ),
            ],
          ),
          if (onCustomizeNavigation != null) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: onCustomizeNavigation,
              icon: const Icon(Icons.tune),
              label: const Text('Customize navigation'),
            ),
          ],
        ],
      ),
    );
  }
}



class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF667085))),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: children,
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.color,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF3E5A6B),
              ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Text(
                  'Open',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C6B6B),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Color(0xFF0C6B6B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

