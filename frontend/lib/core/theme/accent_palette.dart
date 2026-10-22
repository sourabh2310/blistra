/// The ten colour themes a user can pick in Appearance.
///
/// Each theme is a single hue. Every other colour (background, glass tint,
/// glow blobs, accent, progress rings) is derived from it in
/// [BlistraColors.of], separately for light and dark, so the themes stay
/// consistent and a new one is a single line here.
library;

import 'package:flutter/material.dart';

enum AccentPalette {
  lagoon(label: 'Lagoon', description: 'Calm teal', hue: 168),
  aurora(label: 'Aurora', description: 'Soft violet', hue: 262),
  ocean(label: 'Ocean', description: 'Clear blue', hue: 212),
  arctic(label: 'Arctic', description: 'Icy cyan', hue: 190),
  indigo(label: 'Indigo', description: 'Deep indigo', hue: 236),
  emerald(label: 'Emerald', description: 'Fresh green', hue: 146),
  gold(label: 'Gold', description: 'Warm amber', hue: 42),
  sunset(label: 'Sunset', description: 'Burnt orange', hue: 22),
  rose(label: 'Rose', description: 'Playful pink', hue: 335),
  graphite(
    label: 'Graphite',
    description: 'Neutral mono',
    hue: 215,
    saturation: 0.04,
  );

  const AccentPalette({
    required this.label,
    required this.description,
    required this.hue,
    this.saturation = 1,
  });

  final String label;
  final String description;

  /// Base hue in degrees (0–360).
  final double hue;

  /// Multiplier for the theme's own saturation; near zero gives a neutral
  /// theme while secondary ring colours stay readable.
  final double saturation;

  /// Colour from this theme's hue with saturation [s] (0–1, scaled by
  /// [saturation]) and lightness [l] (0–1), optionally shifted by [shift]°.
  Color tone(double s, double l, {double shift = 0, double alpha = 1}) =>
      HSLColor.fromAHSL(
        alpha,
        (hue + shift) % 360,
        (s * saturation).clamp(0.0, 1.0),
        l,
      ).toColor();

  /// Main accent for buttons and selection: a mid tone that carries white
  /// text in both modes.
  Color get primary => tone(0.72, 0.42);

  /// Second stop of the accent gradient.
  Color get secondary => tone(0.72, 0.30);

  /// Swatch shown in the theme picker.
  LinearGradient get gradient => LinearGradient(
    colors: [tone(0.72, 0.66), tone(0.72, 0.36)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hues for secondary data colours (rings, timeline dots), chosen at least
  /// 45° from the theme hue so they never blend into the accent.
  List<double> get secondaryHues {
    const candidates = <double>[215, 40, 320, 160, 270, 30];
    double dist(double a, double b) {
      final x = (a - b).abs() % 360;
      return x > 180 ? 360 - x : x;
    }

    return candidates.where((c) => dist(c, hue) > 45).take(3).toList();
  }

  /// Stored names from the previous palette set map to their closest theme.
  static AccentPalette fromName(String? name) {
    const legacy = {
      'orchid': AccentPalette.aurora,
      'rosewood': AccentPalette.rose,
      'forest': AccentPalette.emerald,
      'slate': AccentPalette.graphite,
      'blossom': AccentPalette.rose,
    };
    return legacy[name] ??
        AccentPalette.values.firstWhere(
          (p) => p.name == name,
          orElse: () => AccentPalette.lagoon,
        );
  }
}

/// Fixed colours that identify each module, independent of the accent.
abstract final class ModuleColors {
  static const planner = Color(0xFF1FB99A);
  static const health = Color(0xFFFF5D7A);
  static const medicines = Color(0xFF4A8CFF);
  static const diet = Color(0xFFFF9A3D);
  static const habits = Color(0xFF8B6BFF);
  static const finance = Color(0xFFE8B230);
}
