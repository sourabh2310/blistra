import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/blistra_ui.dart';
import '../models/meal_type.dart';
import 'diet_ui.dart';

/// Compact meal row used across the day and history lists. Place inside a
/// [GlassList].
class MealTile extends StatelessWidget {
  const MealTile({
    super.key,
    required this.label,
    required this.title,
    required this.consumedAt,
    this.mealType,
    this.itemCount,
    this.onTap,
  });

  final String label;
  final String title;
  final DateTime consumedAt;
  final MealType? mealType;
  final int? itemCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = itemCount ?? 0;
    return GlassRow(
      leading: IconWell(mealTypeIcon(mealType ?? MealType.other)),
      title: title.trim().isEmpty ? label : title,
      subtitle: [
        if (label.isNotEmpty &&
            label.toLowerCase() != title.trim().toLowerCase())
          label,
        DateFormat('h:mm a').format(consumedAt),
      ].join(' · '),
      trailing: RowMeta(
        count > 0 ? '$count ${count == 1 ? 'item' : 'items'}  ›' : '›',
      ),
      onTap: onTap,
    );
  }
}
