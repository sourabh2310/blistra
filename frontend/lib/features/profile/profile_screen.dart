/// Blistra Profile hub: photo and identity at the top, a completeness nudge,
/// then Account, Settings, Privacy and Help groups that open focused
/// sub-screens.
///
/// Every row is backed by a real endpoint or a local setting; nothing here is
/// a placeholder.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/appearance_sheet.dart';
import '../../core/widgets/glass.dart';
import '../notifications/screens/notification_settings_screen.dart';
import '../notifications/state/settings_controller.dart';
import '../preferences/screens/customize_home_screen.dart';
import '../preferences/screens/customize_nav_screen.dart';
import 'profile_controller.dart';
import 'screens/emergency_contact_screen.dart';
import 'screens/help_screen.dart';
import 'screens/personal_info_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/region_screen.dart';
import 'screens/security_screen.dart';
import 'widgets/profile_widgets.dart';

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
      if (!controller.loading) controller.load();
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final profile = controller.profile;
    final colors = BlistraColors.resolve(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: controller.loading && profile == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                children: [
                  _Header(
                    profile: profile,
                    onPhoto: () => _photoOptions(context, controller),
                    onEdit: () => _open(const PersonalInfoScreen()),
                  ),
                  if (controller.error != null && profile == null) ...[
                    const SizedBox(height: 12),
                    _ErrorCard(message: controller.error!, onRetry: controller.load),
                  ],
                  if (profile != null)
                    _CompletenessCard(
                      profile: profile,
                      hasPhoto: controller.avatarBytes != null || profile.hasAvatar,
                      onPhoto: () => _photoOptions(context, controller),
                      onOpen: _open,
                    ),
                  ProfileSection(
                    title: 'Account',
                    children: [
                      ProfileTile(
                        icon: Icons.person_outline,
                        title: 'Personal info',
                        subtitle: _personalSummary(profile),
                        onTap: () => _open(const PersonalInfoScreen()),
                      ),
                      ProfileTile(
                        icon: Icons.contact_emergency_outlined,
                        title: 'Emergency contact',
                        tint: const Color(0xFFFDECEC),
                        subtitle: profile?.hasEmergencyContact == true
                            ? [
                                profile!.emergencyContactName,
                                profile.emergencyContactRelation,
                              ].whereType<String>().join(' · ')
                            : 'Add someone to reach in an emergency',
                        onTap: () => _open(const EmergencyContactScreen()),
                      ),
                      ProfileTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Sign-in & security',
                        subtitle: _securitySummary(profile),
                        trailing: _needsSecurityAttention(profile)
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFF79009),
                                      shape: BoxShape.circle),
                                ),
                                Icon(Icons.chevron_right, color: colors.muted),
                              ])
                            : null,
                        onTap: () => _open(const SecurityScreen()),
                      ),
                    ],
                  ),
                  ProfileSection(
                    title: 'Settings',
                    children: [
                      ProfileTile(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle: _appearanceSummary(context.watch<ThemeController>()),
                        tint: const Color(0xFFF1ECFE),
                        onTap: () => showAppearanceSheet(context),
                      ),
                      ProfileTile(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Home & navigation',
                        subtitle: 'Sections, modules and bottom bar',
                        tint: const Color(0xFFF1ECFE),
                        onTap: () => _showCustomization(context),
                      ),
                      const _NotificationsTile(),
                      ProfileTile(
                        icon: Icons.language_outlined,
                        title: 'Language & region',
                        subtitle: [
                          languageLabel(profile?.language),
                          profile?.timezone,
                          if (profile?.unitSystem != null)
                            profile!.unitSystem == 'IMPERIAL' ? 'Imperial' : 'Metric',
                        ].whereType<String>().join(' · '),
                        tint: const Color(0xFFF1ECFE),
                        onTap: () => _open(const RegionScreen()),
                      ),
                    ],
                  ),
                  ProfileSection(
                    title: 'Privacy',
                    children: [
                      ProfileTile(
                        icon: Icons.lock_outline,
                        title: 'Privacy & data',
                        subtitle: (profile?.allowFriendRequests ?? true)
                            ? 'Friend requests on · Delete account'
                            : 'Friend requests off · Delete account',
                        tint: const Color(0xFFFFF4E5),
                        onTap: () => _open(const PrivacyScreen()),
                      ),
                    ],
                  ),
                  ProfileSection(
                    title: 'Support',
                    children: [
                      ProfileTile(
                        icon: Icons.help_outline,
                        title: 'Help & support',
                        subtitle: 'FAQ, report a problem, about',
                        tint: const Color(0xFFE8F1FD),
                        onTap: () => _open(const HelpScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => confirmSignOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: onGlassDanger(context),
                      side: BorderSide(color: onGlassDanger(context).withValues(alpha: .4)),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('Blistra ${AppConfig.appVersion}',
                        style: TextStyle(fontSize: 12, color: colors.muted)),
                  ),
                ],
              ),
      ),
    );
  }

  static Color onGlassDanger(BuildContext context) =>
      onGlass(context, const Color(0xFFB42318));

  static String _personalSummary(UserProfileDto? p) {
    if (p == null) return 'Name, bio, birthday';
    final parts = <String>[
      if ((p.displayName ?? '').isNotEmpty) p.displayName!,
      if (p.age != null) '${p.age} yrs',
      if (p.country != null) countryLabel(p.country).split('  ').first,
    ];
    return parts.isEmpty ? 'Name, bio, birthday' : parts.join(' · ');
  }

  static bool _needsSecurityAttention(UserProfileDto? p) =>
      p != null &&
      (!p.emailVerified ||
          (p.phone != null && !p.phoneVerified) ||
          p.pendingEmail != null ||
          p.pendingPhone != null);

  static String _securitySummary(UserProfileDto? p) {
    if (p == null) return 'Password, email & phone';
    if (p.pendingEmail != null || p.pendingPhone != null) {
      return 'A change is waiting for its code';
    }
    if (!p.emailVerified) return 'Email not verified yet';
    if (p.phone != null && !p.phoneVerified) return 'Phone not verified yet';
    return 'Password, email & phone · all verified';
  }

  static String _appearanceSummary(ThemeController c) {
    final mode = switch (c.mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
    return '$mode · ${c.accent.label}';
  }

  Future<void> _photoOptions(BuildContext context, ProfileController controller) async {
    if (controller.photoBusy || controller.profile == null) return;
    final hasPhoto = controller.profile!.hasAvatar;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(hasPhoto ? 'Choose a new photo' : 'Add a photo'),
              subtitle: const Text('JPEG, PNG or WebP · up to 5 MB'),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: onGlassDanger(context)),
                title: Text('Remove photo',
                    style: TextStyle(color: onGlassDanger(context))),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'remove') {
      final ok = await controller.removeAvatar();
      if (!ok && context.mounted) showProfileMessage(context, controller.error);
      return;
    }
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
    } catch (_) {
      if (context.mounted) showProfileMessage(context, 'Could not open your photos.');
      return;
    }
    final file = result?.files.single;
    if (file == null || !context.mounted) return;
    final bytes = file.bytes;
    if (bytes == null) {
      showProfileMessage(context, 'Could not read that photo.');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      showProfileMessage(context, 'Photo must be 5 MB or smaller.');
      return;
    }
    final ok = await controller.uploadAvatar(bytes, file.name);
    if (!context.mounted) return;
    showProfileMessage(context, ok ? 'Profile photo updated.' : controller.error);
  }

  Future<void> _showCustomization(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Home sections & modules'),
              onTap: () => Navigator.pop(context, 'home'),
            ),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Bottom navigation'),
              onTap: () => Navigator.pop(context, 'navigation'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    _open(choice == 'navigation'
        ? const CustomizeNavScreen()
        : const CustomizeHomeScreen());
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onPhoto, required this.onEdit});

  final UserProfileDto? profile;
  final VoidCallback onPhoto;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final name = profileDisplayName(context);
    final p = profile;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: colors.gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: .3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ProfileAvatar(radius: 46, editable: true, onTap: onPhoto),
          const SizedBox(height: 14),
          Text(
            name.isEmpty ? 'Your profile' : name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (p != null) ...[
            const SizedBox(height: 2),
            Text('@${p.username}',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
          if ((p?.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(p!.bio!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
          ],
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p?.memberSince != null)
                _HeaderChip(
                    icon: Icons.calendar_month_outlined,
                    label: 'Since ${formatMonthYear(p!.memberSince!)}'),
              if (p != null)
                _HeaderChip(
                  icon: p.emailVerified
                      ? Icons.verified_outlined
                      : Icons.error_outline,
                  label: p.emailVerified ? 'Verified' : 'Email unverified',
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .22),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// "Finish your profile" nudge; disappears once every step is done.
class _CompletenessCard extends StatelessWidget {
  const _CompletenessCard({
    required this.profile,
    required this.hasPhoto,
    required this.onPhoto,
    required this.onOpen,
  });

  final UserProfileDto profile;
  final bool hasPhoto;
  final VoidCallback onPhoto;
  final void Function(Widget screen) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final steps = <(String, bool, VoidCallback)>[
      ('Add a photo', hasPhoto, onPhoto),
      ('Add your name', (profile.displayName ?? '').isNotEmpty,
          () => onOpen(const PersonalInfoScreen())),
      ('Add your birthday', profile.dateOfBirth != null,
          () => onOpen(const PersonalInfoScreen())),
      ('Verify email', profile.emailVerified, () => onOpen(const SecurityScreen())),
      ('Add a phone', profile.phone != null, () => onOpen(const SecurityScreen())),
      ('Emergency contact', profile.hasEmergencyContact,
          () => onOpen(const EmergencyContactScreen())),
    ];
    final done = steps.where((s) => s.$2).length;
    if (done == steps.length) return const SizedBox.shrink();
    final progress = done / steps.length;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Finish your profile',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: colors.text)),
              ),
              Text('${(progress * 100).round()}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: colors.accentText)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.glassBorder,
              color: colors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, complete, onTap) in steps)
                if (!complete)
                  ActionChip(
                    avatar: Icon(Icons.add, size: 16, color: colors.accentText),
                    label: Text(label),
                    onPressed: onTap,
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationsTile extends StatelessWidget {
  const _NotificationsTile();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return ProfileTile(
      icon: Icons.notifications_outlined,
      title: 'Notifications',
      subtitle: settings.saving
          ? 'Saving…'
          : settings.preferences.enabled
              ? 'On · choose which reminders you get'
              : 'All reminders paused',
      tint: const Color(0xFFF1ECFE),
      trailing: Switch(
        value: settings.preferences.enabled,
        onChanged: settings.saving ? null : (v) => settings.update(enabled: v),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Notifications'),
            backgroundColor: Colors.transparent,
          ),
          body: NotificationSettingsScreen(
            onRefresh: () => context.read<SettingsController>().load(),
          ),
        ),
      )),
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
        color: softBg(context, const Color(0xFFFDECEC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13, color: _ProfileScreenState.onGlassDanger(context))),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
