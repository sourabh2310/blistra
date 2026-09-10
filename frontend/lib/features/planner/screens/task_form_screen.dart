import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/api_exception.dart';
import '../formats.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/task_priority.dart';
import '../planner_controller.dart';

/// Create or edit a task. Editing re-submits every field (the backend PUT is a
/// full replacement), so the form is always pre-filled from the task.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, required this.planner, this.task});

  final PlannerController planner;
  final PlannerTask? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String? _listId;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  DateTime? _dueTime;
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    _listId = task?.taskListId;
    _priority = task?.priority ?? TaskPriority.medium;
    _dueDate = task?.dueDate;
    _dueTime = task?.dueTime;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.planner.updateTask(
          widget.task!.id,
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          dueTime: _dueTime,
          taskListId: _listId,
        );
      } else {
        await widget.planner.createTask(
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          priority: _priority,
          dueDate: _dueDate,
          dueTime: _dueTime,
          taskListId: _listId,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = widget.planner;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit task' : 'New task'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: planner,
              builder: (context, _) {
                return DropdownButtonFormField<String?>(
                  initialValue: _listId,
                  decoration: const InputDecoration(
                    labelText: 'List (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None')),
                    for (final list in _lists(planner.taskLists))
                      DropdownMenuItem<String?>(value: list.id, child: Text(list.name)),
                  ],
                  onChanged: (value) => setState(() => _listId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(
                  value: TaskPriority.low,
                  label: Text('Low'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: Text('Medium'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: TaskPriority.high,
                  label: Text('High'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (selection) =>
                  setState(() => _priority = selection.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDueDate(context),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(
                      _dueDate == null
                          ? 'Due date'
                          : '${Formats.date(_dueDate)} (${Formats.dayLabel(_dueDate).toLowerCase()})',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _dueDate == null ? null : () => _pickDueTime(context),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      _dueTime == null ? 'Time' : Formats.timeOfDay(_dueTime),
                    ),
                  ),
                ),
              ],
            ),
            if (_dueDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    _dueDate = null;
                    _dueTime = null;
                  }),
                  child: const Text('Clear due date'),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
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

  Future<void> _pickDueDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    setState(() => _dueDate = selected);
  }

  Future<void> _pickDueTime(BuildContext context) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueTime ?? DateTime.now()),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _dueTime = DateTime(2000, 1, 1, selected.hour, selected.minute);
    });
  }

  List<TaskList> _lists(List<TaskList> lists) {
    if (_isEditing && _listId != null) {
      if (!lists.any((l) => l.id == _listId)) {
        return [
          ...lists,
          TaskList(id: _listId!, name: widget.task!.taskListName ?? 'Unknown'),
        ];
      }
    }
    return lists;
  }
}