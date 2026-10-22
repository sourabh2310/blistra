import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/glass.dart';
import '../diet_controller.dart';
import '../diet_trends.dart';
import 'diet_ui.dart';

/// "Last 7 days" calorie bars from the user's own recorded days.
///
/// Loads bounded per-day summaries through
/// [DietController.loadRangeSummaries] and reloads whenever [token] changes
/// (pass the current day summary so new meals show up). Days without a
/// calorie value get an empty stub, never a zero bar.
class TrendsCard extends StatefulWidget {
  const TrendsCard({super.key, this.token});

  final Object? token;

  @override
  State<TrendsCard> createState() => _TrendsCardState();
}

class _TrendsCardState extends State<TrendsCard> {
  int _request = 0;
  bool _loading = true;
  Object? _error;
  TrendsSummary? _trends;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant TrendsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != null && !identical(widget.token, oldWidget.token)) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = _trends == null;
      _error = null;
    });
    try {
      final summaries =
          await context.read<DietController>().loadRangeSummaries(days: 7);
      if (!mounted || request != _request) return;
      setState(() {
        _trends = summarizeTrends(summaries);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    if (_error != null && _trends == null) {
      return UnavailableCard(name: 'Trends', onRetry: _load);
    }
    final trends = _trends;
    if (_loading || trends == null) {
      return GlassCard(
        padding: const EdgeInsets.all(15),
        child: SizedBox(
          height: 96,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accentText,
              ),
            ),
          ),
        ),
      );
    }
    final avg = trends.averageCaloriesKcal;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CalorieBars(days: trends.days, height: 70),
          const SizedBox(height: 10),
          Text(
            avg == null
                ? 'No calories recorded in the last 7 days'
                : 'Avg ${formatKcal(avg)} kcal/day · '
                    '${trends.daysWithMeals} of ${trends.days.length} days logged',
            style: TextStyle(fontSize: 11, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Vertical calorie bars, one per day, with weekday initials. The last day
/// is highlighted in the accent.
class CalorieBars extends StatelessWidget {
  const CalorieBars({super.key, required this.days, this.height = 70});

  final List<TrendDay> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final largest = days.fold<double>(
      0,
      (m, d) => math.max(m, d.caloriesKcal ?? 0),
    );
    final label = days
        .map((d) =>
            '${DateFormat('EEEE').format(d.date)}: '
            '${d.caloriesKcal == null ? 'not recorded' : '${formatKcal(d.caloriesKcal!)} kcal'}')
        .join(', ');
    return Semantics(
      label: 'Calories by day. $label',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  Expanded(
                    child: Container(
                      height: days[i].caloriesKcal == null || largest == 0
                          ? 5
                          : math.max(6, height * days[i].caloriesKcal! / largest),
                      decoration: BoxDecoration(
                        color: days[i].caloriesKcal == null
                            ? colors.inkAt(0.08)
                            : i == days.length - 1
                                ? colors.accentText
                                : colors.inkAt(0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    DateFormat('E').format(days[i].date).substring(0, 1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: i == days.length - 1
                          ? colors.accentText
                          : colors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the trends sheet: factual averages and daily values over 7, 30 or
/// 90 days. Never offers medical interpretation.
Future<void> showDietTrendsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _TrendsSheet(),
  );
}

class _TrendsSheet extends StatefulWidget {
  const _TrendsSheet();

  @override
  State<_TrendsSheet> createState() => _TrendsSheetState();
}

class _TrendsSheetState extends State<_TrendsSheet> {
  int _days = 7;
  int _request = 0;
  bool _loading = true;
  Object? _error;
  TrendsSummary? _trends;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summaries = await context
          .read<DietController>()
          .loadRangeSummaries(days: _days);
      if (!mounted || request != _request) return;
      setState(() {
        _trends = summarizeTrends(summaries);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final trends = _trends;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 28),
        children: [
          Text('Trends', style: BlistraText.serif(22, colors.text)),
          const SizedBox(height: 4),
          Text(
            'Averages cover only days with a recorded value.',
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          const SizedBox(height: 14),
          GlassSegmented<int>(
            options: const [(7, '7 days'), (30, '30 days'), (90, '90 days')],
            selected: _days,
            onChanged: (days) {
              if (days == _days) return;
              setState(() => _days = days);
              _load();
            },
          ),
          const SizedBox(height: 14),
          if (_loading)
            SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: colors.accentText),
              ),
            )
          else if (_error != null || trends == null)
            UnavailableCard(name: 'Trend data', onRetry: _load)
          else ...[
            GlassCard(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Figure(
                          label: 'Avg calories',
                          value: _avg(trends.averageCaloriesKcal, ' kcal',
                              kcal: true),
                        ),
                      ),
                      Expanded(
                        child: Figure(
                          label: 'Avg water',
                          value: trends.averageWaterMilliliters == null
                              ? '—'
                              : formatWater(trends.averageWaterMilliliters!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Figure(
                          label: 'Protein',
                          value: _avg(trends.averageProteinG, ' g'),
                        ),
                      ),
                      Expanded(
                        child: Figure(
                          label: 'Carbs',
                          value: _avg(trends.averageCarbohydratesG, ' g'),
                        ),
                      ),
                      Expanded(
                        child: Figure(
                          label: 'Fat',
                          value: _avg(trends.averageFatG, ' g'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_days == 7) ...[
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
                child: CalorieBars(days: trends.days),
              ),
            ],
            const SizedBox(height: 18),
            Text('By day', style: BlistraText.serif(17, colors.text)),
            const SizedBox(height: 10),
            GlassList(
              children: [
                for (final day in trends.days.reversed)
                  GlassRow(
                    title: DateFormat('EEE d MMM').format(day.date),
                    subtitle: day.waterMilliliters == null
                        ? null
                        : 'Water ${formatWater(day.waterMilliliters!)}',
                    trailing: RowMeta(
                      day.caloriesKcal == null
                          ? '—'
                          : '${formatKcal(day.caloriesKcal!)} kcal',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _avg(double? value, String unit, {bool kcal = false}) {
    if (value == null) return '—';
    return '${kcal ? formatKcal(value) : formatDietNumber(value)}$unit';
  }
}
