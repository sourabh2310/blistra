import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_scope.dart';
import '../../../core/auth/google_sign_in_service.dart';
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
          footer:
              'When off, people can\'t find you by username to send a '
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
                        final ok = await controller.save({
                          'allowFriendRequests': v,
                        });
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
              body:
                  'Health, diet, medicines, documents, habits and planner '
                  'data are visible only to you. Friends only see your name, '
                  'username, and the expenses you share with them.',
            ),
            _InfoTile(
              icon: Icons.shield_outlined,
              title: 'Only you can open your files',
              body:
                  'Native devices use secure storage when available; otherwise '
                  'your session is kept in memory. Documents and photos require '
                  'your signed-in account. Files opened in other apps may remain there.',
            ),
            _InfoTile(
              icon: Icons.notifications_none_outlined,
              title: 'Reminders stay on this device',
              body:
                  'Medicine and task reminders are scheduled locally by '
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
              subtitle: 'Deactivate your account and sign out',
              destructive: true,
              onTap: () => _deleteAccount(context, controller),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          child: Text(
            'Deleting deactivates your account and keeps your data. Shared '
            'expenses and settlement history stay visible to participants '
            'under "Deleted user".',
            style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4),
          ),
        ),
      ],
    );
  }

  static Future<void> _deleteAccount(
    BuildContext context,
    ProfileController controller,
  ) async {
    final sure = await confirmAction(
      context,
      title: 'Delete your account?',
      message:
          'Your account will be deactivated and you will be signed out. '
          'Your data is kept but can no longer be reached with this account, '
          'and you can register again any time with the same email, phone '
          'or Google account.',
      confirmLabel: 'Continue',
    );
    if (!sure || !context.mounted) return;

    String? password;
    String? idToken;
    if (controller.profile?.googleLinked == true) {
      try {
        idToken = await googleIdTokenProvider.getIdToken();
        if (idToken == null) return; // dismissed the Google account picker
      } on GoogleSignInUnavailable {
        // Fall back to the password below.
      }
    }
    if (idToken == null) {
      if (!context.mounted) return;
      password = await showDialog<String>(
        context: context,
        builder: (_) => const _PasswordDialog(),
      );
      if (password == null || password.isEmpty) return;
    }
    if (!context.mounted) return;

    final auth = AppScope.of(context).authState;
    final ok = await controller.deleteAccount(
      currentPassword: password,
      googleIdToken: idToken,
    );
    if (!context.mounted) return;
    if (!ok) {
      showProfileMessage(context, controller.error);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Your account has been deactivated. You can register again any time.',
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm with your password'),
      content: TextField(
        controller: _password,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Current password'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, _password.text),
          child: const Text('Deactivate account'),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

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
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
