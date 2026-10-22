import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
      noun: 'entry',
      emptyMessage: 'No logs yet. Note a symptom or observation.',
      load: repository.loadLogs,
      delete: (log) => repository.deleteLog(log.id),
      itemBuilder: _row,
      formBuilder: (context, edited) =>
          LogFormScreen(repository: repository, initial: edited),
    );
  }

  static HealthRow _row(BuildContext context, HealthLogEntry log) =>
      logRow(BlistraColors.resolve(context), log, DateTime.now());
}

/// Row for a symptom/observation log, shared with the Health home.
HealthRow logRow(BlistraColors colors, HealthLogEntry log, DateTime now) {
  return HealthRow(
    icon: Icons.sick_outlined,
    color: switch (log.severity) {
      Severity.severe => colors.danger,
      Severity.moderate => colors.warning,
      _ => colors.data[2],
    },
    title: log.title,
    subtitle: [
      'Symptom',
      if (log.severity != null)
        severityLabels[log.severity] ?? '${log.severity}',
      relativeDay(log.observedAt, now),
    ].join(' · '),
  );
}
