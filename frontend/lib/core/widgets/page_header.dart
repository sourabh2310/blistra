/// Shared page header: logo, glass action buttons, profile avatar, then the
/// page title and subtitle. Used by every module page so they all match the
/// Home design.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_scope.dart';
import '../../features/dashboard/models/dashboard_response.dart';
import '../../features/profile/profile_controller.dart';
import '../../features/profile/profile_screen.dart';
import '../theme/app_theme.dart';
import 'glass.dart';
import 'module_guard.dart';

/// 40 px frosted rounded-square icon button.
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
                blur: 16,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, size: 19, color: colors.text),
                ),
              ),
              if (badge)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D6D),
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

/// Gradient initials avatar that opens Profile.
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
    return Semantics(
      label: 'Profile',
      button: true,
      child: GestureDetector(
        onTap: () =>
            pushModulePage(context, const ProfileScreen(), title: 'Profile'),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: colors.gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: .4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: photo != null
              ? Image.memory(photo,
                  width: 40, height: 40, fit: BoxFit.cover, gaplessPlayback: true)
              : Text(
                  name.trim().isEmpty ? 'B' : initialsForName(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}

class BlistraPageHeader extends StatelessWidget {
  const BlistraPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showAvatar = true,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 6),
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showAvatar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.of(context).canPop()) ...[
                GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
              ],
              // Scales down instead of overflowing when a screen has several
              // header actions on a narrow phone.
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: BlistraWordmark(size: 30, serif: false),
                ),
              ),
              for (final action in actions) ...[
                action,
                const SizedBox(width: 8),
              ],
              if (showAvatar) const ProfileAvatarButton(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Sora',
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: -.6,
              color: colors.text,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, height: 1.4, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}


/// Frosted segmented tab bar. Scrolls horizontally when labels do not fit.
class BlistraSegmentedTabs extends StatelessWidget {
  const BlistraSegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: padding,
      child: GlassCard(
        radius: 22,
        blur: 16,
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 32 - 8 - 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Semantics(
                    button: true,
                    selected: selected == i,
                    label: labels[i],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelected(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: selected == i
                              ? colors.accent.withValues(alpha: .2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icons != null) ...[
                              Icon(
                                icons![i],
                                size: 15,
                                color: selected == i
                                    ? colors.accentText
                                    : colors.muted,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: selected == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected == i
                                    ? colors.accentText
                                    : colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
