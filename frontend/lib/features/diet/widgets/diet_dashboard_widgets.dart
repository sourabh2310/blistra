import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diet_profile.dart';
import '../models/meal.dart';
import '../models/meal_type.dart';
import '../models/nutrition_totals.dart';
import '../models/summary.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/glass.dart';
import 'diet_ui.dart';

/// Protein, carbs, fat and fiber for the day. There are no nutrition goals
/// in the API, so the bars are relative to the largest of the four.
class DietMacrosCard extends StatelessWidget {
  const DietMacrosCard({super.key, required this.nutrition});

  final NutritionTotals? nutrition;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final macros = [
      ('Protein', nutrition?.proteinG?.total, colors.data[2]),
      ('Carbs', nutrition?.carbohydratesG?.total, colors.data[1]),
      ('Fat', nutrition?.fatG?.total, colors.data[0]),
      ('Fiber', nutrition?.fiberG?.total, colors.accentText),
    ];
    final largest = macros.fold<double>(0, (m, e) => math.max(m, e.$2 ?? 0));
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          for (var i = 0; i < macros.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(
              child: Semantics(
                label: macros[i].$2 == null
                    ? '${macros[i].$1} not recorded'
                    : '${macros[i].$1} ${formatDietNumber(macros[i].$2!)} grams',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      macros[i].$1.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BlistraText.caption(colors.muted),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        macros[i].$2 == null
                            ? '—'
                            : '${formatDietNumber(macros[i].$2!)} g',
                        style: BlistraText.serif(16, colors.text),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ProgressLine(
                      value: largest == 0 || macros[i].$2 == null
                          ? 0
                          : macros[i].$2! / largest,
                      color: macros[i].$3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The day's water total with one-tap +250 / +500 ml buttons and a row of
/// glass segments (250 ml each). Tapping the card opens the custom log.
class DietWaterCard extends StatelessWidget {
  const DietWaterCard({
    super.key,
    required this.summary,
    required this.busy,
    required this.onAdd,
    required this.onCustom,
  });

  final DietSummary summary;
  final bool busy;
  final ValueChanged<double> onAdd;
  final VoidCallback onCustom;

  static const _mlPerGlass = 250.0;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final total = summary.waterTotalMilliliters;
    final ml = total ?? 0;
    final glasses = (ml / _mlPerGlass).floor();
    final segments = math.max(10, glasses);
    final water = colors.data[0];
    return GlassCard(
      padding: const EdgeInsets.all(15),
      onTap: onCustom,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WATER', style: BlistraText.caption(colors.muted)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          text: total == null && summary.waterCount > 0
                              ? '—'
                              : formatWater(ml),
                          children: [
                            TextSpan(
                              text:
                                  '  $glasses ${glasses == 1 ? 'glass' : 'glasses'}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                        style: BlistraText.serif(22, colors.text),
                      ),
                    ),
                  ],
                ),
              ),
              _WaterButton(
                label: '+250',
                semanticLabel: 'Add 250 ml of water',
                filled: false,
                onTap: busy ? null : () => onAdd(250),
              ),
              const SizedBox(width: 6),
              _WaterButton(
                label: '+500 ml',
                semanticLabel: 'Add 500 ml of water',
                filled: true,
                onTap: busy ? null : () => onAdd(500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < segments; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: i < glasses ? water : colors.inkAt(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterButton extends StatelessWidget {
  const _WaterButton({
    required this.label,
    required this.semanticLabel,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? colors.accentText : colors.inkAt(0.1),
              borderRadius: BorderRadius.circular(99),
              border: filled ? null : Border.all(color: colors.inkAt(0.14)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? colors.onAccent : colors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row per slot (Breakfast, Lunch, Snack, Dinner) with kcal and items;
/// an unlogged slot shows a dashed placeholder. Meals of type Other follow.
class DietMealSlots extends StatelessWidget {
  const DietMealSlots({
    super.key,
    required this.meals,
    required this.onMealTap,
    required this.onLog,
  });

  final List<Meal> meals;
  final ValueChanged<Meal> onMealTap;

  /// Logs a meal of the given slot; null hides the "Log" action (for days
  /// other than today, where a new meal would land on the wrong day).
  final ValueChanged<MealType>? onLog;

  static const _slots = [
    MealType.breakfast,
    MealType.lunch,
    MealType.snack,
    MealType.dinner,
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = [...meals]..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    final rows = <Widget>[];
    for (final slot in [..._slots, MealType.other]) {
      final inSlot = sorted.where((m) => m.mealType == slot).toList();
      if (inSlot.isEmpty) {
        if (slot != MealType.other) {
          rows.add(_PlaceholderRow(
            slot: slot,
            onLog: onLog == null ? null : () => onLog!(slot),
          ));
        }
        continue;
      }
      for (final meal in inSlot) {
        rows.add(_MealRow(meal: meal, onTap: () => onMealTap(meal)));
      }
    }
    return GlassList(children: rows);
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.onTap});

  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kcal = mealCalories(meal);
    final names = meal.items
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
    final title = meal.title.trim();
    final showTitle =
        title.isNotEmpty && title.toLowerCase() != meal.mealType.label.toLowerCase();
    final subtitle = [
      if (showTitle) title,
      if (names.isNotEmpty) names,
      DateFormat('h:mm a').format(meal.consumedAt),
    ].join(' · ');
    return GlassRow(
      leading: IconWell(mealTypeIcon(meal.mealType)),
      title: kcal == null
          ? meal.mealType.label
          : '${meal.mealType.label} · ${formatKcal(kcal)} kcal',
      subtitle: subtitle,
      trailing: const RowMeta('›'),
      onTap: onTap,
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({required this.slot, required this.onLog});

  final MealType slot;
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassRow(
      leading: CustomPaint(
        painter: _DashedBorderPainter(color: colors.inkAt(0.25)),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(mealTypeIcon(slot), size: 17, color: colors.muted),
        ),
      ),
      title: slot.label,
      titleColor: colors.muted,
      subtitle: onLog == null ? 'Not logged' : 'Not logged yet',
      trailing: onLog == null ? null : Pill('Log', onTap: onLog),
      onTap: onLog,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.5),
        Radius.circular(size.width / 3),
      ));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

/// Diet profile summary (preference, disliked foods, notes). Nutrition
/// targets are not stored in Diet, so none are shown.
class DietProfileCard extends StatelessWidget {
  const DietProfileCard({
    super.key,
    required this.profile,
    required this.loading,
    required this.onOpen,
  });

  final DietProfile? profile;
  final bool loading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final value = profile;
    final custom = value?.customPreference?.trim();
    final preference = custom != null && custom.isNotEmpty
        ? custom
        : value?.dietaryPreference?.label;
    final disliked = value?.dislikedFoods?.trim();
    final notes = value?.notes?.trim();
    return GlassList(
      children: [
        GlassRow(
          leading: const IconWell(Icons.eco_outlined),
          title: value == null
              ? (loading ? 'Loading profile…' : 'Set up your diet profile')
              : preference ?? 'No preference set',
          subtitle: value == null
              ? 'Preference and foods to avoid'
              : [
                  disliked != null && disliked.isNotEmpty
                      ? 'Avoids $disliked'
                      : 'No disliked foods recorded',
                  if (notes != null && notes.isNotEmpty) notes,
                ].join(' · '),
          trailing: const RowMeta('›'),
          onTap: onOpen,
        ),
      ],
    );
  }
}
