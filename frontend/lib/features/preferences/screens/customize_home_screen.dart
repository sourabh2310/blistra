/// Customize Home: show/hide + reorder Home widgets.
///
/// The Day-at-a-glance hero is locked (always first and visible). Changes
/// save to the per-user backend preferences; Reset restores Blistra defaults
/// after confirmation.
library;

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
  late List<String> _order;
  late Set<String> _hidden;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final prefs = context.read<PreferencesController>();
      _order = List.of(prefs.homeWidgets);
      // Hidden = allowed widgets absent from the saved order.
      _hidden = HomeWidgets.allowed
          .where((id) =>
              id != HomeWidgets.dayAtAGlance && !_order.contains(id))
          .toSet();
      for (final id in HomeWidgets.allowed) {
        if (id != HomeWidgets.dayAtAGlance && !_order.contains(id)) {
          _order.add(id);
        }
      }
      _initialized = true;
    }
  }

  List<String> get _visible =>
      _order.where((id) => !_hidden.contains(id)).toList();

  Future<void> _save() async {
    final controller = context.read<PreferencesController>();
    final ok = await controller.save(
      bottomNav: controller.bottomNav,
      homeWidgets: _visible,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              ok ? 'Home updated' : (controller.error ?? 'Save failed'))),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Home?'),
        content:
            const Text('Restore the default Home widget layout?'),
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
      bottomNav: controller.bottomNav,
      homeWidgets: List.of(HomeWidgets.defaults),
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _order = List.of(HomeWidgets.defaults);
        _hidden = {};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home reset to defaults')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.error ?? 'Reset failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<PreferencesController>().saving;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: const Text('Customize Home'),
        backgroundColor: const Color(0xFFFFFBF6),
        actions: [
          TextButton(onPressed: saving ? null : _reset, child: const Text('Reset')),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'Choose what appears on Home. Drag to reorder.',
              style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('YOUR HOME',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF667085))),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _order.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final id = _order.removeAt(oldIndex);
                  _order.insert(newIndex, id);
                });
              },
              itemBuilder: (context, index) {
                final id = _order[index];
                final locked = id == HomeWidgets.dayAtAGlance;
                final visible = !_hidden.contains(id);
                return Card(
                  key: ValueKey(id),
                  child: ListTile(
                    leading: locked
                        ? const Icon(Icons.lock_outline, size: 20)
                        : const Icon(Icons.drag_handle, size: 20),
                    title: Text(HomeWidgets.label(id)),
                    subtitle: locked
                        ? const Text('Always on Home')
                        : null,
                    trailing: locked
                        ? const Icon(Icons.check,
                            color: Color(0xFF0C6B6B))
                        : Switch(
                            value: visible,
                            onChanged: (value) => setState(() {
                              if (value) {
                                _hidden.remove(id);
                              } else {
                                _hidden.add(id);
                              }
                            }),
                          ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? 'Saving…' : 'Save'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
