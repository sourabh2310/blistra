import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
      noun: 'session',
      emptyMessage: 'No activities yet. Log a walk, run or workout.',
      load: repository.loadActivities,
      delete: (activity) => repository.deleteActivity(activity.id),
      itemBuilder: _row,
      formBuilder: (context, edited) =>
          ActivityFormScreen(repository: repository, initial: edited),
    );
  }

  static HealthRow _row(BuildContext context, HealthActivity activity) {
    final String label = activityTypeLabels[activity.type] ?? activity.type.name;
    return HealthRow(
      icon: activityIcon(activity.type),
      color: BlistraColors.resolve(context).data[1],
      title: activity.durationMinutes == null
          ? label
          : '$label · ${formatMinutes(activity.durationMinutes)}',
      subtitle: [
        relativeDay(activity.performedAt, DateTime.now()),
        if (activity.distanceKm != null)
          '${formatDouble(activity.distanceKm)} km',
        if (activity.caloriesBurned != null) '${activity.caloriesBurned} kcal',
      ].join(' · '),
    );
  }
}

/// Icon for each activity type.
IconData activityIcon(ActivityType type) => switch (type) {
      ActivityType.walking => Icons.directions_walk_rounded,
      ActivityType.running => Icons.directions_run_rounded,
      ActivityType.cycling => Icons.directions_bike_rounded,
      ActivityType.swimming => Icons.pool_rounded,
      ActivityType.strengthTraining => Icons.fitness_center_rounded,
      ActivityType.yoga => Icons.self_improvement_rounded,
      ActivityType.sports => Icons.sports_tennis_rounded,
      ActivityType.other => Icons.bolt_rounded,
    };
