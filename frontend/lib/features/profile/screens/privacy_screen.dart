import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../profile_controller.dart';
import '../widgets/profile_widgets.dart';

/// Who can reach you, what Blistra keeps, and deleting your account.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final p = controller.profile;
    final colors = BlistraColors.resolve(context);
    return ProfilePage(
      title: 'Privacy & data',
      children: [
        ProfileSection(
          title: 'Visibility',
          footer: 'When off, people can\'t find you by username to send a '
              'friend request. Existing friends and shared expenses are '
              'not affected, and you can still add others.',
          children: [
            ProfileTile(
              icon: Icons.group_add_outlined,
              title: 'Allow friend requests',
              subtitle: 'Others can add you to split expenses',
              trailing: Switch(
                value: p?.allowFriendRequests ?? true,
                onChanged: controller.saving || p == null
                    ? null
                    : (v) async {
                        final ok =
                            await controller.save({'allowFriendRequests': v});
                        if (!ok && context.mounted) {
                          showProfileMessage(context, controller.error);
                        }
                      },
              ),
            ),
          ],
        ),
        ProfileSection(
          title: 'Your data',
          children: const [
            _InfoTile(
              icon: Icons.lock_outline,
              title: 'Private by default',
              body: 'Health, diet, medicines, documents, habits and planner '
                  'data are visible only to you. Friends only see your name, '
                  'username, and the expenses you share with them.',
            ),
            _InfoTile(
              icon: Icons.shield_outlined,
              title: 'Only you can open your files',
              body: 'Your session token is kept in the device\'s secure '
                  'storage. Documents and your photo are served only to '
                  'your signed-in account.',
            ),
            _InfoTile(
              icon: Icons.notifications_none_outlined,
              title: 'Reminders stay on this device',
              body: 'Medicine and task reminders are scheduled locally by '
                  'this phone\'s notification system.',
            ),
          ],
        ),
        ProfileSection(
          title: 'Danger zone',
          children: [
            ProfileTile(
              icon: Icons.delete_forever_outlined,
              title: 'Delete account',
              subtitle: 'Permanently erase your account and data',
              destructive: true,
              onTap: () => _deleteAccount(context, controller),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Text(
            'Expenses you shared with friends stay in their history under '
            '"Deleted user" so their balances remain correct.',
            style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
          ),
        ),
      ],
    );
  }

  static Future<void> _deleteAccount(
      BuildContext context, ProfileController controller) async {
    final sure = await confirmAction(
      context,
      title: 'Delete your account?',
      message: 'This permanently erases your profile, photo, health records, '
          'meals, medicines, habits, planner, documents and personal '
          'finances. It cannot be undone.',
      confirmLabel: 'Continue',
    );
    if (!sure || !context.mounted) return;

    final password = TextEditingController();
    final confirmed = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm with your password'),
        content: TextField(
          controller: password,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, password.text),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    password.dispose();
    if (confirmed == null || confirmed.isEmpty || !context.mounted) return;

    final auth = AppScope.of(context).authState;
    final ok = await controller.deleteAccount(currentPassword: confirmed);
    if (!context.mounted) return;
    if (!ok) {
      showProfileMessage(context, controller.error);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
    messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')));
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colors.accentText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.text)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        fontSize: 13, color: colors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
