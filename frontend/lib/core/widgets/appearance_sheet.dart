/// Appearance picker: Light / Dark / System plus the ten colour themes.
///
/// Changes apply live through [ThemeController] and persist locally.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/accent_palette.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'glass.dart';

Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider<ThemeController>.value(
      value: context.read<ThemeController>(),
      child: const AppearanceSheet(),
    ),
  );
}

class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final colors = BlistraColors.resolve(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: colors.text,
                height: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose a colour theme and how Blistra looks.',
              style: TextStyle(fontSize: 12.5, color: colors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            _ModeSwitch(mode: controller.mode, onChanged: controller.setMode),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'COLOUR THEME',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                for (final palette in AccentPalette.values)
                  _ThemeTile(
                    palette: palette,
                    selected: palette == controller.accent,
                    onTap: () => controller.setAccent(palette),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass segmented control: Light | Dark | System.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    const options = [
      (ThemeMode.light, 'Light'),
      (ThemeMode.dark, 'Dark'),
      (ThemeMode.system, 'System'),
    ];
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == value,
                label: '$label mode',
                child: GestureDetector(
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: mode == value
                          ? colors.accentText
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mode == value ? colors.onAccent : colors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AccentPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} theme',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.accentText : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: GlassCard(
          radius: 19,
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: palette.gradient,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palette.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      palette.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: colors.muted),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 16, color: colors.accentText),
            ],
          ),
        ),
      ),
    );
  }
}
