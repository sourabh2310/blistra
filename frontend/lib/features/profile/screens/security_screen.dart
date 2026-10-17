import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_scope.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../profile_controller.dart';
import '../widgets/profile_widgets.dart';

/// Sign-in details (username, email, phone), verification and password.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final p = controller.profile;
    final emailVerified = p?.emailVerified ?? false;
    final phoneVerified = p?.phoneVerified ?? false;
    return ProfilePage(
      title: 'Sign-in & security',
      children: [
        if (p?.pendingEmail != null)
          _PendingBanner(
            text: 'Confirm ${p!.pendingEmail} to finish changing your email.',
            onConfirm: () => _confirmIdentity(context, controller, 'EMAIL'),
          ),
        if (p?.pendingPhone != null)
          _PendingBanner(
            text: 'Confirm ${p!.pendingPhone} to finish changing your phone.',
            onConfirm: () => _confirmIdentity(context, controller, 'SMS'),
          ),
        ProfileSection(
          title: 'Sign-in details',
          footer: 'You can sign in with your username, email or phone. '
              'Changes need your current password; a new email or phone '
              'only takes effect after you confirm the code sent to it.',
          children: [
            ProfileTile(
              icon: Icons.alternate_email,
              title: 'Username',
              subtitle: p == null ? '—' : '@${p.username}',
              onTap: () => _changeIdentity(context, controller, 'username'),
            ),
            ProfileTile(
              icon: Icons.mail_outline,
              title: 'Email',
              subtitle: p?.email ?? '—',
              trailing: StatusPill(
                  label: emailVerified ? 'Verified' : 'Verify',
                  positive: emailVerified),
              onTap: () => emailVerified
                  ? _changeIdentity(context, controller, 'email')
                  : _verifyChannel(context, controller, email: true),
            ),
            ProfileTile(
              icon: Icons.phone_outlined,
              title: 'Phone',
              subtitle: p?.phone ?? 'Add a phone number',
              trailing: p?.phone == null
                  ? null
                  : StatusPill(
                      label: phoneVerified ? 'Verified' : 'Verify',
                      positive: phoneVerified),
              onTap: () => p?.phone != null && !phoneVerified
                  ? _verifyChannel(context, controller, email: false)
                  : _changeIdentity(context, controller, 'phone'),
            ),
          ],
        ),
        ProfileSection(
          title: 'Password',
          children: [
            ProfileTile(
              icon: Icons.password_outlined,
              title: 'Change password',
              subtitle: 'Use 8+ characters with a letter and a digit',
              onTap: () => _changePassword(context, controller),
            ),
          ],
        ),
        ProfileSection(
          title: 'Session',
          children: [
            ProfileTile(
              icon: Icons.logout,
              title: 'Sign out of this device',
              destructive: true,
              trailing: const SizedBox.shrink(),
              onTap: () => confirmSignOut(context),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _changeIdentity(
      BuildContext context, ProfileController controller, String field) async {
    final labels = {
      'username': 'New username',
      'email': 'New email',
      'phone': 'New phone (e.g. +919876543210)',
    };
    final current = TextEditingController();
    final value = TextEditingController();
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change $field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field != 'username')
              Text(
                'We\'ll send a code to the new $field. Your current one keeps '
                'working until you confirm it.',
                style: TextStyle(
                    fontSize: 13, color: BlistraColors.resolve(context).muted),
              ),
            TextField(
              controller: value,
              autofocus: true,
              keyboardType: switch (field) {
                'email' => TextInputType.emailAddress,
                'phone' => TextInputType.phone,
                _ => TextInputType.text,
              },
              decoration: InputDecoration(labelText: labels[field]),
            ),
            TextField(
              controller: current,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Current password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, {'current': current.text, 'value': value.text.trim()}),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    current.dispose();
    value.dispose();
    if (result == null || result['value']!.isEmpty || !context.mounted) return;
    final ok = await controller.changeIdentity(
      currentPassword: result['current']!,
      username: field == 'username' ? result['value'] : null,
      email: field == 'email' ? result['value'] : null,
      phone: field == 'phone' ? result['value'] : null,
    );
    if (!context.mounted) return;
    if (!ok) {
      showProfileMessage(context, controller.error);
      return;
    }
    if (field == 'username') {
      showProfileMessage(context, 'Username updated.');
      return;
    }
    await _confirmIdentity(
        context, controller, field == 'email' ? 'EMAIL' : 'SMS');
  }

  static Future<void> _confirmIdentity(
      BuildContext context, ProfileController controller, String channel) async {
    final code = await showOtpDialog(context,
        title: 'Enter the code',
        message: channel == 'EMAIL'
            ? 'We sent a 6-digit code to your new email.'
            : 'We sent a 6-digit code to your new phone.',
        confirmLabel: 'Confirm');
    if (code == null || !context.mounted) return;
    final ok = await controller.confirmIdentity(code: code, channel: channel);
    if (!context.mounted) return;
    showProfileMessage(
        context, ok ? 'Sign-in details updated.' : controller.error);
  }

  static Future<void> _verifyChannel(
      BuildContext context, ProfileController controller,
      {required bool email}) async {
    final auth = AppScope.of(context).authState;
    int? cooldown;
    try {
      cooldown =
          email ? await auth.resendEmailOtp() : await auth.resendPhoneOtp();
    } on ApiException catch (e) {
      if (context.mounted) showProfileMessage(context, e.message);
      return;
    }
    if (!context.mounted) return;
    if (cooldown == null) {
      showProfileMessage(context, auth.lastError?.message);
      return;
    }
    final code = await showOtpDialog(context,
        title: email ? 'Verify email' : 'Verify phone',
        message: email
            ? 'Enter the 6-digit code we emailed you.'
            : 'Enter the 6-digit code we texted you.');
    if (code == null || !context.mounted) return;
    final account =
        email ? await auth.verifyEmail(code) : await auth.verifyPhone(code);
    if (!context.mounted) return;
    if (account == null) {
      showProfileMessage(context, auth.lastError?.message);
      return;
    }
    await controller.load();
  }

  static Future<void> _changePassword(
      BuildContext context, ProfileController controller) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: current,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current password')),
            TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText: '8+ characters, a letter and a digit')),
            TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirm new password')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'current': current.text,
              'next': next.text,
              'confirm': confirm.text,
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (result == null || !context.mounted) return;
    if (result['next'] != result['confirm']) {
      showProfileMessage(context, 'Passwords do not match.');
      return;
    }
    final ok = await controller.changePassword(
      currentPassword: result['current']!,
      newPassword: result['next']!,
    );
    if (!context.mounted) return;
    showProfileMessage(context, ok ? 'Password changed.' : controller.error);
  }
}

/// Asks before ending the session, then signs out.
Future<void> confirmSignOut(BuildContext context) async {
  final auth = AppScope.of(context).authState;
  final yes = await confirmAction(context,
      title: 'Sign out?',
      message: 'You\'ll need your password to sign back in on this device.',
      confirmLabel: 'Sign out');
  if (!yes || !context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
  await auth.logout();
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.text, required this.onConfirm});

  final String text;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_unread_outlined, color: colors.accentText),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, color: colors.text))),
          TextButton(onPressed: onConfirm, child: const Text('Enter code')),
        ],
      ),
    );
  }
}
