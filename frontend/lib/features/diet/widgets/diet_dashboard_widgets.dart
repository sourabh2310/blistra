import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../diet_trends.dart';
import '../models/diet_profile.dart';
import '../models/meal.dart';
import '../models/nutrition_totals.dart';
import '../models/summary.dart';

class DietBrandHeader extends StatelessWidget {
  const DietBrandHeader({
    super.key,
    required this.onSearch,
    required this.onNotifications,
    required this.onHistory,
    required this.onProfile,
  });

  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onHistory;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final brand = const _Brand();
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionCircle(
              tooltip: 'Search food log',
              icon: Icons.search_rounded,
              onTap: onSearch,
            ),
            const SizedBox(width: 8),
            _ActionCircle(
              tooltip: 'Notifications',
              icon: Icons.notifications_none_rounded,
              onTap: onNotifications,
            ),
            const SizedBox(width: 8),
            _ActionCircle(
              tooltip: 'Meal history',
              icon: Icons.calendar_today_outlined,
              onTap: onHistory,
            ),
            const SizedBox(width: 8),
            _ActionCircle(
              tooltip: 'Diet profile',
              icon: Icons.person_outline_rounded,
              onTap: onProfile,
            ),
          ],
        );
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              brand,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: brand),
            const SizedBox(width: 8),
            actions,
          ],
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Blistra',
              style: TextStyle(
                color: const Color(0xFF075E55),
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.3,
                height: 1,
              ),
            ),
            const SizedBox(width: 5),
            const SizedBox(
              width: 30,
              height: 30,
              child: CustomPaint(painter: _LeafPainter()),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'EVERYTHING YOU NEED. ONE APP.',
          maxLines: 1,
          overflow: TextOverflow.fade,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.7,
          ),
        ),
      ],
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = const Color(0xFF0A725E)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.94),
      Offset(size.width * 0.56, size.height * 0.12),
      stem,
    );
    final left = Paint()..color = const Color(0xFF41AD72);
    final right = Paint()..color = const Color(0xFF78C86B);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.48, size.height * 0.58)
        ..quadraticBezierTo(
          size.width * 0.08,
          size.height * 0.63,
          size.width * 0.14,
          size.height * 0.27,
        )
        ..quadraticBezierTo(
          size.width * 0.43,
          size.height * 0.28,
          size.width * 0.48,
          size.height * 0.58,
        ),
      left,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.53, size.height * 0.43)
        ..quadraticBezierTo(
          size.width * 0.66,
          size.height * 0.04,
          size.width * 0.94,
          size.height * 0.12,
        )
        ..quadraticBezierTo(
          size.width * 0.83,
          size.height * 0.44,
          size.width * 0.53,
          size.height * 0.43,
        ),
      right,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF0F1F8),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: Icon(icon, size: 23, color: const Color(0xFF172554)),
            ),
          ),
        ),
      ),
    );
  }
}

class DietHero extends StatelessWidget {
  const DietHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 154,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _FoodHeroPainter())),
          Positioned(
            left: 22,
            top: 20,
            bottom: 18,
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Diet',
                  style: TextStyle(
                    color: Color(0xFF172554),
                    fontSize: 47,
                    height: 0.98,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Good food. A healthier you.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF5573A4),
                        fontFamily: 'serif',
                        fontSize: 18,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peach = Paint()..color = const Color(0xFFFFDCC2);
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.47),
      size.height * 0.43,
      peach,
    );
    canvas.drawCircle(
      Offset(size.width * 0.64, size.height * 0.80),
      size.height * 0.33,
      Paint()..color = const Color(0xFFFFE9D6),
    );
    final leafPaint = Paint()..color = const Color(0xFF547E53);
    final lightLeafPaint = Paint()..color = const Color(0xFF79A96A);
    final stemPaint = Paint()
      ..color = const Color(0xFF4B7650)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.91, size.height),
      Offset(size.width * 0.91, size.height * 0.10),
      stemPaint,
    );
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.18 + i * 0.19);
      final right = i.isEven;
      final path = Path()
        ..moveTo(size.width * 0.91, y)
        ..quadraticBezierTo(
          size.width * (right ? 0.78 : 1.03),
          y - size.height * 0.18,
          size.width * (right ? 0.70 : 1.04),
          y + size.height * 0.02,
        )
        ..quadraticBezierTo(
          size.width * 0.84,
          y + size.height * 0.10,
          size.width * 0.91,
          y,
        );
      canvas.drawPath(path, i % 2 == 0 ? leafPaint : lightLeafPaint);
    }
    final bowl = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.73, size.height * 0.79),
        width: size.width * 0.43,
        height: size.height * 0.37,
      ),
      Radius.circular(size.width * 0.13),
    );
    canvas.drawRRect(bowl, Paint()..color = const Color(0xFFF7B67A));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.73, size.height * 0.63),
        width: size.width * 0.43,
        height: size.height * 0.17,
      ),
      Paint()..color = const Color(0xFFFFF2D9),
    );
    final foods = <Offset>[
      Offset(.66, .61),
      Offset(.70, .58),
      Offset(.74, .60),
      Offset(.78, .57),
      Offset(.82, .61),
      Offset(.66, .65),
      Offset(.72, .64),
      Offset(.77, .64),
      Offset(.81, .65),
    ];
    final foodColors = [
      const Color(0xFF5B9B51),
      const Color(0xFF6FAE58),
      const Color(0xFFEA5B45),
      const Color(0xFFF1A33E),
      const Color(0xFFFFD56B),
      const Color(0xFF7A4A2D),
      const Color(0xFFF5D8A5),
    ];
    for (var i = 0; i < foods.length; i++) {
      final point = foods[i];
      final center = Offset(size.width * point.dx, size.height * point.dy);
      if (i.isEven) {
        canvas.drawOval(
          Rect.fromCenter(center: center, width: 13, height: 7),
          Paint()..color = foodColors[i % foodColors.length],
        );
      } else {
        canvas.drawCircle(
          center,
          5.5,
          Paint()..color = foodColors[i % foodColors.length],
        );
      }
    }
    final noodlePaint = Paint()
      ..color = const Color(0xFFE6B967)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.69 + i * 0.023);
      final path = Path()
        ..moveTo(x, size.height * .60)
        ..quadraticBezierTo(
          x + 12,
          size.height * (.65 + (i.isEven ? .01 : -.01)),
          x + 3,
          size.height * .67,
        );
      canvas.drawPath(path, noodlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DietSummaryGrid extends StatelessWidget {
  const DietSummaryGrid({super.key, required this.summary});

  final DietSummary summary;

  @override
  Widget build(BuildContext context) {
    final nutrition = summary.nutrition;
    final recordedMacros = _recordedMacroCount(nutrition);
    final water = summary.waterTotalMilliliters;
    final metrics = [
      _SummaryData(
        color: const Color(0xFFFFF0E5),
        accent: const Color(0xFFFF6B2C),
        icon: Icons.local_fire_department_rounded,
        value: _formatCalories(nutrition?.caloriesKcal?.total),
        label: 'Consumed',
        detail: nutrition?.caloriesKcal?.total == null
            ? 'No calorie value'
            : 'Calories recorded',
        ring: nutrition?.caloriesKcal?.total == null
            ? null
            : _MacroRingData.total(nutrition!.caloriesKcal!.total!),
      ),
      _SummaryData(
        color: const Color(0xFFEAF8F2),
        accent: const Color(0xFF22B573),
        icon: Icons.eco_rounded,
        value: '${summary.mealCount}',
        label: 'Meals',
        detail: summary.mealCount == 0
            ? 'No meals recorded'
            : summary.mealCount == 1
                ? 'Meal recorded'
                : 'Meals recorded',
        ring: _MacroRingData.count(summary.mealCount),
      ),
      _SummaryData(
        color: const Color(0xFFE9F4FF),
        accent: const Color(0xFF168CEB),
        icon: Icons.water_drop_rounded,
        value: water == null ? '—' : _formatWater(water),
        label: 'Water',
        detail: '${summary.waterCount} ${summary.waterCount == 1 ? 'entry' : 'entries'}',
        ring: water == null ? null : _MacroRingData.water(water),
      ),
      _SummaryData(
        color: const Color(0xFFF4EEFF),
        accent: const Color(0xFF7A32E8),
        icon: Icons.donut_large_rounded,
        value: recordedMacros == 0 ? '—' : '$recordedMacros',
        label: 'Nutrition',
        detail: recordedMacros == 0 ? 'No macros recorded' : 'Macros recorded',
        ring: recordedMacros == 0
            ? null
            : _MacroRingData.macros(
                carbohydrates: nutrition?.carbohydratesG?.total,
                protein: nutrition?.proteinG?.total,
                fat: nutrition?.fatG?.total,
              ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 660 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics)
              SizedBox(width: width, child: _SummaryCard(data: metric)),
          ],
        );
      },
    );
  }

  static int _recordedMacroCount(NutritionTotals? nutrition) {
    var count = 0;
    if (nutrition?.carbohydratesG?.hasValue == true) count++;
    if (nutrition?.proteinG?.hasValue == true) count++;
    if (nutrition?.fatG?.hasValue == true) count++;
    return count;
  }

  static String _formatCalories(double? value) {
    if (value == null) return 'Not recorded';
    return '${_formatNumber(value)} kcal';
  }

  static String _formatWater(double milliliters) {
    if (milliliters >= 1000) {
      return '${(milliliters / 1000).toStringAsFixed(1)} L';
    }
    return '${milliliters.round()} ml';
  }

  static String _formatNumber(double value) =>
      value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
}

class _SummaryData {
  const _SummaryData({
    required this.color,
    required this.accent,
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.ring,
  });

  final Color color;
  final Color accent;
  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final _MacroRingData? ring;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: data.accent, size: 23),
              ),
              const Spacer(),
              if (data.ring != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(painter: _MacroRingPainter(data.ring!)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: const TextStyle(
              color: Color(0xFF172554),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: const TextStyle(
              color: Color(0xFF46658C),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            data.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: data.accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRingData {
  const _MacroRingData({
    required this.slices,
    required this.hasValue,
  });

  factory _MacroRingData.total(double value) => _MacroRingData(
        slices: [_RingSlice(0.68, const Color(0xFF2EBE73))],
        hasValue: true,
      );

  factory _MacroRingData.count(int value) => _MacroRingData(
        slices: value == 0
            ? const []
            : const [_RingSlice(0.68, Color(0xFF2EBE73))],
        hasValue: value > 0,
      );

  factory _MacroRingData.water(double value) => _MacroRingData(
        slices: const [
          _RingSlice(0.68, Color(0xFF168CEB)),
        ],
        hasValue: value > 0,
      );

  factory _MacroRingData.macros({
    required double? carbohydrates,
    required double? protein,
    required double? fat,
  }) {
    final values = [
      (carbohydrates ?? 0) * 4,
      (protein ?? 0) * 4,
      (fat ?? 0) * 9,
    ];
    final colors = [
      const Color(0xFFFF982F),
      const Color(0xFF20B969),
      const Color(0xFF7B35E8),
    ];
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) {
      return const _MacroRingData(slices: [], hasValue: false);
    }
    var offset = -math.pi / 2;
    final slices = <_RingSlice>[];
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * math.pi * 2;
      slices.add(_RingSlice(sweep, colors[i], startAngle: offset));
      offset += sweep;
    }
    return _MacroRingData(slices: slices, hasValue: true);
  }

  final List<_RingSlice> slices;
  final bool hasValue;
}

class _RingSlice {
  const _RingSlice(
    this.sweep, {
    this.color = const Color(0xFF20B969),
    this.startAngle = -math.pi / 2,
  });

  final double sweep;
  final Color color;
  final double startAngle;
}

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter(this.data);

  final _MacroRingData data;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = const Color(0xFFE6E9E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(4), 0, math.pi * 2, false, track);
    if (!data.hasValue) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final slice in data.slices) {
      paint.color = slice.color;
      canvas.drawArc(
        rect.deflate(4),
        slice.startAngle,
        math.max(0.0, slice.sweep - 0.03),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) =>
      oldDelegate.data != data;
}

class TodayMealsSection extends StatelessWidget {
  const TodayMealsSection({
    super.key,
    required this.summary,
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onMealTap,
    required this.onAddMeal,
  });

  final DietSummary summary;
  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<Meal> onMealTap;
  final VoidCallback onAddMeal;

  @override
  Widget build(BuildContext context) {
    final meals = [...summary.meals]
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_rounded,
                  color: Color(0xFFFF6B2C), size: 27),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isToday(date) ? "Today's meals" : 'Meals · ${DateFormat('MMM d').format(date)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF172554),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _TodayButton(date: date, onTap: onToday),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Previous day',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Next day',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            _InlineEmpty(
              icon: Icons.no_meals_outlined,
              title: 'No meals recorded',
              message: 'Log a meal to begin this day.',
              actionLabel: 'Log a meal',
              onAction: onAddMeal,
            )
          else
            for (var i = 0; i < meals.length; i++)
              _MealTimelineRow(
                meal: meals[i],
                isLast: i == meals.length - 1,
                onTap: () => onMealTap(meals[i]),
              ),
        ],
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(date);
    return Material(
      color: const Color(0xFFEAF0EA),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            isToday ? 'Today' : DateFormat('MMM d').format(date),
            style: const TextStyle(
              color: Color(0xFF075E55),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MealTimelineRow extends StatelessWidget {
  const _MealTimelineRow({
    required this.meal,
    required this.isLast,
    required this.onTap,
  });

  final Meal meal;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nutrition = _mealNutrition(meal);
    final names = meal.items.map((item) => item.name).where((name) => name.isNotEmpty);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('h:mm a').format(meal.consumedAt),
                  style: const TextStyle(
                    color: Color(0xFF5573A4),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20B969),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: const Color(0xFFD6D9E2)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: _mealColor(meal.mealType.wireName),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _mealIcon(meal.mealType.wireName),
                            color: const Color(0xFF46658C),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal.mealType.label,
                                style: const TextStyle(
                                  color: Color(0xFF172554),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              if (names.isNotEmpty)
                                Text(
                                  names.join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF5573A4),
                                    fontSize: 12,
                                  ),
                                ),
                              if (nutrition.isNotEmpty)
                                Text(
                                  nutrition.join('  •  '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF5573A4),
                                    fontSize: 10.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF172554)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _mealNutrition(Meal meal) {
    final calories = <double>[];
    final carbohydrates = <double>[];
    final protein = <double>[];
    final fat = <double>[];
    for (final item in meal.items) {
      final caloriesValue = item.caloriesKcal;
      final carbohydratesValue = item.carbohydratesG;
      final proteinValue = item.proteinG;
      final fatValue = item.fatG;
      if (caloriesValue != null) calories.add(caloriesValue);
      if (carbohydratesValue != null) carbohydrates.add(carbohydratesValue);
      if (proteinValue != null) protein.add(proteinValue);
      if (fatValue != null) fat.add(fatValue);
    }
    return [
      if (calories.isNotEmpty)
        '${_format(calories.reduce((a, b) => a + b))} kcal',
      if (carbohydrates.isNotEmpty)
        'Carbs ${_format(carbohydrates.reduce((a, b) => a + b))} g',
      if (protein.isNotEmpty)
        'Protein ${_format(protein.reduce((a, b) => a + b))} g',
      if (fat.isNotEmpty) 'Fat ${_format(fat.reduce((a, b) => a + b))} g',
    ];
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static Color _mealColor(String type) {
    return switch (type) {
      'BREAKFAST' => const Color(0xFFFFF0E2),
      'LUNCH' => const Color(0xFFEAF8EE),
      'DINNER' => const Color(0xFFE9F0FF),
      'SNACK' => const Color(0xFFF4EDFF),
      _ => const Color(0xFFF1F2F4),
    };
  }

  static IconData _mealIcon(String type) {
    return switch (type) {
      'BREAKFAST' => Icons.bakery_dining_outlined,
      'LUNCH' => Icons.lunch_dining_outlined,
      'DINNER' => Icons.dinner_dining_outlined,
      'SNACK' => Icons.icecream_outlined,
      _ => Icons.restaurant_outlined,
    };
  }
}

class DietQuickActions extends StatelessWidget {
  const DietQuickActions({
    super.key,
    required this.onLogMeal,
    required this.onLogWater,
    required this.onScanFood,
  });

  final VoidCallback onLogMeal;
  final VoidCallback onLogWater;
  final VoidCallback onScanFood;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        'Log a meal',
        'Record what you eat',
        Icons.add_rounded,
        const Color(0xFFE8F4EE),
        const Color(0xFF075E55),
        onLogMeal,
      ),
      _QuickActionData(
        'Log water',
        'Add water intake',
        Icons.water_drop_rounded,
        const Color(0xFFEAF5FF),
        const Color(0xFF168CEB),
        onLogWater,
      ),
      _QuickActionData(
        'Scan food',
        'Coming soon',
        Icons.document_scanner_outlined,
        const Color(0xFFF2E9FF),
        const Color(0xFF7A32E8),
        onScanFood,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 690 ? 3 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _QuickAction(data: action),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionData {
  const _QuickActionData(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.iconColor,
    this.onTap,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: data.color, shape: BoxShape.circle),
                child: Icon(data.icon, color: data.iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172554),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5573A4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NutritionOverviewSection extends StatefulWidget {
  const NutritionOverviewSection({
    super.key,
    required this.summary,
    required this.date,
    this.showRange = true,
  });

  final DietSummary summary;
  final DateTime date;
  final bool showRange;

  @override
  State<NutritionOverviewSection> createState() =>
      _NutritionOverviewSectionState();
}

class _NutritionOverviewSectionState extends State<NutritionOverviewSection> {
  int _range = 0;
  int _rangeRequest = 0;
  bool _loading = false;
  Object? _error;
  TrendsSummary? _trends;

  @override
  void didUpdateWidget(covariant NutritionOverviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _rangeRequest++;
      _range = 0;
      _loading = false;
      _trends = null;
      _error = null;
    }
  }

  Future<void> _loadRange() async {
    final request = ++_rangeRequest;
    final days = switch (_range) { 1 => 7, 2 => 30, _ => 90 };
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summaries =
          await context.read<DietController>().loadRangeSummaries(days: days);
      if (!mounted || request != _rangeRequest) return;
      setState(() {
        _trends = summarizeTrends(summaries);
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _rangeRequest) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String _dayLabel(DateTime date) => _isToday(date) ? 'Today' : 'Day';

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: Color(0xFF075E55), size: 27),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nutrition overview',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF172554),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              );
              if (!widget.showRange) return title;
              final selector = _RangeSelector(
                selected: _range,
                dayLabel: _dayLabel(widget.date),
                onSelected: (value) {
                  setState(() {
                    _range = value;
                    if (value == 0) {
                      _rangeRequest++;
                      _loading = false;
                      _trends = null;
                      _error = null;
                    }
                  });
                  if (value != 0) _loadRange();
                },
              );
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: selector),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 10),
                  selector,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _NutritionBody(
            summary: widget.summary,
            trends: _trends,
            loading: _loading,
            error: _error,
            onRetry: _loadRange,
            isTodayRange: _range == 0,
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.dayLabel,
    required this.onSelected,
  });

  final int selected;
  final String dayLabel;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [dayLabel, '7D', '1M', '3M'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1F5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: selected == i ? const Color(0xFFDDEAE3) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: selected == i
                        ? const Color(0xFF075E55)
                        : const Color(0xFF5573A4),
                    fontSize: 10.5,
                    fontWeight: selected == i ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NutritionBody extends StatelessWidget {
  const _NutritionBody({
    required this.summary,
    required this.trends,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.isTodayRange,
  });

  final DietSummary summary;
  final TrendsSummary? trends;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final bool isTodayRange;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Text('Trend data could not be loaded.'),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    final nutrition = summary.nutrition;
    final cards = isTodayRange
        ? _nutritionCards(nutrition)
        : _trendCards(trends);
    if (cards == null) {
      return _InlineEmpty(
        icon: Icons.query_stats_rounded,
        title: isTodayRange ? 'No nutrition data' : 'No trend data',
        message: isTodayRange
            ? 'No nutrition values were recorded for this day.'
            : 'No values were recorded in this range.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 500;
        final ring = _NutritionRing(summary: summary, showRangeLabel: !isTodayRange);
        final rows = Column(
          children: [
            for (final card in cards) ...[
              _MacroRow(data: card),
              if (card != cards.last) const Divider(height: 18),
            ],
          ],
        );
        if (wide) {
          return Row(
            children: [
              ring,
              const SizedBox(width: 30),
              Expanded(child: rows),
            ],
          );
        }
        return Column(
          children: [
            Center(child: ring),
            const SizedBox(height: 12),
            rows,
          ],
        );
      },
    );
  }

  static List<_MacroCardData>? _nutritionCards(NutritionTotals? nutrition) {
    final rows = <_MacroCardData>[
      _MacroCardData(
        'Carbohydrates',
        nutrition?.carbohydratesG?.total,
        'g',
        const Color(0xFFFF982F),
      ),
      _MacroCardData(
        'Protein',
        nutrition?.proteinG?.total,
        'g',
        const Color(0xFF20B969),
      ),
      _MacroCardData(
        'Fat',
        nutrition?.fatG?.total,
        'g',
        const Color(0xFF7B35E8),
      ),
      _MacroCardData(
        'Fiber',
        nutrition?.fiberG?.total,
        'g',
        const Color(0xFFE55A7B),
      ),
    ];
    return rows.any((row) => row.value != null) ? rows : null;
  }

  static List<_MacroCardData>? _trendCards(TrendsSummary? trends) {
    if (trends == null) return null;
    final rows = <_MacroCardData>[
      _MacroCardData(
        'Avg carbohydrates',
        trends.averageCarbohydratesG,
        'g',
        const Color(0xFFFF982F),
      ),
      _MacroCardData(
        'Avg protein',
        trends.averageProteinG,
        'g',
        const Color(0xFF20B969),
      ),
      _MacroCardData(
        'Avg fat',
        trends.averageFatG,
        'g',
        const Color(0xFF7B35E8),
      ),
      _MacroCardData(
        'Avg water',
        trends.averageWaterMilliliters,
        'ml',
        const Color(0xFF168CEB),
      ),
    ];
    return rows.any((row) => row.value != null) ? rows : null;
  }
}

class _MacroCardData {
  const _MacroCardData(
    this.label,
    this.value,
    this.unit,
    this.color,
  );

  final String label;
  final double? value;
  final String unit;
  final Color color;
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.data});

  final _MacroCardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: data.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(data.label, style: const TextStyle(color: Color(0xFF172554)))),
        if (data.value == null)
          const Text('—', style: TextStyle(color: Color(0xFF7891B4)))
        else
          Text(
            '${_formatNumber(data.value!)} ${data.unit}',
            style: const TextStyle(
              color: Color(0xFF172554),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _NutritionRing extends StatelessWidget {
  const _NutritionRing({required this.summary, required this.showRangeLabel});

  final DietSummary summary;
  final bool showRangeLabel;

  @override
  Widget build(BuildContext context) {
    final nutrition = summary.nutrition;
    final data = _MacroRingData.macros(
      carbohydrates: nutrition?.carbohydratesG?.total,
      protein: nutrition?.proteinG?.total,
      fat: nutrition?.fatG?.total,
    );
    final calories = nutrition?.caloriesKcal?.total;
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size.square(124), painter: _MacroRingPainter(data)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                calories == null ? '—' : _formatNumber(calories),
                style: const TextStyle(
                  color: Color(0xFF172554),
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
              Text(
                showRangeLabel ? 'ring: day' : 'kcal',
                style: const TextStyle(color: Color(0xFF5573A4), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecentFoodLogSection extends StatelessWidget {
  const RecentFoodLogSection({
    super.key,
    required this.summary,
    required this.onMealTap,
    required this.onSeeAll,
    this.limit = 3,
  });

  final DietSummary summary;
  final ValueChanged<Meal> onMealTap;
  final VoidCallback onSeeAll;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final entries = <_FoodLogEntry>[];
    final meals = [...summary.meals]
      ..sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    for (final meal in meals) {
      for (final item in meal.items) {
        entries.add(_FoodLogEntry(meal: meal, item: item));
      }
    }
    final visible = limit == null || entries.length <= limit!
        ? entries
        : entries.take(limit!).toList();
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  color: Color(0xFF075E55), size: 27),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent food log',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF172554),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: onSeeAll,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('See all'),
              ),
            ],
          ),
          const Divider(),
          if (visible.isEmpty)
            const _InlineEmpty(
              icon: Icons.restaurant_menu_rounded,
              title: 'No food items recorded',
              message: 'Items added to meals will appear here.',
            )
          else
            for (final entry in visible)
              _FoodLogRow(
                entry: entry,
                onTap: () => onMealTap(entry.meal),
              ),
        ],
      ),
    );
  }
}

class _FoodLogEntry {
  const _FoodLogEntry({required this.meal, required this.item});

  final Meal meal;
  final MealItem item;
}

class _FoodLogRow extends StatelessWidget {
  const _FoodLogRow({required this.entry, required this.onTap});

  final _FoodLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final amount = item.quantity;
    final unit = item.unit;
    final quantity = amount == null
        ? null
        : '${_formatNumber(amount)}${unit == null || unit.isEmpty ? '' : ' $unit'}';
    final calories = item.caloriesKcal;
    final detail = [
      if (calories != null) '${_formatNumber(calories)} kcal',
      if (quantity != null) quantity,
    ].join('  •  ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFEFE8),
        child: Icon(_foodIcon(item.name), color: const Color(0xFFFF6B2C)),
      ),
      title: Text(
        item.name,
        style: const TextStyle(
          color: Color(0xFF172554),
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        detail.isEmpty ? 'No nutrition or quantity recorded' : detail,
        style: const TextStyle(color: Color(0xFF5573A4), fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('h:mm a').format(entry.meal.consumedAt),
            style: const TextStyle(color: Color(0xFF5573A4), fontSize: 11),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF172554)),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24415E).withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF7891B4)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF172554),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5573A4), fontSize: 12),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class DietGoalsSection extends StatelessWidget {
  const DietGoalsSection({
    super.key,
    required this.profile,
    required this.loading,
    required this.onOpenProfile,
    required this.onRetry,
  });

  final DietProfile? profile;
  final bool loading;
  final VoidCallback onOpenProfile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading && profile == null) {
      return const _DashboardCard(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final value = profile;
    final preference = value?.dietaryPreference;
    final custom = value?.customPreference;
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag_outlined, color: Color(0xFF075E55), size: 27),
              SizedBox(width: 8),
              Text(
                'Diet goals',
                style: TextStyle(
                  color: Color(0xFF172554),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (value == null)
            const _InlineEmpty(
              icon: Icons.tune_rounded,
              title: 'Set up your diet profile',
              message: 'Diet goals and targets are not available in this account yet.',
            )
          else ...[
            _GoalFact(
              label: 'Dietary preference',
              value: custom == null || custom.trim().isEmpty
                  ? preference?.label ?? 'Not set'
                  : custom.trim(),
            ),
            _GoalFact(
              label: 'Disliked foods',
              value: value.dislikedFoods?.trim().isNotEmpty == true
                  ? value.dislikedFoods!.trim()
                  : 'None recorded',
            ),
            if (value.notes?.trim().isNotEmpty == true)
              _GoalFact(label: 'Notes', value: value.notes!.trim()),
            const SizedBox(height: 10),
            const Text(
              'Nutrition, hydration and activity targets are not stored in Diet. Use guidance from a qualified professional to set them.',
              style: TextStyle(color: Color(0xFF5573A4), fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          if (value == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check again'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Set up profile'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Open diet profile'),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalFact extends StatelessWidget {
  const _GoalFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF5573A4), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF172554),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _foodIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('coffee') || value.contains('tea')) {
    return Icons.local_cafe_rounded;
  }
  if (value.contains('apple') || value.contains('fruit')) {
    return Icons.apple_rounded;
  }
  if (value.contains('salad') || value.contains('veg')) {
    return Icons.eco_rounded;
  }
  if (value.contains('water') || value.contains('milk')) {
    return Icons.water_drop_rounded;
  }
  return Icons.restaurant_rounded;
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
