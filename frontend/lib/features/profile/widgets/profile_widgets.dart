/// Building blocks shared by the Profile hub and its sub-screens.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
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

/// Circular profile photo with an initials fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.radius = 40, this.onTap, this.editable = false});

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
    final avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: bytes == null ? colors.gradient : null,
        border: Border.all(color: Colors.white.withValues(alpha: .85), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        image: bytes == null
            ? null
            : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: bytes == null
          ? Text(
              name.trim().isEmpty ? 'B' : initialsForName(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.7,
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
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: .35),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            if (editable)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: radius * 0.62,
                  height: radius * 0.62,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: Icon(Icons.photo_camera_outlined,
                      size: radius * 0.32, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
            height: 1, indent: 68, endIndent: 16, color: colors.glassBorder));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                  letterSpacing: 0.8)),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.glassBorder),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: rows),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Text(footer!,
                style: TextStyle(fontSize: 12, color: colors.muted, height: 1.4)),
          ),
      ],
    );
  }
}

/// One settings row: tinted icon, title, optional subtitle and trailing.
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
  final Color tint;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    const danger = Color(0xFFB42318);
    final fg = destructive ? onGlass(context, danger) : colors.accentText;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: softBg(context, destructive ? const Color(0xFFFDECEC) : tint),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: destructive ? fg : colors.text)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.muted)),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: colors.muted)
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive
            ? softBg(context, const Color(0xFFE6F6F3))
            : softBg(context, const Color(0xFFFFF4E5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: positive
              ? colors.accentText
              : onGlass(context, const Color(0xFFB54708)),
        ),
      ),
    );
  }
}

/// Scaffold used by every Profile sub-screen.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
        children: children,
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
