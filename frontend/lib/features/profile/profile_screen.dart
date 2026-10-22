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
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/page_header.dart';
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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          // Not lazy: the page is short and every row stays reachable by
          // ensureVisible in both directions.
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BlistraPageHeader(
                  eyebrow: 'Profile',
                  title: 'Settings',
                  showAvatar: false,
                  padding: EdgeInsets.only(top: 8, bottom: 6),
                ),
                const SizedBox(height: 8),
                if (controller.loading && profile == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
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
                    ],
                  ),
                  ProfileSection(
                    title: 'Preferences',
                    children: [
                      ProfileTile(
                        icon: Icons.palette_outlined,
                        title: 'Appearance',
                        subtitle: _appearanceSummary(context.watch<ThemeController>()),
                        onTap: () => showAppearanceSheet(context),
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
                        onTap: () => _open(const RegionScreen()),
                      ),
                      ProfileTile(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Home & navigation',
                        subtitle: 'Sections, modules and bottom bar',
                        onTap: () => _showCustomization(context),
                      ),
                    ],
                  ),
                  ProfileSection(
                    title: 'Safety',
                    children: [
                      ProfileTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Sign-in & security',
                        subtitle: _securitySummary(profile),
                        trailing: _needsSecurityAttention(profile)
                            ? Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: colors.warning,
                                      shape: BoxShape.circle),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 20, color: colors.muted),
                              ])
                            : null,
                        onTap: () => _open(const SecurityScreen()),
                      ),
                      ProfileTile(
                        icon: Icons.contact_emergency_outlined,
                        title: 'Emergency contact',
                        subtitle: profile?.hasEmergencyContact == true
                            ? [
                                profile!.emergencyContactName,
                                profile.emergencyContactRelation,
                              ].whereType<String>().join(' · ')
                            : 'Add someone to reach in an emergency',
                        onTap: () => _open(const EmergencyContactScreen()),
                      ),
                      ProfileTile(
                        icon: Icons.lock_outline,
                        title: 'Privacy & data',
                        subtitle: (profile?.allowFriendRequests ?? true)
                            ? 'Friend requests on · Delete account'
                            : 'Friend requests off · Delete account',
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
                        onTap: () => _open(const HelpScreen()),
                      ),
                      ProfileTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign out',
                        destructive: true,
                        trailing: const SizedBox.shrink(),
                        onTap: () => confirmSignOut(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Blistra ${AppConfig.appVersion}',
                        style: TextStyle(fontSize: 11, color: colors.muted)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color onGlassDanger(BuildContext context) =>
      BlistraColors.resolve(context).danger;

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
    return '${c.accent.label} · $mode';
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
    return GlassCard(
      padding: const EdgeInsets.all(15),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(radius: 28, editable: true, onTap: onPhoto),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Your profile' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BlistraText.serif(19, colors.text),
                    ),
                    if (p != null) ...[
                      const SizedBox(height: 3),
                      Text('@${p.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: colors.muted)),
                      Text(p.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: colors.muted)),
                    ],
                  ],
                ),
              ),
              Tooltip(
                message: 'Edit profile',
                child: Icon(Icons.chevron_right_rounded, color: colors.muted),
              ),
            ],
          ),
          if ((p?.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(p!.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.text, fontSize: 13, height: 1.4)),
          ],
          if (p != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (p.memberSince != null)
                  Pill('Since ${formatMonthYear(p.memberSince!)}',
                      color: colors.muted),
                StatusPill(
                  label: p.emailVerified ? 'Verified' : 'Email unverified',
                  positive: p.emailVerified,
                ),
              ],
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Finish your profile',
                      style: BlistraText.serif(16, colors.text)),
                ),
                Text('${(progress * 100).round()}%',
                    style: BlistraText.serif(16, colors.accentText)),
              ],
            ),
            const SizedBox(height: 10),
            ProgressLine(value: progress),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, complete, onTap) in steps)
                  if (!complete) Pill('+ $label', onTap: onTap),
              ],
            ),
          ],
        ),
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
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
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
