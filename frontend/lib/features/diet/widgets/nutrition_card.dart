import 'package:flutter/material.dart';

import '../models/nutrition_totals.dart';

/// Renders the day's nutrition totals. Only components with recorded values
/// are shown; everything else is omitted (empty row when nothing recorded).
class NutritionSummaryCard extends StatelessWidget {
  const NutritionSummaryCard({super.key, required this.nutrition});

  final NutritionTotals? nutrition;

  @override
  Widget build(BuildContext context) {
    final nutr = nutrition;
    if (nutr == null) {
      return const SizedBox.shrink();
    }
    final calories = nutr.caloriesKcal;
    final anyValue = calories?.hasValue == true ||
        nutr.proteinG?.hasValue == true ||
        nutr.carbohydratesG?.hasValue == true ||
        nutr.fatG?.hasValue == true ||
        nutr.fiberG?.hasValue == true;
    if (!anyValue) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                if (calories?.hasValue == true)
                  Expanded(
                    child: _Metric(
                      label: 'Calories',
                      value: _fmt(calories!.total!),
                      suffix: 'kcal',
                    ),
                  ),
                if (nutr.proteinG?.hasValue == true)
                  Expanded(
                    child: _Metric(
                      label: 'Protein',
                      value: _fmt(nutr.proteinG!.total!),
                      suffix: 'g',
                    ),
                  ),
                if (nutr.carbohydratesG?.hasValue == true)
                  Expanded(
                    child: _Metric(
                      label: 'Carbs',
                      value: _fmt(nutr.carbohydratesG!.total!),
                      suffix: 'g',
                    ),
                  ),
                if (nutr.fatG?.hasValue == true)
                  Expanded(
                    child: _Metric(
                      label: 'Fat',
                      value: _fmt(nutr.fatG!.total!),
                      suffix: 'g',
                    ),
                  ),
                if (nutr.fiberG?.hasValue == true)
                  Expanded(
                    child: _Metric(
                      label: 'Fiber',
                      value: _fmt(nutr.fiberG!.total!),
                      suffix: 'g',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.suffix});

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text.rich(
          TextSpan(
            text: suffix,
            style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Text(label, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}