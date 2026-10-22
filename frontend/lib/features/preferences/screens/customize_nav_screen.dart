/// Customize Navigation: choose + reorder bottom-navigation destinations.
///
/// HOME and ADD are locked. At most 5 total destinations. Hub stays reachable
/// even when unpinned because Home always links it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../preferences_controller.dart';
import '../shell_destinations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';

class CustomizeNavScreen extends StatefulWidget {
  const CustomizeNavScreen({super.key});

  @override
  State<CustomizeNavScreen> createState() => _CustomizeNavScreenState();
}

class _CustomizeNavScreenState extends State<CustomizeNavScreen> {
  late List<String> _pinned;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _pinned = List.of(context.read<PreferencesController>().bottomNav);
      _initialized = true;
    }
  }

  List<String> get _available => ShellDestinations.allowed
      .where((id) =>
          id != ShellDestinations.home &&
          id != ShellDestinations.add &&
          !_pinned.contains(id))
      .toList();

  bool get _full => _pinned.length >= ShellDestinations.maxItems;

  Future<void> _save() async {
    final controller = context.read<PreferencesController>();
    final ok = await controller.save(
      bottomNav: _pinned,
      homeWidgets: controller.homeWidgets,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok
              ? 'Navigation updated'
              : (controller.error ?? 'Save failed'))),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset navigation?'),
        content: const Text(
            'Restore the default bottom navigation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final controller = context.read<PreferencesController>();
    final ok = await controller.save(
      bottomNav: ShellDestinations.defaults,
      homeWidgets: controller.homeWidgets,
    );
    if (!mounted) return;
    if (ok) setState(() => _pinned = List.of(ShellDestinations.defaults));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Navigation reset' : controller.error ?? 'Reset failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final saving = context.watch<PreferencesController>().saving;
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: StickyActionBar(
        label: 'Save',
        busy: saving,
        onPressed: _save,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BlistraPageHeader(
              eyebrow: 'Customize',
              title: 'Navigation',
              subtitle: 'Choose what appears in your navigation. Drag to reorder.',
              showAvatar: false,
              actions: [
                GlassIconButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Reset',
                  onTap: saving ? null : _reset,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Pinned'),
            PagePad(
              GlassCard(
                radius: 22,
                padding: EdgeInsets.zero,
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pinned.length,
                  onReorderItem: (oldIndex, targetIndex) {
                    final moving = _pinned[oldIndex];
                    final target = _pinned[targetIndex];
                    if (moving == ShellDestinations.home ||
                        moving == ShellDestinations.add ||
                        target == ShellDestinations.home ||
                        target == ShellDestinations.add) {
                      return;
                    }
                    setState(() {
                      final id = _pinned.removeAt(oldIndex);
                      _pinned.insert(targetIndex, id);
                    });
                  },
                  itemBuilder: (context, index) {
                    final id = _pinned[index];
                    final locked = id == ShellDestinations.home ||
                        id == ShellDestinations.add;
                    return DecoratedBox(
                      key: ValueKey(id),
                      decoration: BoxDecoration(
                        border: index == 0
                            ? null
                            : Border(top: BorderSide(color: colors.inkAt(0.08))),
                      ),
                      child: GlassRow(
                        leading: IconWell(
                          ShellDestinations.icon(id),
                          color: colors.accentText,
                        ),
                        title: '${index + 1}. ${ShellDestinations.label(id)}',
                        subtitle: locked ? 'Locked' : null,
                        trailing: locked
                            ? Icon(Icons.lock_outline, size: 18, color: colors.muted)
                            : IconButton(
                                tooltip: 'Remove',
                                icon: Icon(Icons.remove_circle_outline,
                                    color: colors.muted),
                                onPressed: () => setState(
                                    () => _pinned.remove(id)),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Available'),
            PagePad(
              _available.isEmpty
                  ? const EmptyCard(
                      message: 'Everything is pinned. Remove a destination '
                          'to add a different one.',
                    )
                  : GlassList(
                      children: [
                        for (final id in _available)
                          GlassRow(
                            leading: IconWell(ShellDestinations.icon(id)),
                            title: ShellDestinations.label(id),
                            trailing: IconButton(
                              tooltip: 'Add',
                              icon: Icon(Icons.add_circle_outline,
                                  color: _full ? colors.muted : colors.accentText),
                              onPressed: _full
                                  ? null
                                  : () => setState(() => _pinned.add(id)),
                            ),
                          ),
                      ],
                    ),
            ),
            if (_full)
              PagePad(
                top: 10,
                Text(
                  'Maximum 5 destinations. Remove one to add another.',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
