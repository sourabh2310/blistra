import 'package:flutter/material.dart';

import '../health_models.dart';
import '../health_repository.dart';
import 'log_form_screen.dart';
import 'widgets.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.repository});

  final HealthRepository repository;

  @override
  Widget build(BuildContext context) {
    return RecordListScreen<HealthLogEntry>(
      title: 'Health logs',
      emptyMessage: 'No logs yet.\nTap + to record an observation.',
      load: repository.loadLogs,
      delete: (log) => repository.deleteLog(log.id),
      itemBuilder: (context, log) => _LogTile(log),
      formBuilder: (context, edited) =>
          LogFormScreen(repository: repository, initial: edited),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile(this.log);

  final HealthLogEntry log;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = [
      if (log.severity != null) severityLabels[log.severity] ?? '${log.severity}',
      formatDateTime(log.observedAt),
    ];
    return Row(
      children: [
        const Icon(Icons.assignment_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                parts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}