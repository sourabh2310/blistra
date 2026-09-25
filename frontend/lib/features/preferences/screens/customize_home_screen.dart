import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../preferences_controller.dart';
import '../shell_destinations.dart';

class CustomizeHomeScreen extends StatefulWidget {
  const CustomizeHomeScreen({super.key});

  @override
  State<CustomizeHomeScreen> createState() => _CustomizeHomeScreenState();
}

class _CustomizeHomeScreenState extends State<CustomizeHomeScreen> {
  late List<String> _sections;
  late List<String> _modules;
  late Set<String> _hiddenSections;
  late Set<String> _hiddenModules;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final saved = context.read<PreferencesController>().homeWidgets;
    final normalized = saved.isEmpty
        ? HomeWidgets.defaults
        : HomeWidgets.normalizeWidgets(saved);
    _sections = [
      for (final id in normalized)
        if (HomeWidgets.sections.contains(id)) id,
      for (final id in HomeWidgets.sections)
        if (!normalized.contains(id)) id,
    ];
    _modules = [
      for (final id in normalized)
        if (HomeWidgets.modules.contains(id)) id,
      for (final id in HomeWidgets.modules)
        if (!normalized.contains(id)) id,
    ];
    _hiddenSections = HomeWidgets.sections
        .where((id) => !normalized.contains(id))
        .toSet();
    _hiddenModules = HomeWidgets.modules
        .where((id) => !normalized.contains(id))
        .toSet();
    _initialized = true;
  }

  List<String> get _visibleSections =>
      _sections.where((id) => !_hiddenSections.contains(id)).toList();

  List<String> get _visibleModules =>
      _modules.where((id) => !_hiddenModules.contains(id)).toList();

  List<String> get _selected => [
        ..._visibleSections,
        if (_visibleModules.isNotEmpty) HomeWidgets.yourLife,
        ..._visibleModules,
      ];

  Future<void> _save({bool close = true}) async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one Home section selected.')),
      );
      return;
    }
    final controller = context.read<PreferencesController>();
    final ok = await controller.save(
      bottomNav: controller.bottomNav,
      homeWidgets: _selected,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Home updated' : controller.error ?? 'Save failed')),
    );
    if (ok && close) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Home and navigation?'),
        content: const Text('Restore the default Home layout and navigation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = context.read<PreferencesController>();
    final ok = await controller.resetToDefaults();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _sections = List.of(HomeWidgets.sections);
        _modules = List.of(HomeWidgets.modules);
        _hiddenSections = {};
        _hiddenModules = {};
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Home and navigation reset' : controller.error ?? 'Reset failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreferencesController>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Home'),
        actions: [
          TextButton(
            onPressed: controller.saving ? null : _reset,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Choose the Home sections and modules you want to see.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 96,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Preview(selected: _selected),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('HOME SECTIONS', style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: _sections.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final value = _sections.removeAt(oldIndex);
                  _sections.insert(newIndex, value);
                });
              },
              itemBuilder: (context, index) {
                final id = _sections[index];
                return _ReorderTile(
                  key: ValueKey('section-$id'),
                  label: HomeWidgets.label(id),
                  visible: !_hiddenSections.contains(id),
                  locked: id == HomeWidgets.yourLife &&
                      _visibleModules.isNotEmpty,
                  onToggle: () => setState(() {
                    if (_hiddenSections.contains(id)) {
                      _hiddenSections.remove(id);
                    } else {
                      _hiddenSections.add(id);
                    }
                  }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('MODULES', style: theme.textTheme.labelLarge),
          ),
          SizedBox(
            height: 132,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _modules.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final value = _modules.removeAt(oldIndex);
                  _modules.insert(newIndex, value);
                });
              },
              itemBuilder: (context, index) {
                final id = _modules[index];
                return SizedBox(
                  width: 190,
                  child: _ReorderTile(
                    key: ValueKey('module-$id'),
                    label: HomeWidgets.label(id),
                    visible: !_hiddenModules.contains(id),
                    onToggle: () => setState(() {
                      if (_hiddenModules.contains(id)) {
                        _hiddenModules.remove(id);
                      } else {
                        _hiddenModules.add(id);
                      }
                    }),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.saving ? null : _save,
                      child: const Text('Done'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: controller.saving ? null : _save,
                      child: Text(controller.saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.selected});
  final List<String> selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live preview', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          if (selected.isEmpty)
            Text('Select something to see it on Home.',
                style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in selected)
                  Chip(label: Text(HomeWidgets.label(id))),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    super.key,
    required this.label,
    required this.visible,
    required this.onToggle,
    this.locked = false,
  });

  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.drag_handle),
        title: Text(label),
        trailing: locked
            ? const Icon(Icons.lock_outline, size: 20)
            : Switch(value: visible, onChanged: (_) => onToggle()),
        onTap: locked ? null : onToggle,
      ),
    );
  }
}
