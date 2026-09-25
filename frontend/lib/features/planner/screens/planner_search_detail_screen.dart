import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import 'event_detail_screen.dart';
import 'list_detail_screen.dart';
import 'task_detail_screen.dart';

class PlannerSearchDetailScreen extends StatelessWidget {
  const PlannerSearchDetailScreen({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    final parts = route.split('/');
    if (parts.length < 3) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planner details')),
        body: const Center(child: Text("Couldn't load this Planner item.")),
      );
    }
    final planner = AppScope.of(context).planner;
    final Widget page = switch (parts[1]) {
      'task' => TaskDetailScreen(planner: planner, taskId: parts[2]),
      'event' => EventDetailScreen(planner: planner, eventId: parts[2]),
      'list' => ListDetailScreen(planner: planner, listId: parts[2]),
      _ => Scaffold(
          appBar: AppBar(title: const Text('Planner details')),
          body: const Center(child: Text("Couldn't load this Planner item.")),
        ),
    };
    return page;
  }
}
