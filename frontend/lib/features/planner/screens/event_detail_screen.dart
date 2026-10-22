import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../formats.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../planner_controller.dart';
import '../widgets/event_card.dart';
import '../widgets/planner_parts.dart';
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
    final settled = event != null && event.status != EventStatus.scheduled;
    return Scaffold(
      bottomNavigationBar: event == null
          ? null
          : StickyActionBar(
              label: settled ? 'Reopen event' : 'Complete event',
              busy: _working,
              onPressed: _setStatus,
            ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BlistraPageHeader(
              eyebrow: 'Event',
              title: event?.title ?? 'Event details',
              subtitle: event == null ? null : 'Scheduled activity · ${_status(event)}',
              showAvatar: false,
              actions: [
                GlassIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit event',
                  onTap: event == null || _loading ? null : _openEdit,
                ),
                PopupMenuButton<_EventAction>(
                  tooltip: 'More event actions',
                  enabled: event != null && !_working,
                  onSelected: (action) => action == _EventAction.cancel ? _cancel() : _delete(),
                  itemBuilder: (context) => [
                    if (event?.status == EventStatus.scheduled)
                      const PopupMenuItem(value: _EventAction.cancel, child: Text('Cancel event')),
                    PopupMenuItem(
                      value: _EventAction.delete,
                      child: Text('Delete event', style: TextStyle(color: BlistraColors.resolve(context).danger)),
                    ),
                  ],
                  child: const IgnorePointer(
                    child: GlassIconButton(icon: Icons.more_horiz, tooltip: null, onTap: null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && event == null)
              const SkeletonLoader(rows: 4, rowHeight: 64)
            else if (_error != null && event == null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (event != null)
              ..._body(context, event),
          ],
        ),
      ),
    );
  }

  String _status(PlannerEvent event) => switch (event.status) {
        EventStatus.completed => 'Completed',
        EventStatus.cancelled => 'Cancelled',
        EventStatus.scheduled => 'Scheduled',
      };

  String _length(DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) return '—';
    final hours = minutes ~/ 60;
    final rest = minutes.remainder(60);
    if (hours == 0) return '${rest}m';
    if (rest == 0) return '${hours}h';
    return '${hours}h ${rest}m';
  }

  List<Widget> _body(BuildContext context, PlannerEvent event) {
    final colors = BlistraColors.resolve(context);
    final start = event.startAt.toLocal();
    final end = event.endAt.toLocal();
    return [
      StatStrip(stats: [
        StatData(
          label: 'Starts',
          value: Formats.timeOfDay(start),
          sub: PlannerDates.relative(start),
          icon: Icons.play_arrow_rounded,
        ),
        StatData(
          label: 'Ends',
          value: Formats.timeOfDay(end),
          sub: PlannerDates.relative(end),
          icon: Icons.stop_rounded,
        ),
        StatData(
          label: 'Length',
          value: _length(start, end),
          icon: Icons.timelapse_rounded,
        ),
      ]),
      const SizedBox(height: 22),
      const SectionHeader(title: 'Details'),
      PagePad(
        GlassList(children: [
          GlassRow(
            leading: IconWell(Icons.event_outlined, color: plannerEventColor(colors)),
            title: Formats.eventRangeLabel(event),
            subtitle: 'When',
          ),
          if (event.location?.isNotEmpty == true)
            GlassRow(
              leading: const IconWell(Icons.location_on_outlined),
              title: event.location!,
              subtitle: 'Location',
            ),
          GlassRow(
            leading: IconWell(
              event.status == EventStatus.scheduled ? Icons.schedule_rounded : Icons.event_available_outlined,
              color: event.status == EventStatus.cancelled ? colors.danger : colors.accentText,
            ),
            title: _status(event),
            subtitle: 'Status',
          ),
        ]),
      ),
      if (event.description?.isNotEmpty == true) ...[
        const SizedBox(height: 22),
        const SectionHeader(title: 'Notes'),
        PagePad(
          GlassCard(
            padding: const EdgeInsets.all(15),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                event.description!,
                style: TextStyle(fontSize: 13.5, height: 1.45, color: colors.text),
              ),
            ),
          ),
        ),
      ],
    ];
  }
}

enum _EventAction { cancel, delete }
