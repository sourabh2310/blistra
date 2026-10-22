/// Building blocks shared by the Profile hub and its sub-screens.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
import '../../auth/country_data.dart';
import '../../dashboard/models/dashboard_response.dart';
import '../profile_controller.dart';

/// Name shown for the signed-in user: profile display name first, then the
/// dashboard/email fallback used across the app.
String profileDisplayName(BuildContext context) {
  final profile = context.watch<ProfileController>().profile;
  if ((profile?.displayName ?? '').trim().isNotEmpty) {
    return profile!.displayName!.trim();
  }
  try {
    final scope = AppScope.of(context);
    return resolveDisplayName(
      user: scope.dashboard.dashboard?.user,
      email: scope.authState.userEmail,
    );
  } catch (_) {
    return '';
  }
}

/// Profile photo in a rounded square with an initials fallback on the theme
/// gradient.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.radius = 40, this.onTap, this.editable = false});

  /// Half the avatar's side length.
  final double radius;
  final VoidCallback? onTap;

  /// Shows a small camera badge to hint the photo can be changed.
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProfileController>();
    final colors = BlistraColors.resolve(context);
    final bytes = controller.avatarBytes;
    final name = profileDisplayName(context);
    final side = radius * 2;
    final corner = BorderRadius.circular(side * 0.36);
    final avatar = Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: corner,
        gradient: bytes == null ? colors.gradient : null,
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: bytes == null
          ? Text(
              name.trim().isEmpty ? 'B' : initialsForName(name),
              style: TextStyle(
                color: colors.onAccent,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.64,
              ),
            )
          : null,
    );
    return Semantics(
      button: onTap != null,
      label: editable ? 'Change profile photo' : 'Profile photo',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            if (controller.photoBusy)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: corner,
                    color: colors.background.withValues(alpha: .55),
                  ),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: colors.accentText),
                  ),
                ),
              ),
            if (editable)
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: colors.sheet,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Icon(Icons.photo_camera_outlined,
                      size: 12, color: colors.accentText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A titled group of settings rows: serif heading, a [GlassList] and an
/// optional muted footnote.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
          child: Semantics(
            header: true,
            child: Text(title, style: BlistraText.serif(17, colors.text)),
          ),
        ),
        GlassList(children: children),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(footer!,
                style: TextStyle(fontSize: 11.5, color: colors.muted, height: 1.45)),
          ),
      ],
    );
  }
}

/// One settings row: icon well, title, current value and a chevron.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tint = const Color(0xFFE6F6F3),
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Kept for compatibility; rows use neutral icon wells like the design.
  final Color tint;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final danger = destructive ? colors.danger : null;
    return GlassRow(
      leading: IconWell(icon, color: danger),
      title: title,
      titleColor: danger,
      subtitle: subtitle,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded, size: 20, color: colors.muted)
              : null),
      onTap: onTap,
    );
  }
}

/// Small rounded status label (Verified / Not verified / Pending).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Pill(label, color: positive ? colors.accentText : colors.warning);
  }
}

/// Page used by every Profile sub-screen, following the form template:
/// back button, serif title, then glass sections. [bottom] pins the page's
/// one primary action (see [StickyActionBar]).
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow = 'Settings',
    this.subtitle,
    this.bottom,
  });

  final String title;
  final String eyebrow;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: bottom,
      body: SafeArea(
        bottom: bottom == null,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 48),
          children: [
            BlistraPageHeader(
              eyebrow: eyebrow,
              title: title,
              subtitle: subtitle,
              showAvatar: false,
              padding: const EdgeInsets.only(top: 8, bottom: 6),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Labels ───────────────────────────────────────────────────────

const Map<String, String> kGenderLabels = {
  'FEMALE': 'Female',
  'MALE': 'Male',
  'NON_BINARY': 'Non-binary',
  'PREFER_NOT_TO_SAY': 'Prefer not to say',
};

const Map<String, String> kLanguageLabels = {
  'en': 'English',
  'en-IN': 'English (India)',
  'en-US': 'English (US)',
  'en-GB': 'English (UK)',
  'hi': 'हिन्दी (Hindi)',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
};

String languageLabel(String? code) =>
    code == null ? 'Not set' : kLanguageLabels[code] ?? code;

String unitLabel(String? units) => switch (units) {
      'METRIC' => 'Metric (cm, kg)',
      'IMPERIAL' => 'Imperial (in, lb)',
      _ => 'Not set',
    };

String countryLabel(String? code) {
  final c = countryForCode(code);
  return c == null ? (code ?? 'Not set') : '${c.flag}  ${c.name}';
}

String formatProfileDate(String? isoDate) {
  final d = DateTime.tryParse(isoDate ?? '');
  if (d == null) return 'Not set';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatMonthYear(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];
  return '${months[d.month - 1]} ${d.year}';
}

// ── Dialogs ──────────────────────────────────────────────────────

void showProfileMessage(BuildContext context, String? message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message ?? 'Something went wrong. Please try again.')),
  );
}

Future<String?> showTextFieldDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? helper,
  int? maxLength,
  int maxLines = 1,
  TextInputType? keyboardType,
  String confirmLabel = 'Save',
}) async {
  final text = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint, helperText: helper),
        onSubmitted: maxLines == 1
            ? (v) => Navigator.pop(context, v.trim())
            : null,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: Text(confirmLabel)),
      ],
    ),
  );
  text.dispose();
  return value;
}

Future<String?> showOtpDialog(BuildContext context,
    {required String title, String? message, String confirmLabel = 'Verify'}) async {
  final code = TextEditingController();
  final result = await showDialog<String?>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message,
                  style: TextStyle(
                      fontSize: 13, color: BlistraColors.resolve(context).muted)),
            ),
          TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
            decoration:
                const InputDecoration(hintText: '••••••', counterText: ''),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, code.text.trim()),
            child: Text(confirmLabel)),
      ],
    ),
  );
  code.dispose();
  return (result == null || result.isEmpty) ? null : result;
}

Future<CountryEntry?> pickCountry(BuildContext context) {
  return showModalBottomSheet<CountryEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CountrySheet(),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet();

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchCountries(_query.text);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final c = results[index];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.name),
                    trailing: Text(c.code),
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet of single-choice options; returns the chosen key.
Future<String?> pickOption(BuildContext context,
    {required String title, required Map<String, String> options, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in options.entries)
                  ListTile(
                    title: Text(e.value),
                    trailing: e.key == selected
                        ? Icon(Icons.check,
                            color: BlistraColors.resolve(context).accentText)
                        : null,
                    onTap: () => Navigator.pop(context, e.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
