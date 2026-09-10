import 'package:flutter/material.dart';

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
      emptyMessage: 'No sleep records yet.\nTap + to record one.',
      load: repository.loadSleepRecords,
      delete: (record) => repository.deleteSleep(record.id),
      itemBuilder: (context, record) => _SleepTile(record),
      formBuilder: (context, edited) =>
          SleepFormScreen(repository: repository, initial: edited),
    );
  }
}

class _SleepTile extends StatelessWidget {
  const _SleepTile(this.record);

  final HealthSleepRecord record;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = [
      if (record.durationMinutes != null) formatMinutes(record.durationMinutes),
      '${formatDateTime(record.startedAt)} → ${formatDateTime(record.endedAt)}',
      if (record.rating != null) 'Rating ${record.rating}/5',
    ];
    return Row(
      children: [
        const Icon(Icons.bedtime_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parts.join(' · '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (record.notes != null && record.notes!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  record.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}