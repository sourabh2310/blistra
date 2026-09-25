import 'package:flutter/material.dart';

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
      emptyMessage: 'No measurements yet.\nTap + to record one.',
      load: repository.loadMeasurements,
      delete: (measurement) => repository.deleteMeasurement(measurement.id),
      itemBuilder: (context, measurement) => _MeasurementTile(measurement),
      formBuilder: (context, edited) => MeasurementFormScreen(
        repository: repository,
        initial: edited,
      ),
      onChanged: onChanged,
    );
  }
}

class _MeasurementTile extends StatelessWidget {
  const _MeasurementTile(this.measurement);

  final HealthMeasurement measurement;

  @override
  Widget build(BuildContext context) {
    final MeasurementType type = measurement.type;
    final String diastolic = measurement.valueDiastolic == null
        ? ''
        : ' / ${formatDouble(measurement.valueDiastolic)}';
    final List<String> lines = [
      '${formatDouble(measurement.value)}$diastolic ${measurement.unit}',
      formatDateTime(measurement.measuredAt),
    ];
    if (measurement.source != null && measurement.source!.isNotEmpty) {
      lines.add(measurement.source!);
    }

    return Row(
      children: [
        Icon(measurementTypeIcons[type] ?? Icons.monitor_heart_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                measurementTypeLabels[type] ?? type.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                lines.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}