/// The ten accent colour themes a user can pick in Appearance.
///
/// The accent recolours the logo, glow, buttons, navigation, progress and
/// artwork in both light and dark. Module colours (health, medicines, …)
/// stay fixed because they carry meaning; see [ModuleColors].
library;

import 'package:flutter/material.dart';

enum AccentPalette {
  lagoon(
    label: 'Lagoon',
    primary: Color(0xFF12B886),
    secondary: Color(0xFF0B7A66),
    glowA: Color(0xFF2FD0B0),
    glowB: Color(0xFFFFD08A),
    glowC: Color(0xFF5AA9FF),
  ),
  ocean(
    label: 'Ocean',
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF06B6D4),
    glowA: Color(0xFF3B82F6),
    glowB: Color(0xFF22D3EE),
    glowC: Color(0xFF8B7BFF),
  ),
  orchid(
    label: 'Orchid',
    primary: Color(0xFF8B5CF6),
    secondary: Color(0xFFD946EF),
    glowA: Color(0xFF8B5CF6),
    glowB: Color(0xFFF0A0FF),
    glowC: Color(0xFF5AA9FF),
  ),
  sunset(
    label: 'Sunset',
    primary: Color(0xFFFF7A1A),
    secondary: Color(0xFFE8452C),
    glowA: Color(0xFFFF7A1A),
    glowB: Color(0xFFFFC15A),
    glowC: Color(0xFFFF5A7A),
  ),
  rosewood(
    label: 'Rosewood',
    primary: Color(0xFFE11D48),
    secondary: Color(0xFFFB7185),
    glowA: Color(0xFFE11D48),
    glowB: Color(0xFFFFB3C4),
    glowC: Color(0xFFA78BFA),
  ),
  forest(
    label: 'Forest',
    primary: Color(0xFF1F9D55),
    secondary: Color(0xFF166534),
    glowA: Color(0xFF3CB56A),
    glowB: Color(0xFFC8E86A),
    glowC: Color(0xFF4FD1C5),
  ),
  indigo(
    label: 'Indigo',
    primary: Color(0xFF4F46E5),
    secondary: Color(0xFF6366F1),
    glowA: Color(0xFF4F46E5),
    glowB: Color(0xFF818CF8),
    glowC: Color(0xFF38BDF8),
  ),
  gold(
    label: 'Gold',
    primary: Color(0xFFD98A00),
    secondary: Color(0xFFB45309),
    glowA: Color(0xFFF5B82E),
    glowB: Color(0xFFFFE08A),
    glowC: Color(0xFFFF9A5A),
  ),
  slate(
    label: 'Slate',
    primary: Color(0xFF52627A),
    secondary: Color(0xFF1F2A3D),
    glowA: Color(0xFF64748B),
    glowB: Color(0xFFCBD5E1),
    glowC: Color(0xFF94A3B8),
  ),
  blossom(
    label: 'Blossom',
    primary: Color(0xFFF06292),
    secondary: Color(0xFFFF8A65),
    glowA: Color(0xFFF06292),
    glowB: Color(0xFFFFB7C9),
    glowC: Color(0xFFFFCC80),
  );

  const AccentPalette({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.glowA,
    required this.glowB,
    required this.glowC,
  });

  final String label;

  /// Main accent: buttons, selection, links.
  final Color primary;

  /// Second stop of the accent gradient.
  final Color secondary;

  /// Background glow blobs (top right, middle left, bottom right).
  final Color glowA;
  final Color glowB;
  final Color glowC;

  LinearGradient get gradient => LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static AccentPalette fromName(String? name) => AccentPalette.values
      .firstWhere((p) => p.name == name, orElse: () => AccentPalette.lagoon);
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
