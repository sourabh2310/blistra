import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../health_models.dart';
import '../health_repository.dart';
import '../overview_stats.dart';
import 'measurement_form_screen.dart';
import 'widgets.dart';

/// One vital (weight, blood pressure, …): latest value and change, a trend
/// chart over a chosen range, and the full reading history with edit and
/// delete. Follows the Detail page template.
class VitalDetailScreen extends StatefulWidget {
  const VitalDetailScreen({
    super.key,
    required this.repository,
    required this.type,
    this.onChanged,
  });

  final HealthRepository repository;
  final MeasurementType type;

  /// Invoked after a successful create/edit/delete (for dashboard refresh).
  final Future<void> Function()? onChanged;

  @override
  State<VitalDetailScreen> createState() => _VitalDetailScreenState();
}

class _VitalDetailScreenState extends State<VitalDetailScreen> {
  static const List<(int, String)> _ranges = [
    (7, '7D'),
    (30, '1M'),
    (90, '3M'),
    (365, '1Y'),
  ];

  int _days = 30;

  HealthRepository get _repository => widget.repository;

  Future<void> _reload() async {
    try {
      await _repository.loadMeasurements(size: 100);
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  Future<void> _openForm({HealthMeasurement? initial}) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MeasurementFormScreen(
          repository: _repository,
          initial: initial,
          initialType: widget.type,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload();
      await widget.onChanged?.call();
    }
  }

  Future<void> _confirmDelete(HealthMeasurement measurement) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Delete record',
      message: 'This record will be permanently removed.',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await _repository.deleteMeasurement(measurement.id);
      if (!mounted) {
        return;
      }
      await _reload();
      await widget.onChanged?.call();
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repository,
      builder: (context, _) {
        final BlistraColors colors = BlistraColors.resolve(context);
        final DateTime now = DateTime.now();
        final String label =
            measurementTypeLabels[widget.type] ?? widget.type.name;
        final List<HealthMeasurement> history = historyFor(
          _repository.measurements,
          widget.type,
          limit: 1000,
        );
        final HealthMeasurement? latest = history.isEmpty ? null : history.first;
        final String? change =
            history.length >= 2
            ? shortChange(history[0], history[1], signs: true)
            : null;
        final DateTime cutoff = now.subtract(Duration(days: _days));
        final List<HealthMeasurement> visible = history
            .where((m) => !m.measuredAt.isBefore(cutoff))
            .toList()
            .reversed
            .toList();
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  BlistraPageHeader(
                    eyebrow: 'Vitals',
                    title: label,
                    subtitle: latest == null
                        ? 'No readings yet'
                        : 'Latest ${measurementNumber(latest)} '
                            '${displayUnit(latest.unit)} · '
                            '${relativeDay(latest.measuredAt, now).toLowerCase()}',
                    showAvatar: false,
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: 14),
                    StatStrip(
                      stats: [
                        StatData(
                          label: 'Latest',
                          value: measurementNumber(latest),
                          unit: displayUnit(latest.unit),
                          sub: relativeDay(latest.measuredAt, now),
                        ),
                        if (change != null)
                          StatData(
                            label: 'Change',
                            value: change,
                            unit: change == 'No change'
                                ? ''
                                : displayUnit(latest.unit),
                            sub: 'vs last reading',
                          ),
                        StatData(
                          label: 'Readings',
                          value: '${history.length}',
                          sub: 'Since ${DateFormat('d MMM y').format(history.last.measuredAt.toLocal())}',
                        ),
                      ],
                    ),
                  ],
                  PagePad(
                    GlassSegmented<int>(
                      options: _ranges,
                      selected: _days,
                      onChanged: (days) => setState(() => _days = days),
                    ),
                    top: 18,
                  ),
                  PagePad(
                    GlassCard(
                      radius: 22,
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
                      child: visible.isEmpty
                          ? SizedBox(
                              height: 150,
                              child: Center(
                                child: Text(
                                  'No ${label.toLowerCase()} readings in this period',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.muted,
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 190,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _TrendPainter(
                                  history: visible,
                                  colors: colors,
                                  textDirection: Directionality.of(context),
                                ),
                              ),
                            ),
                    ),
                    top: 10,
                  ),
                  const SizedBox(height: 26),
                  const SectionHeader(title: 'History'),
                  PagePad(
                    history.isEmpty
                        ? EmptyCard(
                            message: 'No ${label.toLowerCase()} readings yet.',
                          )
                        : GlassList(
                            children: [
                              for (final HealthMeasurement m in history)
                                GlassRow(
                                  onTap: () => _openForm(initial: m),
                                  title: '${measurementNumber(m)} '
                                      '${displayUnit(m.unit)}',
                                  subtitle: [
                                    friendlyDateTime(m.measuredAt),
                                    if ((m.source ?? '').trim().isNotEmpty)
                                      m.source!.trim(),
                                  ].join(' · '),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 19,
                                      color: colors.muted,
                                    ),
                                    tooltip: 'Delete',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _confirmDelete(m),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: StickyActionBar(
            label: 'Add reading',
            onPressed: () => _openForm(),
          ),
        );
      },
    );
  }
}

/// Line chart of [history] (oldest first). Blood pressure plots systolic.
class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.history,
    required this.colors,
    required this.textDirection,
  });

  final List<HealthMeasurement> history;
  final BlistraColors colors;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty || size.width < 80 || size.height < 80) {
      return;
    }
    const double left = 36;
    const double right = 8;
    const double top = 10;
    const double bottom = 24;
    final double width = size.width - left - right;
    final double height = size.height - top - bottom;
    final List<double> values = history.map((item) => item.value).toList();
    double minimum = values.reduce((a, b) => a < b ? a : b);
    double maximum = values.reduce((a, b) => a > b ? a : b);
    final double spread = maximum - minimum;
    if (spread < 1) {
      minimum -= 0.5;
      maximum += 0.5;
    } else {
      minimum -= spread * 0.16;
      maximum += spread * 0.16;
    }
    final TextStyle labelStyle = TextStyle(
      fontFamily: 'Inter',
      color: colors.muted,
      fontSize: 9,
      fontFeatures: BlistraText.tabular,
    );
    final Paint grid = Paint()
      ..color = colors.inkAt(0.08)
      ..strokeWidth = 1;
    for (int index = 0; index < 4; index++) {
      final double y = top + height * index / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final double value = maximum - (maximum - minimum) * index / 3;
      _paintText(canvas, formatDouble((value * 10).round() / 10),
          Offset(0, y - 6), labelStyle);
    }
    final List<Offset> points = [
      for (int index = 0; index < values.length; index++)
        Offset(
          values.length == 1
              ? left + width / 2
              : left + width * index / (values.length - 1),
          top + height * (maximum - values[index]) / (maximum - minimum),
        ),
    ];
    final Path fill = Path()..moveTo(points.first.dx, top + height);
    for (final Offset point in points) {
      fill.lineTo(point.dx, point.dy);
    }
    fill
      ..lineTo(points.last.dx, top + height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.accentText.withValues(alpha: 0.28),
            colors.accentText.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, top, size.width, height)),
    );
    final Path line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.accentText
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final Offset point in points) {
      canvas.drawCircle(point, 4, Paint()..color = colors.accentText);
      canvas.drawCircle(point, 1.6, Paint()..color = colors.background);
    }
    final DateFormat format = DateFormat('d MMM');
    for (final int index in {0, history.length ~/ 2, history.length - 1}) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: format.format(history[index].measuredAt.toLocal()),
          style: labelStyle,
        ),
        textDirection: textDirection,
      )..layout();
      final double dx = (points[index].dx - painter.width / 2)
          .clamp(0, size.width - painter.width)
          .toDouble();
      painter.paint(canvas, Offset(dx, size.height - painter.height));
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.history != history || oldDelegate.colors != colors;
}
