import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
import '../formats.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/task_priority.dart';
import '../models/task_reminder_mode.dart';
import '../planner_controller.dart';
import '../widgets/planner_parts.dart';

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
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '')
      ..addListener(() => setState(() {}));
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
    if (widget.planner.taskLists.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.planner.loadTaskLists());
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
    final colors = BlistraColors.resolve(context);
    final now = DateTime.now();
    final quickDates = [
      ('Today', now),
      ('Tomorrow', now.add(const Duration(days: 1))),
      ('This weekend', _nextWeekend()),
      ('Next week', _nextWeek()),
    ];
    final quickIndex = quickDates.indexWhere((entry) => _isSameDay(_date, entry.$2));
    final reminderModes = [
      TaskReminderMode.none,
      if (_start != null) TaskReminderMode.atStart,
      if (_end != null) TaskReminderMode.atEnd,
      if (_start != null && _end != null) TaskReminderMode.atStartAndEnd,
    ];
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        bottomNavigationBar: StickyActionBar(
          label: _isEditing ? 'Save changes' : 'Create task',
          busy: _saving,
          onPressed: _title.text.trim().isEmpty ? null : _save,
        ),
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                BlistraPageHeader(
                  eyebrow: _isEditing ? 'Edit task' : 'New task',
                  title: _isEditing ? 'Update this task' : 'What needs doing?',
                  showAvatar: false,
                ),
                PagePad(
                  PlannerTextField(
                    label: 'Title',
                    controller: _title,
                    hint: 'Finish project report',
                    autofocus: !_isEditing,
                    large: true,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Give your task a name.'
                        : null,
                  ),
                  top: 14,
                ),
                PagePad(
                  PickerField(
                    label: 'When',
                    value: _whenLabel,
                    placeholder: _date == null,
                    onTap: _saving ? null : _pickDate,
                  ),
                ),
                ChipRow(
                  labels: [for (final entry in quickDates) entry.$1],
                  selected: quickIndex < 0 ? null : quickIndex,
                  onSelected: (index) => _setQuickDate(quickDates[index].$2),
                ),
                const SizedBox(height: 12),
                PagePad(
                  Row(
                    children: [
                      Expanded(
                        child: PickerField(
                          label: 'Start',
                          value: _start?.format(context) ?? 'Start time',
                          placeholder: _start == null,
                          onTap: _date == null ? null : () => _pickTime(start: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PickerField(
                          label: 'End',
                          value: _end?.format(context) ?? 'End time',
                          placeholder: _end == null,
                          onTap: _date == null || _start == null ? null : () => _pickTime(start: false),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_start == null)
                  PagePad(
                    PickerField(
                      label: 'Due time',
                      value: _dueTime?.format(context) ?? 'Set due time',
                      placeholder: _dueTime == null,
                      onTap: _date == null ? null : _pickDueTime,
                    ),
                  ),
                if (_durationLabel.isNotEmpty ||
                    (_start != null && _end != null && _duration == null) ||
                    _date != null)
                  PagePad(
                    Row(
                      children: [
                        Expanded(
                          child: _start != null && _end != null && _duration == null
                              ? Text(
                                  'End time must be after the start time.',
                                  style: TextStyle(fontSize: 12, color: colors.danger),
                                )
                              : Text(
                                  _durationLabel.isEmpty ? '' : 'Duration  $_durationLabel',
                                  style: TextStyle(fontSize: 12, color: colors.muted),
                                ),
                        ),
                        if (_date != null)
                          Pill(
                            'No date',
                            color: colors.muted,
                            onTap: _saving
                                ? null
                                : () => setState(() {
                                      _date = null;
                                      _start = null;
                                      _end = null;
                                      _dueTime = null;
                                    }),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                PagePad(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FormCaption('Priority'),
                      GlassSegmented<TaskPriority>(
                        options: const [
                          (TaskPriority.low, 'Low'),
                          (TaskPriority.medium, 'Medium'),
                          (TaskPriority.high, 'High'),
                        ],
                        selected: _priority,
                        onChanged: (value) => setState(() => _priority = value),
                      ),
                      const SizedBox(height: 14),
                      ListenableBuilder(
                        listenable: planner,
                        builder: (context, _) => FieldCard(
                          label: 'List',
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _listId,
                              isDense: true,
                              isExpanded: true,
                              dropdownColor: colors.sheet,
                              icon: Icon(Icons.expand_more_rounded, color: colors.muted),
                              style: TextStyle(fontSize: 14, color: colors.text),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('No list')),
                                for (final list in _lists(planner.taskLists))
                                  DropdownMenuItem<String?>(value: list.id, child: Text(list.name)),
                              ],
                              onChanged: (value) => setState(() => _listId = value),
                            ),
                          ),
                        ),
                      ),
                      const FormCaption('Reminder'),
                    ],
                  ),
                ),
                if (reminderModes.length == 1)
                  PagePad(
                    Text(
                      'Add a start time to set a reminder.',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  )
                else
                  ChipRow(
                    labels: [for (final mode in reminderModes) mode.label],
                    selected: reminderModes.indexOf(_effectiveReminderMode),
                    onSelected: (index) => setState(() => _reminderMode = reminderModes[index]),
                  ),
                const SizedBox(height: 14),
                PagePad(
                  PlannerTextField(
                    label: 'Notes',
                    controller: _details,
                    hint: 'Add any context, notes or instructions...',
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                  ),
                ),
              ],
            ),
          ),
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
