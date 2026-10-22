import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
import '../models/task_list.dart';
import '../planner_controller.dart';
import '../widgets/planner_parts.dart';

/// Task list form: create a new list (edit is handled via the rename sheet in
/// the Lists tab by reusing this screen).
class TaskListFormScreen extends StatefulWidget {
  const TaskListFormScreen({super.key, required this.planner, this.list});

  final PlannerController planner;
  final TaskList? list;

  @override
  State<TaskListFormScreen> createState() => _TaskListFormScreenState();
}

class _TaskListFormScreenState extends State<TaskListFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  bool _saving = false;

  bool get _isEditing => widget.list != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.list?.name ?? '')
      ..addListener(() => setState(() {}));
    _description = TextEditingController(text: widget.list?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
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
        await widget.planner.updateTaskList(
          widget.list!.id,
          name: _name.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        );
      } else {
        await widget.planner.createTaskList(
          name: _name.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
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
          const SnackBar(content: Text("Couldn't save this list. Try again.")),
        );
      }
    }
  }

  String _friendly(ApiException error) {
    if (error.fieldErrors.isNotEmpty) return error.fieldErrors.values.first;
    if (error.message == 'Request validation failed') {
      return "Couldn't save this list. Try again.";
    }
    return error.message.isEmpty ? "Couldn't save this list. Try again." : error.message;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        bottomNavigationBar: StickyActionBar(
          label: _isEditing ? 'Save changes' : 'Create list',
          busy: _saving,
          onPressed: _name.text.trim().isEmpty ? null : _save,
        ),
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 24),
              children: [
                BlistraPageHeader(
                  eyebrow: _isEditing ? 'Edit list' : 'New list',
                  title: _isEditing ? 'Rename this list' : 'What is this list for?',
                  showAvatar: false,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
                ),
                PlannerTextField(
                  label: 'Name',
                  controller: _name,
                  hint: 'Groceries',
                  large: true,
                  autofocus: !_isEditing,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Name is required' : null,
                ),
                PlannerTextField(
                  label: 'Description',
                  controller: _description,
                  hint: 'Optional',
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
