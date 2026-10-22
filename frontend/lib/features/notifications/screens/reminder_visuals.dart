/// Notifications-only visuals: per-module icon and colour, and a glass
/// switch row. Kept private to this module.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../models/reminder_type.dart';

IconData reminderIcon(ReminderType type) => switch (type) {
      ReminderType.medicine => Icons.medication_outlined,
      ReminderType.habit => Icons.repeat_outlined,
      ReminderType.planner => Icons.event_note_outlined,
      ReminderType.health => Icons.favorite_outline,
      ReminderType.general => Icons.alarm,
    };

/// Module tint, readable on the current theme; the accent for general.
Color reminderColor(BuildContext context, ReminderType type) {
  final colors = BlistraColors.resolve(context);
  final hue = switch (type) {
    ReminderType.medicine => 215.0,
    ReminderType.habit => 262.0,
    ReminderType.planner => 40.0,
    ReminderType.health => 320.0,
    ReminderType.general => null,
  };
  if (hue == null) return colors.accentText;
  return HSLColor.fromAHSL(
    1,
    hue,
    colors.isDark ? 0.8 : 0.7,
    colors.isDark ? 0.7 : 0.4,
  ).toColor();
}

/// A [GlassList] row with a trailing switch.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.color,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GlassRow(
        leading: icon == null ? null : IconWell(icon!, color: color),
        title: title,
        subtitle: subtitle,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
