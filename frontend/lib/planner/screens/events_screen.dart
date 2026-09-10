import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/planner_event.dart';
import '../planner_controller.dart';
import '../widgets/event_card.dart';
import '../widgets/status_views.dart';
import 'event_form_screen.dart';

/// The Events tab: a list of the user's time-blocked events.
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
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (planner.totalEvents == 0 && !planner.loading) {
            planner.loadEvents();
          }
        });

        return Scaffold(
          body: _buildBody(context, planner),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(context, planner),
            tooltip: 'New event',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (planner.error != null && planner.events.isEmpty) {
      return ErrorRetry(message: planner.error!, onRetry: planner.loadEvents);
    }
    if (planner.events.isEmpty) {
      return RefreshIndicator(
        onRefresh: planner.loadEvents,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.event_available,
              message: 'No events yet.\nTap + to plan one.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: planner.loadEvents,
      child: ListView.separated(
        itemCount: planner.events.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final event = planner.events[index];
          return EventCard(
            event: event,
            onEdit: () => _openForm(context, planner, event: event),
            onDelete: () => _confirm(
              context,
              'Delete "${event.title}"?',
              () => planner.deleteEvent(event.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    PlannerController planner, {
    PlannerEvent? event,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(planner: planner, event: event),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(event == null ? 'Event created' : 'Event updated')),
      );
    }
  }

  Future<void> _confirm(
    BuildContext context,
    String message,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) {
      action();
    }
  }
}