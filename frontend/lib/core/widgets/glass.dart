/// Frosted-glass building blocks shared by every screen.
///
/// Presentation only. Colours come from [BlistraColors] so every widget
/// follows the user's accent palette and light/dark mode.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/accent_palette.dart';
import '../theme/app_theme.dart';

/// Context-free access to the active theme colours, for painters and static
/// style tables that cannot read [Theme]. Kept in sync by `MaterialApp.builder`.
abstract final class ActiveColors {
  static BlistraColors value = BlistraColors.of(
    AccentPalette.lagoon,
    Brightness.light,
  );

  static void sync(BlistraColors colors) => value = colors;

  /// Illustration colour adapted to the theme: nudged toward the accent in
  /// light, and darkened to a night tone in dark.
  static Color scene(Color c) {
    final v = value;
    final tinted = Color.lerp(c, v.accent, 0.12)!;
    return v.isDark
        ? Color.lerp(
            Color.lerp(c, const Color(0xFF0B1022), 0.72)!,
            v.accent,
            0.1,
          )!
        : tinted;
  }

  /// Pastel surface adapted to the theme (see [softBg]).
  static Color soft(Color pastel) {
    final v = value;
    if (!v.isDark) return pastel;
    return Color.alphaBlend(pastel.withValues(alpha: 0.09), v.glassFill);
  }

  static Color get text => value.text;
  static Color get muted => value.muted;
  static Color get accent => value.accent;
  static Color get accentText => value.accentText;
  static Color get glassFill => value.glassFill;
  static Color get glassBorder => value.glassBorder;
}

/// Near-white pastel surfaces designed for light mode, adapted to the theme:
/// unchanged in light, a faint tint over dark glass in dark.
Color softBg(BuildContext context, Color pastel) {
  final colors = BlistraColors.resolve(context);
  if (!colors.isDark) return pastel;
  return Color.alphaBlend(pastel.withValues(alpha: 0.09), colors.glassFill);
}

/// A module/status colour made readable on the current surface: lightened in
/// dark mode, unchanged in light.
Color onGlass(BuildContext context, Color color) =>
    BlistraColors.resolve(context).isDark
    ? Color.lerp(color, Colors.white, 0.4)!
    : color;

/// Page background: tinted base colour with four soft glows from the theme.
///
/// Placed once above the [Navigator] (see `MaterialApp.builder`) so every
/// route, including pushed module pages, sits on the same backdrop.
class BlistraBackdrop extends StatelessWidget {
  const BlistraBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final blobs = colors.blobs;
    return ColoredBox(
      color: colors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Glow(
            color: blobs[0],
            diameter: 420,
            alignment: const Alignment(-1.6, -0.95),
          ),
          _Glow(
            color: blobs[1],
            diameter: 400,
            alignment: const Alignment(1.7, -0.2),
          ),
          _Glow(
            color: blobs[2],
            diameter: 420,
            alignment: const Alignment(-1.1, 0.55),
          ),
          _Glow(
            color: blobs[3],
            diameter: 340,
            alignment: const Alignment(1.5, 1.15),
          ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.color,
    required this.diameter,
    required this.alignment,
  });

  final Color color;
  final double diameter;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass surface: blurred backdrop, translucent fill, light border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = 24,
    this.onTap,
    this.tint,
    this.blur = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Optional module colour washed over the top-left of the glass.
  final Color? tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final BorderRadius br = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: br, child: content);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 24,
            spreadRadius: -14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        // Grouped: cards only blur the app background, so they can share the
        // nearest BackdropGroup's snapshot (falls back to a plain blur).
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              border: Border.all(color: colors.glassBorder),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tint == null
                    ? [colors.glassFill, colors.glassFillEnd]
                    : [
                        Color.alphaBlend(
                          tint!.withValues(alpha: colors.isDark ? 0.18 : 0.14),
                          colors.glassFill,
                        ),
                        colors.glassFillEnd,
                      ],
              ),
            ),
            child: DecoratedBox(
              // Faint light along the top edge, like real glass.
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: br,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.glassHighlight,
                    colors.glassHighlight.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.035],
                ),
              ),
              child: Material(type: MaterialType.transparency, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Blistra "b" mark, filled with the accent gradient.
class BlistraMark extends StatelessWidget {
  const BlistraMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: colors.gradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.4),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'b',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.62,
              height: 1,
            ),
          ),
          Positioned(
            top: size * 0.1,
            right: size * 0.1,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "b" mark followed by the Blistra wordmark, used in page headers.
class BlistraWordmark extends StatelessWidget {
  const BlistraWordmark({super.key, this.size = 30, this.serif = true});

  /// Mark size; the wordmark scales with it.
  final double size;

  /// Serif "Blistra" (Home) or sans lowercase "blistra" (module pages).
  final bool serif;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlistraMark(size: size),
        SizedBox(width: size * 0.28),
        Text(
          serif ? 'Blistra' : 'blistra',
          maxLines: 1,
          style: TextStyle(
            color: colors.text,
            fontFamily: serif ? 'Fraunces' : 'Sora',
            fontSize: serif ? size * 0.95 : size * 0.72,
            fontWeight: serif ? FontWeight.w600 : FontWeight.w700,
            letterSpacing: serif ? -0.5 : -0.4,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
