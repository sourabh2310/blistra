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
import '../util/insights.dart';
import '../widgets/medicine_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';

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
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: _buildBody()),
    );
  }

  Widget _header() {
    final taken = _doses.where((d) => d.status == DoseStatus.taken).length;
    final adherence = adherenceOf(_doses);
    return BlistraPageHeader(
      eyebrow: 'Medicine',
      title: 'Dose history',
      showAvatar: false,
      subtitle: _doses.isEmpty
          ? 'Every recorded dose, newest first'
          : '$taken of ${_doses.length}${_hasMore ? '+' : ''} taken'
              '${adherence == null ? '' : ' · ${(adherence * 100).round()}%'}',
    );
  }

  Widget _buildBody() {
    if (_loading && _doses.isEmpty) {
      return Column(
        children: [
          _header(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }
    if (_error != null && _doses.isEmpty) {
      return ListView(
        children: [
          _header(),
          const SizedBox(height: 16),
          PagePad(UnavailableCard(name: 'Dose history', onRetry: _loadFirstPage)),
        ],
      );
    }

    // Consecutive doses on the same day share one glass list.
    final days = <List<DoseRecord>>[];
    for (final dose in _doses) {
      if (days.isEmpty || !_sameDay(days.last.first.scheduledAt, dose.scheduledAt)) {
        days.add([dose]);
      } else {
        days.last.add(dose);
      }
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: days.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                _header(),
                if (_doses.isEmpty)
                  const PagePad(
                    EmptyCard(message: 'No doses recorded yet.'),
                    top: 16,
                  ),
              ],
            );
          }
          if (index == days.length + 1) {
            if (_hasMore && _doses.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: BlistraColors.resolve(context).accentText,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          final day = days[index - 1];
          final taken = day.where((d) => d.status == DoseStatus.taken).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MedSection(
                title: _dayLabel(day.first.scheduledAt),
                actionLabel: '$taken of ${day.length} taken',
              ),
              PagePad(
                GlassList(
                  children: [
                    for (final dose in day)
                      DoseRecordRow(
                        dose: dose,
                        timeOnly: true,
                        onEdit: () => _editDose(dose),
                        onDelete: () => _deleteDose(dose),
                      ),
                  ],
                ),
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
          builder: (_) => DoseStatusDialog(initialStatus: dose.status),
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
    final ok = await confirmAction(
      context,
      title: 'Delete dose record?',
      message: '${doseStatusLabel(dose.status)} · ${relativeDateTime(dose.scheduledAt)}',
    );
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
