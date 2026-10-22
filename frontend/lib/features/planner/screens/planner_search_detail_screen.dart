import 'package:flutter/material.dart';

import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
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
    if (parts.length < 3) return const _Unavailable();
    final planner = AppScope.of(context).planner;
    final Widget page = switch (parts[1]) {
      'task' => TaskDetailScreen(planner: planner, taskId: parts[2]),
      'event' => EventDetailScreen(planner: planner, eventId: parts[2]),
      'list' => ListDetailScreen(planner: planner, listId: parts[2]),
      _ => const _Unavailable(),
    };
    return page;
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: const [
            BlistraPageHeader(eyebrow: 'Planner', title: 'Planner details', showAvatar: false),
            PagePad(EmptyCard(message: "Couldn't load this Planner item."), top: 10),
          ],
        ),
      ),
    );
  }
}
