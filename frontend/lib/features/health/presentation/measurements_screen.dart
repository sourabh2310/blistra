import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'measurement_form_screen.dart';
import 'widgets.dart';

class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final HealthRepository repository;

  /// Invoked after a successful create/edit/delete (for dashboard refresh).
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context) {
    return RecordListScreen<HealthMeasurement>(
      title: 'Measurements',
      noun: 'reading',
      emptyMessage: 'No measurements yet. Add your first reading.',
      load: repository.loadMeasurements,
      delete: (measurement) => repository.deleteMeasurement(measurement.id),
      itemBuilder: _row,
      formBuilder: (context, edited) => MeasurementFormScreen(
        repository: repository,
        initial: edited,
      ),
      onChanged: onChanged,
    );
  }

  static HealthRow _row(BuildContext context, HealthMeasurement measurement) {
    final MeasurementType type = measurement.type;
    final String when = relativeDay(measurement.measuredAt, DateTime.now());
    final String source = measurement.source?.trim() ?? '';
    return HealthRow(
      icon: measurementTypeIcons[type] ?? Icons.monitor_heart_outlined,
      color: measurementColor(BlistraColors.resolve(context), type),
      title: measurementTypeLabels[type] ?? type.name,
      subtitle: [
        '${measurementNumber(measurement)} ${displayUnit(measurement.unit)}',
        when,
        if (source.isNotEmpty) source,
      ].join(' · '),
    );
  }
}
