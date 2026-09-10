import 'package:flutter/material.dart';

import '../health_models.dart';
import '../health_repository.dart';
import 'activity_form_screen.dart';
import 'widgets.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.repository});

  final HealthRepository repository;

  @override
  Widget build(BuildContext context) {
    return RecordListScreen<HealthActivity>(
      title: 'Activity',
      emptyMessage: 'No activities yet.\nTap + to record one.',
      load: repository.loadActivities,
      delete: (activity) => repository.deleteActivity(activity.id),
      itemBuilder: (context, activity) => _ActivityTile(activity),
      formBuilder: (context, edited) =>
          ActivityFormScreen(repository: repository, initial: edited),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile(this.activity);

  final HealthActivity activity;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = [
      activityTypeLabels[activity.type] ?? activity.type.name,
      if (activity.durationMinutes != null) formatMinutes(activity.durationMinutes),
      if (activity.distanceKm != null) '${formatDouble(activity.distanceKm)} km',
      if (activity.caloriesBurned != null) '${activity.caloriesBurned} kcal',
    ];
    return Row(
      children: [
        const Icon(Icons.directions_run),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parts.join(' · '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                formatDateTime(activity.performedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}