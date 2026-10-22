/// Shared page header: back button or date eyebrow, glass action buttons,
/// profile avatar, then a serif title and subtitle. Used by every module page
/// so they all match the Home design.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../app/app_scope.dart';
import '../../features/dashboard/models/dashboard_response.dart';
import '../../features/profile/profile_controller.dart';
import '../../features/profile/profile_screen.dart';
import '../theme/app_theme.dart';
import 'blistra_ui.dart';
import 'glass.dart';
import 'module_guard.dart';

//// 38 px frosted rounded-square icon button.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;

  /// Null when a parent (e.g. a [PopupMenuButton]) already owns the tooltip
  /// and semantics, so they are not announced twice.
  final String? tooltip;
  final VoidCallback? onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassCard(
            padding: EdgeInsets.zero,
            radius: 14,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, size: 19, color: colors.text),
            ),
          ),
          if (badge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B7D),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.background, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
    final label = tooltip;
    if (label == null) return button;
    return Tooltip(
      message: label,
      child: Semantics(button: true, label: label, child: button),
    );
  }
}

/// Glass initials (or photo) avatar that opens Profile.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    String name = '';
    try {
      final scope = AppScope.of(context);
      name = resolveDisplayName(
        user: scope.dashboard.dashboard?.user,
        email: scope.authState.userEmail,
      );
    } catch (_) {
      name = '';
    }
    Uint8List? photo;
    try {
      final profile = context.watch<ProfileController>();
      photo = profile.avatarBytes;
      final display = profile.profile?.displayName ?? '';
      if (display.trim().isNotEmpty) name = display;
    } catch (_) {
      // No ProfileController above this header (e.g. in isolated tests).
    }
    final initials = name.trim().isEmpty ? '' : initialsForName(name);
    return Semantics(
      label: 'Profile',
      button: true,
      child: GestureDetector(
        onTap: () =>
            pushModulePage(context, const ProfileScreen(), title: 'Profile'),
        child: GlassCard(
          padding: EdgeInsets.zero,
          radius: 14,
          child: SizedBox(
            width: 38,
            height: 38,
            child: photo != null
                ? Image.memory(
                    photo,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : Center(
                    child: initials.isEmpty
                        ? Icon(
                            Icons.person_outline_rounded,
                            size: 19,
                            color: colors.accentText,
                          )
                        : Text(
                            initials,
                            style: TextStyle(
                              color: colors.accentText,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Page header shared by every module page, matching Home: back button (on
/// pushed pages) and a small accent eyebrow on the left, glass actions on
/// the right, then a serif title and a muted subtitle.
class BlistraPageHeader extends StatelessWidget {
  const BlistraPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.actions = const [],
    this.showAvatar = true,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 6),
  });

  final String title;
  final String? subtitle;

  /// Small uppercase line above the title; defaults to today's date.
  final String? eyebrow;
  final List<Widget> actions;
  final bool showAvatar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final canPop = Navigator.of(context).canPop();
    final line = (eyebrow ?? DateFormat('EEEE · d MMM').format(DateTime.now()))
        .toUpperCase();
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (canPop) ...[
                GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: canPop
                    ? const SizedBox.shrink()
                    : Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BlistraText.eyebrow(colors.accentText),
                      ),
              ),
              for (final action in actions) ...[
                action,
                const SizedBox(width: 8),
              ],
              if (showAvatar) const ProfileAvatarButton(),
            ],
          ),
          if (canPop) ...[
            const SizedBox(height: 12),
            Text(line, style: BlistraText.eyebrow(colors.accentText)),
          ],
          const SizedBox(height: 8),
          Text(title, style: BlistraText.serif(30, colors.text, height: 1.1)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Glass segmented tabs with a filled accent selection. Tabs share the width
/// equally; with many or long labels the bar scrolls horizontally instead.
class BlistraSegmentedTabs extends StatelessWidget {
  const BlistraSegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 8),
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    Widget tab(int i, {required bool expand}) {
      final on = selected == i;
      final body = Semantics(
        button: true,
        selected: on,
        label: labels[i],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? colors.accentText : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icons != null) ...[
                  Icon(
                    icons![i],
                    size: 15,
                    color: on ? colors.onAccent : colors.muted,
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? colors.onAccent : colors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return expand ? Expanded(child: body) : body;
    }

    final fits = labels.length <= 4 &&
        labels.every((l) => l.length <= (labels.length <= 3 ? 14 : 10));
    return Padding(
      padding: padding,
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.all(4),
        child: fits
            ? Row(children: [
                for (var i = 0; i < labels.length; i++) tab(i, expand: true),
              ])
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (var i = 0; i < labels.length; i++) tab(i, expand: false),
                ]),
              ),
      ),
    );
  }
}
