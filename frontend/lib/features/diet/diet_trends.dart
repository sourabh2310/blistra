/// Pure, widget-free helpers for Diet trends.
///
/// Everything derives from the user's own recorded [DietSummary] days.
/// A day without a recorded value is excluded from that metric's average —
/// missing data is never silently treated as zero. Output is factual
/// arithmetic only, never medical interpretation.
library;

import 'models/summary.dart';

/// One day's trendable values; null means "not recorded that day".
class TrendDay {
  TrendDay({
    required this.date,
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
    this.waterMilliliters,
  });

  factory TrendDay.fromSummary(DietSummary summary) {
    return TrendDay(
      date: DateTime(
        summary.date.year,
        summary.date.month,
        summary.date.day,
      ),
      caloriesKcal: summary.nutrition?.caloriesKcal?.total,
      proteinG: summary.nutrition?.proteinG?.total,
      carbohydratesG: summary.nutrition?.carbohydratesG?.total,
      fatG: summary.nutrition?.fatG?.total,
      waterMilliliters: summary.waterTotalMilliliters,
    );
  }

  final DateTime date;
  final double? caloriesKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;
  final double? waterMilliliters;
}

/// Factual averages over [days]; each average covers only days with a
/// recorded value for that metric (null when no day recorded it).
class TrendsSummary {
  TrendsSummary({required List<TrendDay> days})
      : days = List.unmodifiable((List.of(days)
          ..sort((a, b) => a.date.compareTo(b.date))));

  final List<TrendDay> days;

  double? get averageCaloriesKcal => _average((d) => d.caloriesKcal);
  double? get averageProteinG => _average((d) => d.proteinG);
  double? get averageCarbohydratesG =>
      _average((d) => d.carbohydratesG);
  double? get averageFatG => _average((d) => d.fatG);
  double? get averageWaterMilliliters =>
      _average((d) => d.waterMilliliters);

  int get daysWithMeals =>
      days.where((d) => d.caloriesKcal != null).length;

  bool get isEmpty => days.isEmpty;

  double? _average(double? Function(TrendDay) pick) {
    double sum = 0;
    int count = 0;
    for (final day in days) {
      final value = pick(day);
      if (value != null) {
        sum += value;
        count++;
      }
    }
    if (count == 0) {
      return null;
    }
    return sum / count;
  }
}

/// Builds a [TrendsSummary] from per-day summaries (any order).
TrendsSummary summarizeTrends(List<DietSummary> summaries) =>
    TrendsSummary(days: summaries.map(TrendDay.fromSummary).toList());
