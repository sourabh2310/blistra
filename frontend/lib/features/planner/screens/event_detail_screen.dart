import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../formats.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../planner_controller.dart';
import '../widgets/status_views.dart';
import 'event_form_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.planner,
    required this.eventId,
  });

  final PlannerController planner;
  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  PlannerEvent? _event;
  String? _error;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final event = await widget.planner.loadEvent(widget.eventId);
      if (mounted) setState(() => _event = event);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't load this event.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdit() async {
    final event = _event;
    if (event == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(planner: widget.planner, event: event),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _setStatus() async {
    final event = _event;
    if (event == null) return;
    setState(() => _working = true);
    try {
      if (event.status == EventStatus.completed || event.status == EventStatus.cancelled) {
        await widget.planner.reopenEvent(event.id);
      } else {
        await widget.planner.completeEvent(event.id);
      }
      await _load();
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't update this event.", error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel() async {
    final event = _event;
    if (event == null) return;
    setState(() => _working = true);
    try {
      await widget.planner.cancelEvent(event.id);
      await _load();
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't cancel this event.", error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete() async {
    final event = _event;
    if (event == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this event?',
      message: 'This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.planner.deleteEvent(event.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't delete this event.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        actions: [
          TextButton(
            onPressed: event == null || _loading ? null : _openEdit,
            child: const Text('Edit'),
          ),
        ],
      ),
      body: _loading && event == null
          ? const SkeletonLoader(rows: 4)
          : _error != null && event == null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : event == null
                  ? const SizedBox.shrink()
                  : _body(context, event),
    );
  }

  Widget _body(BuildContext context, PlannerEvent event) {
    final theme = Theme.of(context);
    final status = switch (event.status) {
      EventStatus.completed => 'Completed',
      EventStatus.cancelled => 'Cancelled',
      EventStatus.scheduled => 'Scheduled',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: event.status == EventStatus.cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusChip(label: status, color: theme.colorScheme.primary, icon: Icons.event),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(Formats.eventRangeLabel(event), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text('Scheduled activity', style: theme.textTheme.bodyMedium),
              if (event.location?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.lg),
                _EventLine(icon: Icons.location_on_outlined, value: event.location!),
              ],
              if (event.description?.isNotEmpty == true) ...[
                const Divider(height: AppSpacing.xxl),
                Text(event.description!, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _working ? null : _setStatus,
          icon: _working
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(event.status == EventStatus.completed || event.status == EventStatus.cancelled ? Icons.replay : Icons.check),
          label: Text(event.status == EventStatus.completed || event.status == EventStatus.cancelled ? 'Reopen event' : 'Complete event'),
        ),
        if (event.status == EventStatus.scheduled)
          TextButton.icon(
            onPressed: _working ? null : _cancel,
            icon: const Icon(Icons.block),
            label: const Text('Cancel event'),
          ),
        TextButton.icon(
          onPressed: _working ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete event'),
        ),
      ],
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(value)),
      ],
    );
  }
}
