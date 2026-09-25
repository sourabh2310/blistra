/// Customize Navigation: choose + reorder bottom-navigation destinations.
///
/// HOME and ADD are locked. At most 5 total destinations. Hub stays reachable
/// even when unpinned because Home always links it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../preferences_controller.dart';
import '../shell_destinations.dart';

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
    final saving = context.watch<PreferencesController>().saving;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: const Text('Customize Navigation'),
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
              'Choose what appears in your navigation. Drag to reorder.',
              style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('PINNED',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF667085))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pinned.length,
                  onReorder: (oldIndex, newIndex) {
                    final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
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
                    return Card(
                      key: ValueKey(id),
                      child: ListTile(
                        leading: Icon(
                          ShellDestinations.icon(id),
                          color: const Color(0xFF0C6B6B),
                        ),
                        title: Text(
                            '${index + 1}. ${ShellDestinations.label(id)}'),
                        subtitle: locked
                            ? const Text('Locked')
                            : null,
                        trailing: locked
                            ? const Icon(Icons.lock_outline, size: 20)
                            : IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => setState(
                                    () => _pinned.remove(id)),
                              ),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 4),
                  child: Text('AVAILABLE',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF667085))),
                ),
                if (_available.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('Everything is pinned'),
                      subtitle: Text(
                          'Remove a destination to add a different one.'),
                    ),
                  ),
                for (final id in _available)
                  Card(
                    child: ListTile(
                      leading: Icon(ShellDestinations.icon(id)),
                      title: Text(ShellDestinations.label(id)),
                      trailing: IconButton(
                        tooltip: 'Add',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _full
                            ? null
                            : () => setState(() => _pinned.add(id)),
                      ),
                    ),
                  ),
                if (_full)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Maximum 5 destinations. Remove one to add another.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF667085)),
                    ),
                  ),
              ],
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
