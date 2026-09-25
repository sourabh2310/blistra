/// Paginated dose history page with edit/delete.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../data/medicines_api_client.dart';
import '../models/dose_record.dart';
import '../models/medicine_enums.dart';
import '../util/home_refresh.dart';

class DoseHistoryPage extends StatefulWidget {
  const DoseHistoryPage({super.key, required this.medicineId});

  final String medicineId;

  @override
  State<DoseHistoryPage> createState() => _DoseHistoryPageState();
}

class _DoseHistoryPageState extends State<DoseHistoryPage> {
  MedicinesApiClient? _api;
  List<DoseRecord> _doses = [];
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _page = 0;
  static const int _pageSize = 50;
  bool _hasMore = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      final authState = context.read<AuthState>();
      _api = MedicinesApiClient(
        tokenProvider: () => authState.apiClient.token ?? '',
        onUnauthorized: () => authState.handleUnauthorized(),
      );
      _loadFirstPage();
    }
  }

  Future<void> _loadFirstPage() async {
    _loading = true;
    _error = null;
    _page = 0;
    _hasMore = true;
    if (mounted) setState(() {});
    try {
      final page = await _api!.listDoses(widget.medicineId, page: 0, size: _pageSize);
      _doses = page.content;
      _hasMore = !page.last;
    } on Object catch (e) {
      _error = e;
      _doses.clear();
    } finally {
      _loading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _api == null) return;
    _loadingMore = true;
    if (mounted) setState(() {});
    try {
      final page = await _api!.listDoses(widget.medicineId, page: _page + 1, size: _pageSize);
      _doses.addAll(page.content);
      _page = page.last ? _page : _page + 1;
      _hasMore = !page.last;
    } catch (_) {
      // Ignore errors for load more
    } finally {
      _loadingMore = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dose History')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _doses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _doses.isEmpty) {
      return _ErrorRetry(
        message: _error.toString(),
        onRetry: _loadFirstPage,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        itemCount: _doses.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _doses.length) {
            if (_hasMore) {
              _loadMore();
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          final dose = _doses[index];
          final bool showHeader = index == 0 ||
              !_sameDay(_doses[index - 1].scheduledAt, dose.scheduledAt);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    _dayLabel(dose.scheduledAt),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              _DoseTile(
                dose: dose,
                onEdit: () => _editDose(dose),
                onDelete: () => _deleteDose(dose),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime day) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime that = DateTime(day.year, day.month, day.day);
    if (that == today) {
      return 'Today';
    }
    if (that == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('dd MMM yyyy').format(day);
  }

  Future<void> _editDose(DoseRecord dose) async {
    final status = await showDialog<DoseStatus>(
          context: context,
          builder: (_) => _DoseStatusDialog(initialStatus: dose.status),
        );
    if (status != null && mounted && _api != null) {
      try {
        await _api!.updateDose(widget.medicineId, dose.id, {'status': status.name.toUpperCase()});
        await _loadFirstPage();
        if (mounted) {
          await refreshHomeDashboard(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteDose(DoseRecord dose) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete dose record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok && mounted && _api != null) {
      try {
        await _api!.deleteDose(widget.medicineId, dose.id);
        await _loadFirstPage();
        if (mounted) {
          await refreshHomeDashboard(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({
    required this.dose,
    required this.onEdit,
    required this.onDelete,
  });

  final DoseRecord dose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(
          _doseStatusIcon(dose.status),
          color: _doseStatusColor(dose.status),
        ),
        title: Text(_doseStatusLabel(dose.status)),
        subtitle: Text(_fmtDateTime(dose.scheduledAt)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit status')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseStatusDialog extends StatefulWidget {
  const _DoseStatusDialog({required this.initialStatus});

  final DoseStatus initialStatus;

  @override
  State<_DoseStatusDialog> createState() => _DoseStatusDialogState();
}

class _DoseStatusDialogState extends State<_DoseStatusDialog> {
  late DoseStatus _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change dose status'),
      content: RadioGroup<DoseStatus>(
        groupValue: _selected,
        onChanged: (v) {
          if (v != null) setState(() => _selected = v);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: DoseStatus.values
              .map(
                (s) => RadioListTile<DoseStatus>(
                  title: Text(s.name.toUpperCase()),
                  value: s,
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Color _doseStatusColor(DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return Colors.green;
    case DoseStatus.missed:
      return Colors.red;
    case DoseStatus.skipped:
      return Colors.orange;
  }
}

IconData _doseStatusIcon(DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return Icons.check_circle;
    case DoseStatus.missed:
      return Icons.remove_circle_outline;
    case DoseStatus.skipped:
      return Icons.help_outline;
  }
}

String _doseStatusLabel(DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return 'Taken';
    case DoseStatus.missed:
      return 'Missed';
    case DoseStatus.skipped:
      return 'Skipped';
  }
}