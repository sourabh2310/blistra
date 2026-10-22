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
    final colors = BlistraColors.of(palette, brightness);
    final base = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: colors.accentText,
      onPrimary: colors.onAccent,
      secondary: palette.secondary,
      surface: colors.background,
      onSurface: colors.text,
      onSurfaceVariant: colors.muted,
      outlineVariant: colors.glassBorder,
      error: colors.danger,
    );
    final serif = TextStyle(
      fontFamily: 'Fraunces',
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: colors.text,
    );
    final baseText = ThemeData(brightness: brightness).textTheme;
    final textTheme = baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.merge(serif),
      headlineMedium: baseText.headlineMedium?.merge(serif),
      headlineSmall: baseText.headlineSmall?.merge(serif),
      titleLarge: baseText.titleLarge?.merge(serif),
    );
    const stadium = StadiumBorder();
    final fieldRadius = BorderRadius.circular(16);
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
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
        titleTextStyle: serif.copyWith(fontSize: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.glassFill,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.glassBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.glassFill,
        selectedColor: colors.accentSoft,
        checkmarkColor: colors.accentText,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.text,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: colors.glassBorder),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.glassFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: colors.muted),
        floatingLabelStyle: TextStyle(color: colors.accentText),
        hintStyle: TextStyle(color: colors.muted.withValues(alpha: 0.8)),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colors.accentText, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colors.danger, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accentText,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.inkAt(0.1),
          disabledForegroundColor: colors.muted,
          minimumSize: const Size.fromHeight(50),
          shape: stadium,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colors.accentText,
          foregroundColor: colors.onAccent,
          shape: stadium,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          foregroundColor: colors.text,
          backgroundColor: colors.inkAt(0.06),
          side: BorderSide(color: colors.glassBorder),
          shape: stadium,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accentText,
        foregroundColor: colors.onAccent,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: colors.glassBorder)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? colors.accentText
                : colors.glassFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? colors.onAccent
                : colors.muted,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : colors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colors.accentText
              : colors.inkAt(0.12),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? colors.accentText
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(colors.onAccent),
        side: BorderSide(color: colors.inkAt(0.55), width: 1.8),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentText,
        linearTrackColor: colors.inkAt(0.12),
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.accentText,
        unselectedLabelColor: colors.muted,
        indicatorColor: colors.accentText,
        dividerColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.sheet,
        contentTextStyle: TextStyle(color: colors.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.glassBorder),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: colors.inkAt(0.08),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        iconColor: colors.muted,
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.text,
        ),
        subtitleTextStyle: TextStyle(fontSize: 12, color: colors.muted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.sheet,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: serif.copyWith(fontSize: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: colors.glassBorder),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.sheet,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: colors.inkAt(0.25),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.glassBorder),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.sheet,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: colors.text,
      ),
      timePickerTheme: TimePickerThemeData(backgroundColor: colors.sheet),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.navFill,
        selectedItemColor: colors.accentText,
        unselectedItemColor: colors.muted,
      ),
    );
  }
}

// Colours that depend on the colour theme and brightness. Read with
/// [BlistraColors.resolve].
///
/// Every value is derived from the theme hue (see [AccentPalette]) so the
/// ten themes share one set of light and dark rules.
@immutable
class BlistraColors extends ThemeExtension<BlistraColors> {
  const BlistraColors({
    required this.palette,
    required this.brightness,
    required this.background,
    required this.text,
    required this.muted,
    required this.glassFill,
    required this.glassFillEnd,
    required this.glassBorder,
    required this.glassHighlight,
    required this.navFill,
    required this.navFillEnd,
    required this.sheet,
    required this.accentText,
    required this.onAccent,
    required this.ink,
    required this.shadow,
    required this.danger,
    required this.warning,
    required this.blobs,
    required this.data,
  });

  final AccentPalette palette;
  final Brightness brightness;
  final Color background;
  final Color text;
  final Color muted;

  /// Glass surface: gradient from [glassFill] to [glassFillEnd], a hairline
  /// [glassBorder] and a one-pixel [glassHighlight] along the top edge.
  final Color glassFill;
  final Color glassFillEnd;
  final Color glassBorder;
  final Color glassHighlight;
  final Color navFill;
  final Color navFillEnd;
  final Color sheet;

  /// Accent readable as text/icon on [background].
  final Color accentText;

  /// Text on a filled [accentText] surface.
  final Color onAccent;

  /// Base for subtle fills and dividers: white in dark, near-black in light.
  final Color ink;
  final Color shadow;

  /// Urgent items (overdue, due now). Stays red in every theme.
  final Color danger;
  final Color warning;

  /// Four background glow colours, alpha included.
  final List<Color> blobs;

  /// Three secondary data colours for rings and timeline dots.
  final List<Color> data;

  bool get isDark => brightness == Brightness.dark;
  LinearGradient get gradient => palette.gradient;
  Color get accent => palette.primary;
  Color get accent2 => palette.secondary;

  /// [accentText] as a soft tinted fill.
  Color get accentSoft => accentText.withValues(alpha: isDark ? 0.18 : 0.13);

  /// [ink] at [alpha]: subtle fills, tracks and dividers.
  Color inkAt(double alpha) => ink.withValues(alpha: alpha);

  factory BlistraColors.of(AccentPalette palette, Brightness brightness) {
    final hues = palette.secondaryHues;
    Color data(double hue, double s, double l) =>
        HSLColor.fromAHSL(1, hue, s, l).toColor();
    if (brightness == Brightness.dark) {
      return BlistraColors(
        palette: palette,
        brightness: brightness,
        background: palette.tone(0.34, 0.06),
        text: palette.tone(0.25, 0.96),
        muted: palette.tone(0.14, 0.80, alpha: 0.66),
        glassFill: const Color(0x13FFFFFF),
        glassFillEnd: const Color(0x08FFFFFF),
        glassBorder: const Color(0x17FFFFFF),
        glassHighlight: const Color(0x1AFFFFFF),
        navFill: const Color(0x1AFFFFFF),
        navFillEnd: const Color(0x0AFFFFFF),
        sheet: palette.tone(0.30, 0.10),
        accentText: palette.tone(0.72, 0.62),
        onAccent: palette.tone(0.60, 0.07),
        ink: Colors.white,
        shadow: const Color(0x99000000),
        danger: const Color(0xFFFF7A85),
        warning: const Color(0xFFFFC46B),
        blobs: [
          palette.tone(0.80, 0.48, alpha: 0.34),
          palette.tone(0.80, 0.58, shift: 55, alpha: 0.30),
          palette.tone(0.85, 0.52, shift: -45, alpha: 0.22),
          palette.tone(0.80, 0.62, shift: 120, alpha: 0.15),
        ],
        data: [
          data(hues[0], 0.85, 0.68),
          data(hues[1], 0.90, 0.64),
          data(hues[2], 0.75, 0.72),
        ],
      );
    }
    return BlistraColors(
      palette: palette,
      brightness: brightness,
      background: palette.tone(0.36, 0.95),
      text: palette.tone(0.35, 0.09),
      muted: palette.tone(0.14, 0.26, alpha: 0.72),
      glassFill: const Color(0xC7FFFFFF),
      glassFillEnd: const Color(0x75FFFFFF),
      glassBorder: const Color(0xE6FFFFFF),
      glassHighlight: const Color(0xF2FFFFFF),
      navFill: const Color(0xDBFFFFFF),
      navFillEnd: const Color(0x94FFFFFF),
      sheet: palette.tone(0.30, 0.97),
      accentText: palette.tone(0.72, 0.34),
      onAccent: Colors.white,
      ink: palette.tone(0.40, 0.14),
      shadow: palette.tone(0.40, 0.30, alpha: 0.32),
      danger: const Color(0xFFD3303C),
      warning: const Color(0xFFB46F06),
      blobs: [
        palette.tone(0.85, 0.62, alpha: 0.55),
        palette.tone(0.85, 0.68, shift: 55, alpha: 0.45),
        palette.tone(0.90, 0.66, shift: -45, alpha: 0.40),
        palette.tone(0.85, 0.70, shift: 120, alpha: 0.30),
      ],
      data: [
        data(hues[0], 0.85, 0.40),
        data(hues[1], 0.90, 0.38),
        data(hues[2], 0.75, 0.42),
      ],
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
