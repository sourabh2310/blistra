import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: StickyActionBar(
        label: 'Save',
        busy: controller.saving,
        onPressed: _save,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BlistraPageHeader(
              eyebrow: 'Customize',
              title: 'Home',
              subtitle: 'Choose the Home sections and modules you want to see.',
              showAvatar: false,
              actions: [
                GlassIconButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Reset',
                  onTap: controller.saving ? null : _reset,
                ),
              ],
            ),
            PagePad(top: 14, _Preview(selected: _selected)),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Home sections'),
            PagePad(
              _ReorderCard(
                itemCount: _sections.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final value = _sections.removeAt(oldIndex);
                    _sections.insert(newIndex, value);
                  });
                },
                itemBuilder: (context, index) {
                  final id = _sections[index];
                  return _ReorderTile(
                    key: ValueKey('section-$id'),
                    first: index == 0,
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
            const SizedBox(height: 24),
            const SectionHeader(title: 'Modules'),
            PagePad(
              _ReorderCard(
                itemCount: _modules.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final value = _modules.removeAt(oldIndex);
                    _modules.insert(newIndex, value);
                  });
                },
                itemBuilder: (context, index) {
                  final id = _modules[index];
                  return _ReorderTile(
                    key: ValueKey('module-$id'),
                    first: index == 0,
                    label: HomeWidgets.label(id),
                    visible: !_hiddenModules.contains(id),
                    onToggle: () => setState(() {
                      if (_hiddenModules.contains(id)) {
                        _hiddenModules.remove(id);
                      } else {
                        _hiddenModules.add(id);
                      }
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.selected});
  final List<String> selected;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIVE PREVIEW', style: BlistraText.caption(colors.muted)),
          const SizedBox(height: 10),
          if (selected.isEmpty)
            Text('Select something to see it on Home.',
                style: TextStyle(fontSize: 12, color: colors.muted))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in selected) Pill(HomeWidgets.label(id)),
              ],
            ),
        ],
      ),
    );
  }
}

/// A glass card holding a shrink-wrapped reorderable list of rows.
class _ReorderCard extends StatelessWidget {
  const _ReorderCard({
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorderItem,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorderItem;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: itemCount,
        onReorderItem: onReorderItem,
        itemBuilder: (context, index) {
          final child = itemBuilder(context, index);
          return ReorderableDelayedDragStartListener(
            key: child.key,
            index: index,
            child: child,
          );
        },
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
    this.first = false,
  });

  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final bool locked;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(top: BorderSide(color: colors.inkAt(0.08))),
      ),
      child: GlassRow(
        leading: Icon(Icons.drag_indicator_rounded, size: 20, color: colors.muted),
        title: label,
        subtitle: locked ? 'Shown while modules are visible' : null,
        trailing: locked
            ? Icon(Icons.lock_outline, size: 18, color: colors.muted)
            : Switch(value: visible, onChanged: (_) => onToggle()),
        onTap: locked ? null : onToggle,
      ),
    );
  }
}
