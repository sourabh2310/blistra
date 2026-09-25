import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../diet_trends.dart';

/// On-demand trends over the last 7 recorded days.
///
/// Loads bounded per-day summaries only when the user asks, shows factual
/// averages and daily values, and never offers medical interpretation.
class TrendsCard extends StatefulWidget {
  const TrendsCard({super.key});

  @override
  State<TrendsCard> createState() => _TrendsCardState();
}

class _TrendsCardState extends State<TrendsCard> {
  bool _expanded = false;
  bool _loading = false;
  Object? _error;
  TrendsSummary? _trends;

  Future<void> _load() async {
    setState(() {
      _expanded = true;
      _loading = true;
      _error = null;
    });
    try {
      final summaries =
          await context.read<DietController>().loadRangeSummaries(days: 7);
      if (!mounted) {
        return;
      }
      setState(() {
        _trends = summarizeTrends(summaries);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Trends · last 7 days',
                      style: textTheme.titleSmall),
                ),
                if (!_expanded && !_loading)
                  TextButton(
                    onPressed: _load,
                    child: const Text('Show'),
                  ),
                if (_expanded && !_loading)
                  TextButton(
                    onPressed: () => setState(() => _expanded = false),
                    child: const Text('Hide'),
                  ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Could not load trends: $_error',
                      style: textTheme.bodySmall),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else if (_expanded && _trends != null)
              _TrendsBody(trends: _trends!),
          ],
        ),
      ),
    );
  }
}

class _TrendsBody extends StatelessWidget {
  const _TrendsBody({required this.trends});

  final TrendsSummary trends;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final avgCalories = trends.averageCaloriesKcal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (avgCalories == null)
          Text('No calorie data in the last 7 days.',
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.outline))
        else
          Text(
            'Average calories: ${_fmt(avgCalories)} kcal/day',
            style: textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        for (final metric in [
          ('Protein', trends.averageProteinG, 'g'),
          ('Carbs', trends.averageCarbohydratesG, 'g'),
          ('Fat', trends.averageFatG, 'g'),
        ])
          if (metric.$2 != null)
            Text('Average ${metric.$1}: ${_fmt(metric.$2!)} ${metric.$3}/day',
                style: textTheme.bodySmall),
        if (trends.averageWaterMilliliters != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Average water: ${_fmtWater(trends.averageWaterMilliliters!)}/day',
              style: textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        for (final day in trends.days)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE d MMM').format(day.date),
                    style: textTheme.bodyMedium,
                  ),
                ),
                if (day.waterMilliliters != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      _fmtWater(day.waterMilliliters!),
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ),
                Text(
                  day.caloriesKcal == null
                      ? '—'
                      : '${_fmt(day.caloriesKcal!)} kcal',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    if (value >= 100) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _fmtWater(double milliliters) {
    if (milliliters >= 1000) {
      return '${(milliliters / 1000).toStringAsFixed(1)} L';
    }
    return '${milliliters.round()} ml';
  }
}
