import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import 'ai_api.dart';
import 'ai_draft.dart';

String fieldValue(Object? value, Map<String, dynamic> field) {
  if (value == null || value == '') return 'Not supplied';
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is List) {
    return value
        .map((v) => fieldValue(v, field['item'] as Map<String, dynamic>? ?? {}))
        .join('; ');
  }
  if (value is Map) {
    final children = field['fields'] as List? ?? [];
    return children
        .where((f) => value[f['name']] != null)
        .map(
          (f) =>
              '${f['label']}: ${fieldValue(value[f['name']], Map<String, dynamic>.from(f as Map))}',
        )
        .join(', ');
  }
  if (field['type'] == 'datetime') {
    final date = DateTime.tryParse(value.toString());
    if (date != null) {
      return '${DateFormat.yMMMd().add_jm().format(date.toLocal())} (device time; saved ${value.toString().replaceFirst('T', ' ')})';
    }
  }
  return value.toString().replaceAll('_', ' ');
}

class AiEntryEditor extends StatefulWidget {
  const AiEntryEditor({super.key, required this.api, required this.draft});
  final AiApi api;
  final AiDraft draft;
  @override
  State<AiEntryEditor> createState() => _AiEntryEditorState();
}

class _AiEntryEditorState extends State<AiEntryEditor> {
  late Map<String, dynamic> _data;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(widget.draft.data)) as Map,
    );
  }

  Future<void> _review() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.api.edit(widget.draft, _data);
      if (mounted) Navigator.of(context).pop(draft);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Could not validate this draft. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Edit ${widget.draft.label.toLowerCase()}')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Required fields are marked *. Optional fields may be left blank. Date/time pickers use your device timezone; your Blistra timezone is ${widget.draft.timezone}.',
          ),
          const SizedBox(height: 16),
          for (final field in widget.draft.fields)
            EntryField(
              key: ValueKey(field['name']),
              api: widget.api,
              field: field,
              contextValues: _data,
              value: _data[field['name']],
              enabled: !_busy,
              onChanged: (value) {
                setState(() {
                  if (value == null) {
                    _data.remove(field['name']);
                  } else {
                    _data[field['name'] as String] = value;
                  }
                });
              },
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _busy ? null : _review,
            child: Text(_busy ? 'Validating…' : 'Validate and review'),
          ),
          const Text(
            'This checks the draft. Nothing is saved until you approve the review card.',
          ),
        ],
      ),
    ),
  );
}

class EntryField extends StatefulWidget {
  const EntryField({
    super.key,
    required this.api,
    required this.field,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.contextValues = const {},
  });
  final AiApi api;
  final Map<String, dynamic> field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final bool enabled;
  final Map<String, dynamic> contextValues;
  @override
  State<EntryField> createState() => _EntryFieldState();
}

class _EntryFieldState extends State<EntryField> {
  late Object? _value;
  late TextEditingController _text;
  final List<Key> _itemKeys = [];
  String _reference = '';
  Future<List<Map<String, String>>>? _options;
  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _text = TextEditingController(text: _value?.toString() ?? '');
    _reference = AiApi.referencePath(widget.field, widget.contextValues);
    if (_reference.isNotEmpty) _options = widget.api.options(_reference);
  }

  @override
  void didUpdateWidget(EntryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = AiApi.referencePath(widget.field, widget.contextValues);
    if (path != _reference) {
      _reference = path;
      _options = path.isEmpty ? null : widget.api.options(path);
      if (_value != null) {
        _value = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onChanged(null);
        });
      }
    }
  }

  void _change(Object? value) {
    if (['text', 'number', 'integer'].contains(widget.field['type'])) {
      _text.text = value?.toString() ?? '';
    }
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String get _label =>
      '${widget.field['label']}${widget.field['required'] == true ? ' *' : ''}';

  Future<void> _pick() async {
    final type = widget.field['type'];
    final initial =
        DateTime.tryParse(_value?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    DateTime date = initial;
    if (type != 'time') {
      final firstDate = DateTime(1900);
      final lastDate = DateTime(2200);
      final pickerInitial = initial.isBefore(firstDate)
          ? firstDate
          : initial.isAfter(lastDate)
          ? lastDate
          : initial;
      final picked = await showDatePicker(
        context: context,
        initialDate: pickerInitial,
        firstDate: firstDate,
        lastDate: lastDate,
      );
      if (picked == null || !mounted) return;
      date = picked;
    }
    if (type == 'date') {
      _change(DateFormat('yyyy-MM-dd').format(date));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    if (type == 'time') {
      _change(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      );
      return;
    }
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Explicit offset preserves the device-time intent even when the profile zone differs.
    final minutes = selected.timeZoneOffset.inMinutes;
    final sign = minutes < 0 ? '-' : '+';
    final offset =
        '$sign${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
    _change('${DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(selected)}$offset');
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final type = f['type'] as String;
    Widget child;
    if (type == 'choice' || type == 'boolean') {
      final values = type == 'boolean'
          ? <Object>[true, false]
          : (f['choices'] as List).cast<Object>();
      child = DropdownButtonFormField<Object>(
        key: ValueKey('choice:$_value'),
        initialValue: values.contains(_value) ? _value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: _label),
        items: [
          for (final option in values)
            DropdownMenuItem(
              value: option,
              child: Text(
                option is bool
                    ? (option ? 'Yes' : 'No')
                    : option.toString().replaceAll('_', ' '),
              ),
            ),
        ],
        onChanged: widget.enabled ? _change : null,
      );
    } else if (type == 'reference') {
      child = FutureBuilder<List<Map<String, String>>>(
        future: _options,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load $_label. Check your connection and retry.',
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _options = widget.api.options(_reference);
                  }),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final options = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('reference:${options.length}:$_value'),
                initialValue: options.any((v) => v['id'] == _value)
                    ? _value as String?
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: _label),
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option['id'],
                      child: Text(option['label']!),
                    ),
                ],
                onChanged: widget.enabled ? _change : null,
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(),
              if (snapshot.connectionState == ConnectionState.done &&
                  options.isEmpty)
                const Text(
                  'No selectable records. Create the related entry in its module first.',
                ),
            ],
          );
        },
      );
    } else if (type == 'date' || type == 'time' || type == 'datetime') {
      child = ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_label),
        subtitle: Text(fieldValue(_value, f)),
        trailing: const Icon(Icons.calendar_today),
        onTap: widget.enabled ? _pick : null,
      );
    } else if (type == 'list') {
      final values = (_value as List? ?? []).toList();
      while (_itemKeys.length < values.length) {
        _itemKeys.add(UniqueKey());
      }
      final item = Map<String, dynamic>.from(f['item'] as Map);
      child = Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_label),
              for (var i = 0; i < values.length; i++)
                Row(
                  key: _itemKeys[i],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: EntryField(
                        api: widget.api,
                        contextValues: widget.contextValues,
                        field: {...item, 'label': '${item['label']} ${i + 1}'},
                        value: values[i],
                        enabled: widget.enabled,
                        onChanged: (value) {
                          values[i] = value;
                          _change(values);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove item',
                      onPressed: widget.enabled
                          ? () {
                              values.removeAt(i);
                              _itemKeys.removeAt(i);
                              _change(values);
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: widget.enabled && values.length < 50
                    ? () {
                        values.add(
                          item['type'] == 'object' ? <String, dynamic>{} : null,
                        );
                        _change(values);
                      }
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
        ),
      );
    } else if (type == 'object') {
      final data = Map<String, dynamic>.from(_value as Map? ?? {});
      child = Column(
        children: [
          for (final raw in f['fields'] as List)
            EntryField(
              key: ValueKey((raw as Map)['name']),
              api: widget.api,
              contextValues: widget.contextValues,
              field: Map<String, dynamic>.from(raw),
              value: data[raw['name']],
              enabled: widget.enabled,
              onChanged: (value) {
                if (value == null) {
                  data.remove(raw['name']);
                } else {
                  data[raw['name'] as String] = value;
                }
                _change(data);
              },
            ),
        ],
      );
    } else {
      child = TextFormField(
        controller: _text,
        enabled: widget.enabled,
        maxLength: f['maxLength'] as int?,
        decoration: InputDecoration(
          labelText: _label,
          helperText: (f['help'] as String? ?? '').isEmpty
              ? null
              : f['help'] as String,
          helperMaxLines: 4,
        ),
        keyboardType: type == 'number' || type == 'integer'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: (text) {
          Object? value = text.isEmpty ? null : text;
          if (type == 'number') value = num.tryParse(text) ?? value;
          if (type == 'integer') value = int.tryParse(text) ?? value;
          setState(() => _value = value);
          widget.onChanged(value);
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          if (_value != null && f['required'] != true)
            TextButton(
              onPressed: widget.enabled ? () => _change(null) : null,
              child: const Text('Leave unset'),
            ),
        ],
      ),
    );
  }
}
