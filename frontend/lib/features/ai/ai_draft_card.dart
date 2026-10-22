import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/glass.dart';
import 'ai_api.dart';
import 'ai_draft.dart';
import 'ai_entry_editor.dart';

class AiDraftCard extends StatefulWidget {
  const AiDraftCard({
    super.key,
    required this.api,
    required this.draft,
    required this.busy,
    required this.onApprove,
    required this.onEdit,
    required this.onCancel,
    this.onView,
  });
  final AiApi api;
  final AiDraft draft;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback? onView;
  @override
  State<AiDraftCard> createState() => _AiDraftCardState();
}

class _AiDraftCardState extends State<AiDraftCard> {
  bool _reviewed = false;
  final Map<String, String> _referenceNames = {};
  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void didUpdateWidget(AiDraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.revision != widget.draft.revision ||
        oldWidget.draft.id != widget.draft.id) {
      _reviewed = false;
      _referenceNames.clear();
      _loadLabels();
    }
  }

  Future<void> _loadLabels() async {
    final current = widget.draft;
    final paths = <String>{};
    void collect(Map<String, dynamic> field, Object? value) {
      if (value == null) return;
      final reference = AiApi.referencePath(field, current.data);
      if (reference.isNotEmpty) {
        paths.add(reference);
      }
      for (final child in field['fields'] as List? ?? []) {
        if (value is Map) {
          collect(
            Map<String, dynamic>.from(child as Map),
            value[child['name']],
          );
        }
      }
      if (field['item'] is Map) {
        if (value is List) {
          for (final item in value) {
            collect(Map<String, dynamic>.from(field['item'] as Map), item);
          }
        }
      }
    }

    for (final field in current.fields) {
      collect(field, current.data[field['name']]);
    }
    for (final path in paths) {
      try {
        final options = await widget.api.options(path);
        if (!mounted ||
            current.id != widget.draft.id ||
            current.revision != widget.draft.revision) {
          return;
        }
        setState(() {
          for (final option in options) {
            _referenceNames[option['id']!] = option['label']!;
          }
        });
      } catch (_) {
        /* Unresolved references stay visible and require editing. */
      }
    }
  }

  String _display(Object? value, Map<String, dynamic> field) {
    if (value == null) return 'Not supplied — module default';
    if (field['type'] == 'reference') {
      return _referenceNames[value.toString()] ??
          'Selection needs review in Edit';
    }
    if (value is List) {
      return value
          .map(
            (v) => _display(
              v,
              Map<String, dynamic>.from(field['item'] as Map? ?? {}),
            ),
          )
          .join('; ');
    }
    if (value is Map) {
      return (field['fields'] as List? ?? [])
          .where((f) => value[f['name']] != null)
          .map(
            (f) =>
                '${f['label']}: ${_display(value[f['name']], Map<String, dynamic>.from(f as Map))}',
          )
          .join(', ');
    }
    return fieldValue(value, field);
  }

  bool _resolved(Object? value, Map<String, dynamic> field) {
    if (value == null) return true;
    if (field['type'] == 'reference') {
      return _referenceNames.containsKey(value.toString());
    }
    if (value is List) {
      return value.every(
        (v) => _resolved(
          v,
          Map<String, dynamic>.from(field['item'] as Map? ?? {}),
        ),
      );
    }
    if (value is Map) {
      return (field['fields'] as List? ?? []).every(
        (f) => _resolved(value[f['name']], Map<String, dynamic>.from(f as Map)),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final receipt = draft.json['result'];
    final displayed = draft.state == 'APPLIED' && receipt is Map
        ? {...draft.data, ...Map<String, dynamic>.from(receipt)}
        : draft.data;
    final resolved = draft.fields.every(
      (f) => _resolved(draft.data[f['name']], f),
    );
    final colors = BlistraColors.resolve(context);
    final body = TextStyle(fontSize: 13, height: 1.45, color: colors.text);
    final note = TextStyle(fontSize: 11.5, height: 1.45, color: colors.muted);
    return GlassCard(
      radius: 22,
      tint: colors.accent,
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle.merge(
        style: body,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DESTINATION · ${draft.module}'.toUpperCase(),
              style: BlistraText.eyebrow(colors.accentText),
            ),
            const SizedBox(height: 6),
            Text(
              '${draft.state == 'APPLIED' ? 'Saved' : 'Review'}: ${draft.label}',
              style: BlistraText.serif(19, colors.text),
            ),
            const SizedBox(height: 6),
            Text(draft.effect, style: note),
            const SizedBox(height: 12),
            for (final f in draft.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${f['label']}: ${_display(displayed[f['name']], f)}',
                ),
              ),
            for (final error in draft.errors.values)
              Text(error.toString(), style: TextStyle(color: colors.danger)),
            if (draft.state == 'APPLIED')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Saved successfully. This approval cannot create another copy.',
                  style: TextStyle(
                    color: colors.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (draft.state == 'APPLIED' && widget.onView != null)
              OutlinedButton(
                onPressed: widget.onView,
                child: Text('View in ${draft.module}'),
              ),
            if (draft.state == 'PENDING' && draft.expired)
              Text(
                'This draft expired. Ask Blistra AI to prepare a new one.',
                style: TextStyle(color: colors.warning),
              ),
            if (draft.pending) ...[
              Text(
                'Blistra timezone: ${draft.timezone}. Review user-provided values and any module defaults. Live business rules are checked again when saving.',
                style: note,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _reviewed,
                title: const Text(
                  'I checked every field and confirm these are the details I want saved.',
                ),
                onChanged: widget.busy
                    ? null
                    : (value) => setState(() => _reviewed = value ?? false),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        !widget.busy && draft.ready && resolved && _reviewed
                        ? widget.onApprove
                        : null,
                    child: const Text('Approve and add'),
                  ),
                  OutlinedButton(
                    onPressed: widget.busy ? null : widget.onEdit,
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : widget.onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
