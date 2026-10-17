import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../app_update/update_dialog.dart';
import '../profile_controller.dart';
import '../widgets/profile_widgets.dart';

/// FAQ, ways to get help, and app information.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = <(String, String)>[
    (
      'How do I add something quickly?',
      'Tap the + button in the bottom bar. It opens quick actions for '
          'meals, water, doses, tasks, expenses and more.',
    ),
    (
      'My reminders aren\'t showing up',
      'Reminders are delivered by this device. Check that notifications '
          'are on in Profile > Notifications and allowed for Blistra in '
          'your phone\'s settings, and that battery saver isn\'t blocking it.',
    ),
    (
      'How does splitting expenses work?',
      'Add a friend by their username in Finance > Friends. Once they '
          'accept, you can add them to an expense and split it equally, by '
          'exact amounts, percentages or shares. Settle up any time.',
    ),
    (
      'Can I change what\'s on Home and in the bottom bar?',
      'Yes. Go to Profile > Home & navigation to show, hide and reorder '
          'sections, modules and bottom-bar tabs.',
    ),
    (
      'I forgot my password',
      'On the sign-in screen tap "Forgot password". We\'ll send a code '
          'to your verified email (or phone) to set a new one.',
    ),
    (
      'Why does "today" look wrong?',
      'Blistra uses the timezone in Profile > Language & region. If you '
          'travel, tap "Use device" there to switch to your current zone.',
    ),
    (
      'How do I delete my account?',
      'Profile > Privacy & data > Delete account. You\'ll be asked for '
          'your password, and the deletion is permanent.',
    ),
  ];

  String _diagnostics(String? userId) {
    final platform = kIsWeb ? 'web' : Platform.operatingSystem;
    return 'Blistra ${AppConfig.appVersion}'
        ' (${kReleaseMode ? 'release' : 'debug'})\n'
        'Platform: $platform\n'
        'Account: ${userId ?? 'unknown'}\n'
        'Time: ${DateTime.now().toIso8601String()}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final userId = context.watch<ProfileController>().profile?.userId;
    return ProfilePage(
      title: 'Help & support',
      children: [
        ProfileSection(
          title: 'Frequently asked',
          children: [
            for (final (q, a) in _faq)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  title: Text(q,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text)),
                  children: [
                    Text(a,
                        style: TextStyle(
                            fontSize: 14, color: colors.muted, height: 1.45)),
                  ],
                ),
              ),
          ],
        ),
        ProfileSection(
          title: 'Get in touch',
          footer: 'Include the copied details when you report a problem so '
              'we can find it faster. They contain no health or finance data.',
          children: [
            if (AppConfig.supportEmail.isNotEmpty)
              ProfileTile(
                icon: Icons.mail_outline,
                title: 'Email support',
                subtitle: AppConfig.supportEmail,
                trailing: Icon(Icons.copy, size: 18, color: colors.muted),
                onTap: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: AppConfig.supportEmail));
                  if (context.mounted) {
                    showProfileMessage(context, 'Support email copied.');
                  }
                },
              ),
            ProfileTile(
              icon: Icons.bug_report_outlined,
              title: 'Report a problem',
              subtitle: 'Copy app and device details',
              trailing: Icon(Icons.copy, size: 18, color: colors.muted),
              onTap: () async {
                await Clipboard.setData(
                    ClipboardData(text: _diagnostics(userId)));
                if (context.mounted) {
                  showProfileMessage(context, 'Details copied to clipboard.');
                }
              },
            ),
          ],
        ),
        ProfileSection(
          title: 'About',
          children: [
            ProfileTile(
              icon: Icons.info_outline,
              title: 'Blistra',
              subtitle: 'Version ${AppConfig.appVersion}'
                  '${AppConfig.appBuild > 0 ? ' · build ${AppConfig.appBuild}' : ''}',
              trailing: const SizedBox.shrink(),
            ),
            ProfileTile(
              icon: Icons.system_update_outlined,
              title: 'Check for updates',
              onTap: () => checkForUpdateAndPrompt(context, userInitiated: true),
            ),
            ProfileTile(
              icon: Icons.article_outlined,
              title: 'Open-source licences',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Blistra',
                applicationVersion: AppConfig.appVersion,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
