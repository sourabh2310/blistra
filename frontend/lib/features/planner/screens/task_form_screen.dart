import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../formats.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/task_priority.dart';
import '../models/task_reminder_mode.dart';
import '../planner_controller.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.planner,
    this.task,
    this.initialListId,
  });

  final PlannerController planner;
  final PlannerTask? task;
  final String? initialListId;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _details;
  late String? _listId;
  late TaskPriority _priority;
  late TaskReminderMode _reminderMode;
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  TimeOfDay? _dueTime;
  bool _showMore = false;
  bool _showDetails = false;
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _details = TextEditingController(text: task?.description ?? '');
    _listId = task?.taskListId ?? widget.initialListId;
    _priority = task?.priority ?? TaskPriority.medium;
    _reminderMode = task?.reminderMode ?? TaskReminderMode.none;
    _date = task?.dueDate ?? task?.startAt?.toLocal();
    _start = task?.startAt == null
        ? null
        : TimeOfDay.fromDateTime(task!.startAt!.toLocal());
    _end = task?.endAt == null
        ? null
        : TimeOfDay.fromDateTime(task!.endAt!.toLocal());
    _dueTime = task?.dueTime == null
        ? null
        : TimeOfDay.fromDateTime(task!.dueTime!);
    _showDetails = (task?.description?.isNotEmpty ?? false);
    _showMore = _listId != null || _showDetails || _reminderMode != TaskReminderMode.none;
    if (widget.planner.taskLists.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => planner.loadTaskLists());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  DateTime? get _startAt => _combine(_start);
  DateTime? get _endAt => _combine(_end);
  DateTime? get _dueAt => _dueTime == null
      ? null
      : DateTime(2000, 1, 1, _dueTime!.hour, _dueTime!.minute);

  DateTime? _combine(TimeOfDay? time) {
    if (_date == null || time == null) return null;
    return DateTime(_date!.year, _date!.month, _date!.day, time.hour, time.minute);
  }

  Duration? get _duration {
    if (_startAt == null || _endAt == null || !_endAt!.isAfter(_startAt!)) return null;
    return _endAt!.difference(_startAt!);
  }

  String get _durationLabel {
    final duration = _duration;
    if (duration == null) return '';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  TaskReminderMode get _effectiveReminderMode {
    if ((_reminderMode == TaskReminderMode.atStart && _start == null) ||
        ((_reminderMode == TaskReminderMode.atEnd ||
                _reminderMode == TaskReminderMode.atStartAndEnd) &&
            _end == null)) {
      return TaskReminderMode.none;
    }
    return _reminderMode;
  }

  String get _whenLabel {
    if (_date == null) return 'No date';
    final day = Formats.dayLabel(_date);
    if (_start == null && _dueTime != null) {
      return '$day · Due ${_dueTime!.format(context)}';
    }
    if (_start == null) return '$day · No time scheduled';
    final start = _start!.format(context);
    if (_end == null) return '$day · $start';
    return '$day · $start – ${_end!.format(context)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start != null && _end != null && !_endAt!.isAfter(_startAt!)) {
      setState(() {});
      return;
    }
    if (_end != null && _start == null) {
      setState(() {});
      return;
    }
    if (_reminderMode != _effectiveReminderMode) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      final description = _details.text.trim().isEmpty ? null : _details.text.trim();
      if (_isEditing) {
        await widget.planner.updateTask(
          widget.task!.id,
          title: _title.text.trim(),
          description: description,
          priority: _priority,
          dueDate: _date,
          dueTime: _dueAt,
          startAt: _startAt,
          endAt: _endAt,
          reminderMode: _effectiveReminderMode,
          taskListId: _listId,
        );
      } else {
        await widget.planner.createTask(
          title: _title.text.trim(),
          description: description,
          priority: _priority,
          dueDate: _date,
          dueTime: _dueAt,
          startAt: _startAt,
          endAt: _endAt,
          reminderMode: _effectiveReminderMode,
          taskListId: _listId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendly(e))),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save this task. Try again.")),
        );
      }
    }
  }

  String _friendly(ApiException e) {
    if (e.fieldErrors.isNotEmpty) return e.fieldErrors.values.first;
    if (e.message == 'Request validation failed') {
      return "Couldn't save this task. Try again.";
    }
    return e.message.isEmpty ? "Couldn't save this task. Try again." : e.message;
  }

  void _setQuickDate(DateTime value) {
    setState(() => _date = DateTime(value.year, value.month, value.day));
  }

  bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _nextWeekend() {
    final now = DateTime.now();
    final daysUntilSaturday = (DateTime.saturday - now.weekday + 7) % 7;
    return DateTime(now.year, now.month, now.day + daysUntilSaturday);
  }

  DateTime _nextWeek() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    return DateTime(now.year, now.month, now.day + daysUntilMonday);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _start = picked;
          if (_end != null && _endAt != null && _startAt != null &&
              !_endAt!.isAfter(_startAt!)) {
            _end = TimeOfDay.fromDateTime(
              _startAt!.add(const Duration(hours: 1)),
            );
          }
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final planner = widget.planner;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_isEditing ? 'Edit task' : 'Create a task'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _SectionLabel('What needs to get done?'),
            TextFormField(
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Finish project report',
                filled: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Give your task a name.'
                  : null,
            ),
            const SizedBox(height: 28),
            const _SectionLabel('When?'),
            _SelectionCard(
              icon: Icons.calendar_today_outlined,
              label: _whenLabel,
              onTap: _pickDate,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _QuickDateChip(
                  label: 'Today',
                  selected: _isSameDay(_date, DateTime.now()),
                  onTap: () => _setQuickDate(DateTime.now()),
                ),
                _QuickDateChip(
                  label: 'Tomorrow',
                  selected: _isSameDay(
                      _date, DateTime.now().add(const Duration(days: 1))),
                  onTap: () => _setQuickDate(
                      DateTime.now().add(const Duration(days: 1))),
                ),
                _QuickDateChip(
                  label: 'This weekend',
                  selected: _isSameDay(_date, _nextWeekend()),
                  onTap: () => _setQuickDate(_nextWeekend()),
                ),
                _QuickDateChip(
                  label: 'Next week',
                  selected: _isSameDay(_date, _nextWeek()),
                  onTap: () => _setQuickDate(_nextWeek()),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _date == null ? null : () => _pickTime(start: true),
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: Text(_start?.format(context) ?? 'Start time'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _date == null || _start == null
                        ? null
                        : () => _pickTime(start: false),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(_end?.format(context) ?? 'End time'),
                  ),
                ),
              ],
            ),
            if (_start == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _date == null ? null : _pickDueTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(_dueTime?.format(context) ?? 'Set due time'),
                ),
              ),
            if (_durationLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text('Duration  $_durationLabel'),
              ),
            if (_start != null && _end != null && _duration == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'End time must be after the start time.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (_date != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                             _date = null;
                             _start = null;
                             _end = null;
                             _dueTime = null;
                          }),
                  child: const Text('No date'),
                ),
              ),
            const SizedBox(height: 20),
            const _SectionLabel('Priority'),
            _PriorityPicker(
              value: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 20),
            _MoreOptions(
              expanded: _showMore,
              onToggle: () => setState(() => _showMore = !_showMore),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExpandableRow(
                    icon: Icons.notes_outlined,
                    label: 'Details',
                    value: _showDetails ? 'Added' : 'Add details',
                    onTap: () => setState(() => _showDetails = !_showDetails),
                  ),
                  if (_showDetails)
                    TextFormField(
                      controller: _details,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Add any context, notes or instructions...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: planner,
                    builder: (context, _) => DropdownButtonFormField<String?>(
                      initialValue: _listId,
                      decoration: const InputDecoration(labelText: 'Organization'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('No list')),
                        for (final list in _lists(planner.taskLists))
                          DropdownMenuItem<String?>(
                              value: list.id, child: Text(list.name)),
                      ],
                      onChanged: (value) => setState(() => _listId = value),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel('Reminder'),
                  _ReminderPicker(
                    value: _effectiveReminderMode,
                    hasStart: _start != null,
                    hasEnd: _end != null,
                    onChanged: (value) => setState(() => _reminderMode = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEditing ? 'Save changes' : 'Create task'),
            ),
          ],
        ),
      ),
    );
  }

  List<TaskList> _lists(List<TaskList> lists) {
    if (_listId != null && !lists.any((list) => list.id == _listId)) {
      return [
        ...lists,
        TaskList(id: _listId!, name: widget.task?.taskListName ?? 'Current list', taskCount: 0),
      ];
    }
    return lists;
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      );
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});
  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: TaskPriority.values.map((priority) {
          final selected = priority == value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: priority == TaskPriority.high ? 0 : 8),
              child: InkWell(
                onTap: () => onChanged(priority),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(priority.wireName[0] + priority.wireName.substring(1).toLowerCase()),
                ),
              ),
            ),
          );
        }).toList(),
      );
}

class _MoreOptions extends StatelessWidget {
  const _MoreOptions({required this.expanded, required this.onToggle, required this.child});
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            ListTile(
              onTap: onToggle,
              leading: const Icon(Icons.tune_outlined),
              title: const Text('More options'),
              trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: child,
              ),
          ],
        ),
      );
}

class _ExpandableRow extends StatelessWidget {
  const _ExpandableRow({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value),
      );
}

class _ReminderPicker extends StatelessWidget {
  const _ReminderPicker({required this.value, required this.hasStart, required this.hasEnd, required this.onChanged});
  final TaskReminderMode value;
  final bool hasStart;
  final bool hasEnd;
  final ValueChanged<TaskReminderMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final modes = [
      TaskReminderMode.none,
      if (hasStart) TaskReminderMode.atStart,
      if (hasEnd) TaskReminderMode.atEnd,
      if (hasStart && hasEnd) TaskReminderMode.atStartAndEnd,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((mode) {
        final selected = mode == value;
        return ChoiceChip(
          label: Text(mode.label),
          selected: selected,
          onSelected: (_) => onChanged(mode),
        );
      }).toList(),
    );
  }
}
