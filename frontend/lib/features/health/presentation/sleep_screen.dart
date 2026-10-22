import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/app_theme.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'sleep_form_screen.dart';
import 'widgets.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key, required this.repository});

  final HealthRepository repository;

  @override
  Widget build(BuildContext context) {
    return RecordListScreen<HealthSleepRecord>(
      title: 'Sleep',
      noun: 'night',
      emptyMessage: 'No sleep records yet. Log last night.',
      load: repository.loadSleepRecords,
      delete: (record) => repository.deleteSleep(record.id),
      itemBuilder: _row,
      formBuilder: (context, edited) =>
          SleepFormScreen(repository: repository, initial: edited),
    );
  }

  static HealthRow _row(BuildContext context, HealthSleepRecord record) {
    final DateFormat time = DateFormat('h:mm a');
    final String notes = record.notes?.trim() ?? '';
    return HealthRow(
      icon: Icons.bedtime_outlined,
      color: BlistraColors.resolve(context).data[0],
      title: '${relativeDay(record.endedAt, DateTime.now())} · '
          '${durationText(sleepMinutes(record))}',
      subtitle: [
        '${time.format(record.startedAt.toLocal())} → '
            '${time.format(record.endedAt.toLocal())}',
        if (record.rating != null) 'Feeling ${record.rating}/5',
        if (notes.isNotEmpty) notes,
      ].join(' · '),
    );
  }
}
