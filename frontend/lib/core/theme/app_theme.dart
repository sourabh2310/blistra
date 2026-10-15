import 'package:flutter/material.dart';

import 'accent_palette.dart';

/// Material 3 theme for Blistra: frosted-glass surfaces over a soft accent
/// glow, in light and dark, recoloured by the user's [AccentPalette].
///
/// Design tokens live in [AppSpacing], [AppRadius] and [BlistraColors] and are
/// consumed via [BlistraDesign] widgets — do not scatter raw numbers/colors in
/// screens.
class AppTheme {
  AppTheme._();

  static const seed = Color(0xFF12B886);

  static ThemeData light([AccentPalette palette = AccentPalette.lagoon]) =>
      _build(palette, Brightness.light);

  static ThemeData dark([AccentPalette palette = AccentPalette.lagoon]) =>
      _build(palette, Brightness.dark);

  static ThemeData _build(AccentPalette palette, Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final colors = BlistraColors.of(palette, brightness);
    final base = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: dark ? colors.accentText : palette.primary,
      onPrimary: Colors.white,
      secondary: palette.secondary,
      surface: colors.background,
      onSurface: colors.text,
      onSurfaceVariant: colors.muted,
      outlineVariant: colors.glassBorder,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: colors.glassBorder),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      colorScheme: scheme,
      extensions: [colors],
      // Transparent so the [BlistraBackdrop] glow shows through every page.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: colors.text,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: colors.text,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.glassFill,
        surfaceTintColor: Colors.transparent,
        shadowColor: colors.shadow,
        shape: shape,
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide(color: colors.glassBorder),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.glassFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: colors.muted.withValues(alpha: 0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide(color: colors.glassBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: colors.glassBorder,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.sheet,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.sheet,
        headerForegroundColor: colors.text,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.navFill,
        selectedItemColor: colors.accentText,
        unselectedItemColor: colors.muted,
      ),
    );
  }
}

/// Colours that depend on the accent palette and brightness: glass surfaces,
/// glow and gradients. Read with [BlistraColors.resolve].
@immutable
class BlistraColors extends ThemeExtension<BlistraColors> {
  const BlistraColors({
    required this.palette,
    required this.brightness,
    required this.background,
    required this.text,
    required this.muted,
    required this.glassFill,
    required this.glassBorder,
    required this.navFill,
    required this.sheet,
    required this.accentText,
    required this.shadow,
  });

  final AccentPalette palette;
  final Brightness brightness;
  final Color background;
  final Color text;
  final Color muted;
  final Color glassFill;
  final Color glassBorder;
  final Color navFill;
  final Color sheet;

  /// Accent readable as text/icon on [background].
  final Color accentText;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;
  LinearGradient get gradient => palette.gradient;
  Color get accent => palette.primary;
  Color get accent2 => palette.secondary;
  double get glowOpacity => isDark ? 0.5 : 0.55;

  factory BlistraColors.of(AccentPalette palette, Brightness brightness) {
    final Color p = palette.primary;
    if (brightness == Brightness.dark) {
      return BlistraColors(
        palette: palette,
        brightness: brightness,
        background: Color.lerp(const Color(0xFF050810), p, 0.09)!,
        text: const Color(0xFFEEF4F6),
        muted: const Color(0xFF93A1B3),
        glassFill: const Color(0x12FFFFFF),
        glassBorder: const Color(0x24FFFFFF),
        navFill: Color.lerp(const Color(0xFF0E1422), p, 0.08)!
            .withValues(alpha: 0.72),
        sheet: Color.lerp(const Color(0xFF0E1422), p, 0.1)!,
        accentText: Color.lerp(p, Colors.white, 0.45)!,
        shadow: const Color(0x59000000),
      );
    }
    return BlistraColors(
      palette: palette,
      brightness: brightness,
      background: Color.lerp(const Color(0xFFF8F5EE), p, 0.07)!,
      text: Color.lerp(const Color(0xFF0D1514), p, 0.2)!,
      muted: Color.lerp(const Color(0xFF667370), p, 0.14)!,
      glassFill: const Color(0x94FFFFFF),
      glassBorder: const Color(0xE6FFFFFF),
      navFill: const Color(0xA8FFFFFF),
      sheet: Color.lerp(Colors.white, p, 0.04)!,
      accentText: Color.lerp(p, Colors.black, 0.18)!,
      shadow: p.withValues(alpha: 0.22),
    );
  }

  /// The theme's colours, or Lagoon defaults when a screen is built outside
  /// the app theme (for example in widget tests).
  static BlistraColors resolve(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BlistraColors>() ??
        BlistraColors.of(AccentPalette.lagoon, theme.brightness);
  }

  @override
  BlistraColors copyWith({AccentPalette? palette}) =>
      palette == null ? this : BlistraColors.of(palette, brightness);

  @override
  BlistraColors lerp(ThemeExtension<BlistraColors>? other, double t) =>
      t < 0.5 || other is! BlistraColors ? this : other;
}

/// Spacing scale — use everywhere instead of magic numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner radii.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}
