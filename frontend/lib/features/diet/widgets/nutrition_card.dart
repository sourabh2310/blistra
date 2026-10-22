import 'package:flutter/material.dart';

import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/glass.dart';
import '../models/nutrition_totals.dart';
import 'diet_ui.dart';

/// Renders the day's nutrition totals. Only components with recorded values
/// are shown; everything else is omitted (empty when nothing recorded).
class NutritionSummaryCard extends StatelessWidget {
  const NutritionSummaryCard({super.key, required this.nutrition});

  final NutritionTotals? nutrition;

  @override
  Widget build(BuildContext context) {
    final nutr = nutrition;
    if (nutr == null) {
      return const SizedBox.shrink();
    }
    final metrics = [
      ('Calories', nutr.caloriesKcal, 'kcal'),
      ('Protein', nutr.proteinG, 'g'),
      ('Carbs', nutr.carbohydratesG, 'g'),
      ('Fat', nutr.fatG, 'g'),
      ('Fiber', nutr.fiberG, 'g'),
    ].where((m) => m.$2?.hasValue == true).toList();
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          for (final metric in metrics)
            Expanded(
              child: Figure(
                label: metric.$1,
                value: '${formatDietNumber(metric.$2!.total!)} ${metric.$3}',
              ),
            ),
        ],
      ),
    );
  }
}
