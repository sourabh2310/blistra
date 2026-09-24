/// Blistra Profile section: personal, health, preferences, security.
///
/// Every row is backed by a real endpoint: profile GET/PUT, identity
/// change + OTP confirmation, health profile (read), notification
/// preferences, change password, logout. Unsupported controls (e.g. account
/// deletion, avatar upload) are omitted, never faked.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../dashboard/models/dashboard_response.dart';
import '../notifications/state/settings_controller.dart';
import '../preferences/screens/customize_home_screen.dart';
import '../preferences/screens/customize_nav_screen.dart';
import 'profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ProfileController>();
      if (controller.profile == null && !controller.loading) {
        controller.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final controller = context.watch<ProfileController>();
    final profile = controller.profile;
    final name = resolveDisplayName(
      user: scope.dashboard.dashboard?.user,
      email: scope.authState.userEmail,
    );
    final displayName = (profile?.displayName?.isNotEmpty == true)
        ? profile!.displayName!
        : name;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFFFFFBF6),
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: controller.loading && profile == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _HeaderCard(
                    displayName: displayName,
                    email: profile?.email ?? scope.authState.userEmail,
                    username: profile?.username ?? scope.authState.username,
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorCard(
                      message: controller.error!,
                      onRetry: controller.load,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Personal',
                    children: [
                      _Row(
                        icon: Icons.badge_outlined,
                        label: 'Display name',
                        value: profile?.displayName ?? '—',
                        onTap: () =>
                            _editProfileField(context, controller, 'displayName'),
                      ),
                      _Row(
                        icon: Icons.alternate_email,
                        label: 'Username',
                        value: profile?.username ?? '—',
                        onTap: () =>
                            _changeIdentity(context, controller, 'username'),
                      ),
                      _Row(
                        icon: Icons.mail_outline,
                        label: 'Email',
                        value: profile?.email ?? '—',
                        trailing: _VerifiedChip(
                            verified: profile?.emailVerified ?? false),
                        onTap: () =>
                            _changeIdentity(context, controller, 'email'),
                      ),
                      _Row(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: profile?.phone ?? 'Not set',
                        trailing: profile?.phone == null
                            ? null
                            : _VerifiedChip(
                                verified: profile?.phoneVerified ?? false),
                        onTap: () =>
                            _changeIdentity(context, controller, 'phone'),
                      ),
                      _Row(
                        icon: Icons.cake_outlined,
                        label: 'Date of birth',
                        value: profile?.dateOfBirth ??
                            (profile?.age != null
                                ? 'Age ${profile!.age}'
                                : '—'),
                        subtitle: profile?.age != null
                            ? 'Age ${profile!.age} (from date of birth)'
                            : null,
                        onTap: () =>
                            _editProfileField(context, controller, 'dob'),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Health',
                    children: [
                      _Row(
                        icon: Icons.monitor_weight_outlined,
                        label: 'Height & weight',
                        value: 'Managed in Health',
                        subtitle:
                            'Height lives on your health profile; weight is a Health measurement.',
                        onTap: null,
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Preferences',
                    children: [
                      _Row(
                        icon: Icons.public_outlined,
                        label: 'Country',
                        value: profile?.country ?? '—',
                        onTap: () =>
                            _editProfileField(context, controller, 'country'),
                      ),
                      _Row(
                        icon: Icons.schedule_outlined,
                        label: 'Timezone',
                        value: profile?.timezone ?? '—',
                        onTap: () =>
                            _editProfileField(context, controller, 'timezone'),
                      ),
                      _Row(
                        icon: Icons.language_outlined,
                        label: 'Language',
                        value: profile?.language ?? '—',
                        onTap: () =>
                            _editProfileField(context, controller, 'language'),
                      ),
                      _Row(
                        icon: Icons.straighten_outlined,
                        label: 'Units',
                        value: profile?.unitSystem == 'IMPERIAL'
                            ? 'Imperial'
                            : 'Metric',
                        onTap: () =>
                            _editProfileField(context, controller, 'units'),
                      ),
                      _Row(
                        icon: Icons.dashboard_customize_outlined,
                        label: 'Customize Home',
                        value: 'Widgets and layout',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const CustomizeHomeScreen(),
                          ),
                        ),
                      ),
                      _Row(
                        icon: Icons.tune_outlined,
                        label: 'Customize Navigation',
                        value: 'Bottom bar destinations',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CustomizeNavScreen(),
                          ),
                        ),
                      ),
                      const _NotificationRow(),
                    ],
                  ),
                  _Section(
                    title: 'Security',
                    children: [
                      _Row(
                        icon: Icons.mark_email_read_outlined,
                        label: 'Email verification',
                        value: (profile?.emailVerified ?? false)
                            ? 'Verified'
                            : 'Not verified',
                        trailing: (profile?.emailVerified ?? false)
                            ? null
                            : const _ActionChip(label: 'Verify'),
                        onTap: (profile?.emailVerified ?? false)
                            ? null
                            : () => _verifyChannel(
                                context, controller, email: true),
                      ),
                      if (profile?.phone != null)
                        _Row(
                          icon: Icons.sms_outlined,
                          label: 'Phone verification',
                          value: (profile?.phoneVerified ?? false)
                              ? 'Verified'
                              : 'Not verified',
                          trailing: (profile?.phoneVerified ?? false)
                              ? null
                              : const _ActionChip(label: 'Verify'),
                          onTap: (profile?.phoneVerified ?? false)
                              ? null
                              : () => _verifyChannel(
                                  context, controller, email: false),
                        ),
                      _Row(
                        icon: Icons.password_outlined,
                        label: 'Change password',
                        value: 'Update your sign-in password',
                        onTap: () => _changePassword(context, controller),
                      ),
                      _Row(
                        icon: Icons.logout,
                        label: 'Sign out',
                        value: 'End this session',
                        onTap: () => scope.authState.logout(),
                      ),
                    ],
                  ),
                  _Section(
                    title: 'Account',
                    children: [
                      _Row(
                        icon: Icons.info_outline,
                        label: 'Status',
                        value: profile?.status == 'ACTIVE'
                            ? 'Active'
                            : 'Verification pending',
                      ),
                      _Row(
                        icon: Icons.task_alt_outlined,
                        label: 'Onboarding',
                        value: (profile?.onboardingCompleted ?? false)
                            ? 'Complete'
                            : 'Incomplete',
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  // ── Personal/profile editing ───────────────────────────────────

  Future<void> _editProfileField(
      BuildContext context, ProfileController controller, String field) async {
    final profile = controller.profile;
    if (profile == null) return;
    if (field == 'dob') {
      final now = DateTime.now();
      DateTime? initial;
      if (profile.dateOfBirth != null) {
        initial = DateTime.tryParse(profile.dateOfBirth!);
      }
      final picked = await showDatePicker(
        context: context,
        initialDate: initial ?? DateTime(now.year - 25, now.month, now.day),
        firstDate: DateTime(1900),
        lastDate: now,
      );
      if (picked == null || !context.mounted) return;
      final ok = await controller.save({
        'dateOfBirth':
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
      });
      if (!ok && context.mounted) _showError(context, controller);
      return;
    }
    if (field == 'units') {
      final units = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Unit system'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'METRIC'),
              child: const Text('Metric (cm, kg)'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'IMPERIAL'),
              child: const Text('Imperial (in, lb)'),
            ),
          ],
        ),
      );
      if (units == null || !context.mounted) return;
      final ok = await controller.save({'unitSystem': units});
      if (!ok && context.mounted) _showError(context, controller);
      return;
    }
    final labels = {
      'displayName': 'Display name',
      'country': 'Country (2-letter code, e.g. IN)',
      'timezone': 'Timezone (e.g. Asia/Kolkata)',
      'language': 'Language (e.g. en)',
    };
    final initial = {
      'displayName': profile.displayName ?? '',
      'country': profile.country ?? '',
      'timezone': profile.timezone ?? '',
      'language': profile.language ?? '',
    }[field]!;
    final text = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(labels[field]!),
        content: TextField(controller: text, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, text.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    text.dispose();
    if (value == null || !context.mounted) return;
    final ok = await controller.save({field: value});
    if (!ok && context.mounted) _showError(context, controller);
  }

  // ── Identity change + OTP confirmation ─────────────────────────

  Future<void> _changeIdentity(
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
        title: Text('Change ${field == 'username' ? 'username' : field}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field != 'username')
              const Text(
                'Email/phone changes take effect only after you confirm the code sent to the new address.',
                style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
              ),
            TextField(
              controller: value,
              autofocus: true,
              decoration: InputDecoration(labelText: labels[field]),
            ),
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Current password (required)'),
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
    if (result == null || !context.mounted) return;
    final ok = await controller.changeIdentity(
      currentPassword: result['current']!,
      username: field == 'username' ? result['value'] : null,
      email: field == 'email' ? result['value'] : null,
      phone: field == 'phone' ? result['value'] : null,
    );
    if (!context.mounted) return;
    if (!ok) {
      _showError(context, controller);
      return;
    }
    if ((field == 'email' || field == 'phone') && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Code sent. Confirm it to finish the change.')),
      );
      await _confirmIdentity(
          context, controller, field == 'email' ? 'EMAIL' : 'SMS');
    }
  }

  Future<void> _confirmIdentity(
      BuildContext context, ProfileController controller, String channel) async {
    final code = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm the change'),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
          decoration: const InputDecoration(
              hintText: '••••••', counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, code.text.trim()),
              child: const Text('Confirm')),
        ],
      ),
    );
    code.dispose();
    if (result == null || result.isEmpty || !context.mounted) return;
    final ok =
        await controller.confirmIdentity(code: result, channel: channel);
    if (!context.mounted) return;
    if (!ok) {
      _showError(context, controller);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign-in details updated.')),
    );
  }

  Future<void> _verifyChannel(
      BuildContext context, ProfileController controller,
      {required bool email}) async {
    final auth = AppScope.of(context).authState;
    int? cooldown;
    try {
      cooldown =
          email ? await auth.resendEmailOtp() : await auth.resendPhoneOtp();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!context.mounted) return;
    if (cooldown == null) {
      _showErrorText(context, auth.lastError?.message);
      return;
    }
    final code = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(email ? 'Verify email' : 'Verify phone'),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
          decoration: const InputDecoration(
              hintText: '••••••', counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, code.text.trim()),
              child: const Text('Verify')),
        ],
      ),
    );
    code.dispose();
    if (result == null || result.isEmpty || !context.mounted) return;
    final account =
        email ? await auth.verifyEmail(result) : await auth.verifyPhone(result);
    if (!context.mounted) return;
    if (account == null) {
      _showErrorText(context, auth.lastError?.message);
      return;
    }
    await controller.load();
  }

  Future<void> _changePassword(
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
                    labelText: 'New password (8+ chars, letter + digit)')),
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
      _showErrorText(context, 'Passwords do not match.');
      return;
    }
    final ok = await controller.changePassword(
      currentPassword: result['current']!,
      newPassword: result['next']!,
    );
    if (!context.mounted) return;
    if (!ok) {
      _showError(context, controller);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed.')),
    );
  }

  void _showError(BuildContext context, ProfileController controller) {
    _showErrorText(context, controller.error);
  }

  void _showErrorText(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(message ?? 'Something went wrong. Please try again.')),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.displayName,
    required this.email,
    required this.username,
  });

  final String displayName;
  final String email;
  final String username;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E6E6E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFF3D9C8),
            child: Text(
              initialsForName(displayName),
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Color(0xFF5B3A29)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(email,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                Text('@$username',
                    style: const TextStyle(
                        color: Color(0xFF8FE3C8), fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
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
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF667085),
                  letterSpacing: 0.4)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EDE8)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F6F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF0C6B6B), size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF667085))),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF101828))),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF667085))),
        ],
      ),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right, color: Color(0xFF98A2B3))
              : null),
      onTap: onTap,
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            verified ? const Color(0xFFE6F6F3) : const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        verified ? 'Verified' : 'Unverified',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: verified
              ? const Color(0xFF0C6B6B)
              : const Color(0xFFB42318),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C6B6B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFB42318))),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F6F3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.notifications_outlined,
            color: Color(0xFF0C6B6B), size: 20),
      ),
      title: const Text('Notifications',
          style: TextStyle(fontSize: 13, color: Color(0xFF667085))),
      subtitle: Text(
          settings.saving ? 'Saving…' : 'Reminder delivery master switch',
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF101828))),
      trailing: Switch(
        value: settings.preferences.enabled,
        onChanged: settings.saving
            ? null
            : (v) => settings.update(enabled: v),
      ),
    );
  }
}
