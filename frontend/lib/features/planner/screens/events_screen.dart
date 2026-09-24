import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../planner_controller.dart';
import '../widgets/event_card.dart';
import '../widgets/status_views.dart';
import 'event_form_screen.dart';

/// Events tab: time-bound appointments and commitments.
///
/// Content-only widget (header + pill switcher live in [HomeScreen]).
/// An event has a defined time interval — never confuse with a task, which
/// is an action to complete. Inline "+ Create event" CTA only.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _teal = Color(0xFF0C6B6B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planner = AppScope.of(context).planner;
      if (planner.events.isEmpty && !planner.loading) {
        planner.loadEvents();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        return RefreshIndicator(
          color: _teal,
          onRefresh: planner.loadEvents,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context, planner)),
              _bodySliver(context, planner),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, PlannerController planner) {
    final visible = _visibleEvents(planner);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Events',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828))),
                Text(
                  visible.isEmpty
                      ? 'Scheduled commitments'
                      : '${visible.length} upcoming',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openForm(context, planner),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create event'),
          ),
        ],
      ),
    );
  }

  Widget _bodySliver(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.events.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }
    if (planner.error != null && planner.events.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child:
            ErrorRetry(message: planner.error!, onRetry: planner.loadEvents),
      );
    }
    final visible = _visibleEvents(planner);
    if (visible.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(context, planner));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding:
              EdgeInsets.fromLTRB(16, index == 0 ? 12 : 8, 16, 0),
          child: EventCard(
            event: visible[index],
            onEdit: () =>
                _openForm(context, planner, event: visible[index]),
            onDelete: () => _confirm(
              context,
              'Delete "${visible[index].title}"?',
              () => planner.deleteEvent(visible[index].id),
            ),
            onToggleComplete: visible[index].status == EventStatus.cancelled
                ? null
                : () => visible[index].status == EventStatus.completed
                    ? planner.reopenEvent(visible[index].id)
                    : planner.completeEvent(visible[index].id),
            onCancel: visible[index].status == EventStatus.scheduled
                ? () => planner.cancelEvent(visible[index].id)
                : null,
          ),
        ),
        childCount: visible.length,
      ),
    );
  }

  List<PlannerEvent> _visibleEvents(PlannerController planner) {
    final q = planner.searchQuery.trim().toLowerCase();
    final sorted = List<PlannerEvent>.from(planner.events)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (q.isEmpty) return sorted;
    return sorted
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            (e.description?.toLowerCase().contains(q) ?? false) ||
            (e.location?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  Widget _emptyState(BuildContext context, PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1E0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_outlined,
                  size: 30, color: Color(0xFFB54708)),
            ),
            const SizedBox(height: 12),
            const Text('No upcoming events',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Keep appointments and commitments in one place.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085))),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () => _openForm(context, planner),
              icon: const Icon(Icons.add),
              label: const Text('Create event'),
            ),
          ],
        ),
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
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(event == null ? 'Event created' : 'Event updated')),
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) {
      action();
    }
  }
}
