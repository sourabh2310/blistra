import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../../../features/app_scope.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../planner_controller.dart';
import '../widgets/event_card.dart';
import '../widgets/status_views.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) => RefreshIndicator(
        onRefresh: planner.loadEvents,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(planner)),
            ..._body(context, planner),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _header(PlannerController planner) {
    final events = _visibleEvents(planner);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is scheduled?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text('${events.length} ${events.length == 1 ? 'event' : 'events'}', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.events.isEmpty) {
      return const [SliverToBoxAdapter(child: SkeletonLoader(rows: 5, rowHeight: 78))];
    }
    if (planner.error != null && planner.events.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorRetry(
            message: "Couldn't load your events.",
            onRetry: planner.loadEvents,
          ),
        ),
      ];
    }
    final events = _visibleEvents(planner);
    if (events.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _emptyState(
            title: planner.searchQuery.trim().isNotEmpty ? 'No matching events' : 'No events yet',
            message: planner.searchQuery.trim().isNotEmpty
                ? 'Try a different Planner search.'
                : 'Use the global Add button to schedule an appointment or commitment.',
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: EventCard(
              event: event,
              onOpen: () => _openDetail(context, planner, event),
              onEdit: () => _openForm(context, planner, event: event),
              onDelete: () => _confirm(context, event, () => planner.deleteEvent(event.id)),
              onToggleComplete: () => _runAction(
                context,
                () => event.status == EventStatus.completed || event.status == EventStatus.cancelled
                    ? planner.reopenEvent(event.id)
                    : planner.completeEvent(event.id),
              ),
              onCancel: event.status == EventStatus.scheduled
                  ? () => _runAction(context, () => planner.cancelEvent(event.id))
                  : null,
            ),
          );
        },
      ),
    ];
  }

  List<PlannerEvent> _visibleEvents(PlannerController planner) {
    final query = planner.searchQuery.trim().toLowerCase();
    final events = List<PlannerEvent>.from(planner.events)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (query.isEmpty) return events;
    return events.where((event) {
      return event.title.toLowerCase().contains(query) ||
          (event.description?.toLowerCase().contains(query) ?? false) ||
          (event.location?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Widget _emptyState({required String title, required String message}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: AppCard(
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, PlannerController planner, PlannerEvent event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EventDetailScreen(planner: planner, eventId: event.id)),
    );
  }

  Future<void> _openForm(BuildContext context, PlannerController planner, {PlannerEvent? event}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventFormScreen(planner: planner, event: event)),
    );
    if (saved == true && context.mounted) {
      showAppMessage(context, event == null ? 'Event created' : 'Event updated');
    }
  }

  Future<void> _confirm(BuildContext context, PlannerEvent event, Future<void> Function() action) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this event?',
      message: 'This cannot be undone.',
    );
    if (confirmed) await _runAction(context, action);
  }

  Future<void> _runAction(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) showAppMessage(context, "Couldn't update this event.", error: true);
    }
  }
}
