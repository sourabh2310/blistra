import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/routing/routes.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/schedule.dart';
import '../models/today_doses.dart';
import '../state/medicine_list_controller.dart';
import '../state/medicine_overview_controller.dart';
import '../state/medicine_today_controller.dart';
import '../util/home_refresh.dart';
import '../util/insights.dart';
import '../widgets/medicine_widgets.dart';
import '../../notifications/screens/reminders_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../search/search_api.dart';
import 'dose_history_page.dart';
import 'medicine_detail_page.dart';
import 'medicine_form_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';

/// Medicines home: today's doses by part of day with Take / Skip on due
/// rows, a 7-day adherence / active / refills strip, and every medicine.
class MedicineListPage extends StatefulWidget {
  const MedicineListPage({super.key});

  @override
  State<MedicineListPage> createState() => _MedicineListPageState();
}

class _MedicineListPageState extends State<MedicineListPage> {
  MedicinesApiClient? _api;
  MedicineListController? _controller;
  MedicineTodayController? _today;
  MedicineOverviewController? _overview;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final authState = context.read<AuthState>();
      final api = MedicinesApiClient(
        tokenProvider: () => authState.apiClient.token ?? '',
        onUnauthorized: () => authState.handleUnauthorized(),
      );
      _api = api;
      _controller = MedicineListController(api)..addListener(_syncOverview);
      _today = MedicineTodayController(api);
      _overview = MedicineOverviewController(api);
      _controller!.refresh();
      _today!.refresh();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncOverview);
    _controller?.dispose();
    _today?.dispose();
    _overview?.dispose();
    super.dispose();
  }

  List<Medicine> get _active => [
        for (final m in _controller?.medicines ?? const <Medicine>[])
          if (m.status == MedicineStatus.active) m,
      ];

  /// Loads per-medicine schedules, doses and refills once the list settles.
  void _syncOverview({bool force = false}) {
    final controller = _controller;
    if (controller == null || controller.isLoading || controller.error != null) {
      return;
    }
    _overview?.load(_active, force: force);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final today = _today;
    final overview = _overview;
    if (controller == null || today == null || overview == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: Listenable.merge([controller, today, overview]),
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: SafeArea(
              top: true,
              bottom: false,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  BlistraPageHeader(
                    eyebrow: 'Medicines',
                    title: "Today's doses",
                    subtitle: _headline(today.today),
                    actions: [
                      GlassIconButton(
                        tooltip: 'Add a medicine',
                        icon: Icons.add_rounded,
                        onTap: _pushAdd,
                      ),
                      GlassMenuButton<String>(
                        items: const [
                          ('search', 'Search'),
                          ('reminders', 'Reminders'),
                          ('history', 'Dose history'),
                          ('summary', "Today's summary"),
                        ],
                        onSelected: _onMenu,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  StatStrip(stats: _stats(controller, today, overview)),
                  ..._todaySections(today),
                  MedSection(
                    title: 'My medicines',
                    actionLabel: 'All ›',
                    onAction: _pushAll,
                  ),
                  PagePad(_myMedicines(controller, overview)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _headline(MedicineToday? data) {
    if (data == null) return 'Loading today’s schedule…';
    if (data.isEmpty) return 'Nothing scheduled today';
    final base = '${data.takenDoses} of ${data.totalDoses} taken';
    final next = data.nextDose;
    if (next != null) {
      return '$base · next ${next.medicineName} at '
          '${DateFormat('h:mm a').format(next.scheduledAt)}';
    }
    return data.allCompleted ? '$base · all done' : base;
  }

  List<StatData> _stats(
    MedicineListController controller,
    MedicineTodayController today,
    MedicineOverviewController overview,
  ) {
    final colors = BlistraColors.resolve(context);
    final adherence = overview.weekAdherence;
    final listReady = !controller.isLoading && controller.error == null;
    final active = _active;

    final types = <ScheduleType, int>{};
    for (final m in active) {
      final kinds = {
        for (final s in overview.of(m.id)?.schedules ?? const <Schedule>[])
          if (s.active) s.scheduleType,
      };
      for (final k in kinds) {
        types[k] = (types[k] ?? 0) + 1;
      }
    }
    final typeLine = types.entries
        .map((e) => '${e.value} ${scheduleTypeLabel(e.key).toLowerCase()}')
        .join(', ');

    final low = [
      for (final m in active)
        if (overview.of(m.id)?.lowStock ?? false) m,
    ];
    final tracked = active.any((m) => overview.of(m.id)?.latest != null);
    final String refillSub;
    if (low.isNotEmpty) {
      final left = overview.of(low.first.id)!.latest!.remainingLabel;
      refillSub = '${low.first.name} · $left left';
    } else {
      refillSub = tracked ? 'Stock looks fine' : 'No refills logged';
    }

    return [
      StatData(
        label: 'Adherence',
        value: adherence == null ? '—' : '${(adherence * 100).round()}',
        unit: adherence == null ? '' : '%',
        sub: adherence == null ? 'No doses logged' : 'Last 7 days',
        progress: adherence,
        color: colors.data[0],
        icon: adherence == null ? Icons.insights_rounded : null,
        onTap: () => _showAdherence(today),
      ),
      StatData(
        label: 'Active',
        value: listReady ? '${active.length}' : '—',
        unit: 'meds',
        sub: typeLine.isEmpty ? 'Taking now' : typeLine,
        icon: Icons.medication_outlined,
        onTap: _pushAll,
      ),
      StatData(
        label: 'Refill soon',
        value: listReady ? '${low.length}' : '—',
        sub: refillSub,
        badge: low.isEmpty ? null : '!',
        icon: Icons.inventory_2_outlined,
        onTap: low.isEmpty ? null : () => _pushDetail(low.first.id),
      ),
    ];
  }

  List<Widget> _todaySections(MedicineTodayController today) {
    final data = today.today;
    if (data == null && today.isLoading) {
      return const [
        SizedBox(height: 24),
        PagePad(LoadingCard()),
      ];
    }
    if (data == null) {
      return [
        const SizedBox(height: 24),
        PagePad(
          UnavailableCard(name: "Today's doses", onRetry: today.refresh),
        ),
      ];
    }
    if (data.doses.isEmpty) {
      return const [
        SizedBox(height: 24),
        PagePad(EmptyCard(message: 'No medicines scheduled today.')),
      ];
    }
    return [
      for (final MapEntry(key: part, value: doses)
          in groupByDayPart(data.doses).entries) ...[
        MedSection(
          title: part.label,
          actionLabel:
              '${doses.where((d) => d.isTaken).length} of ${doses.length}',
        ),
        PagePad(
          GlassList(
            children: [
              for (final d in doses)
                _DoseRow(
                  dose: d,
                  today: today,
                  onDetail: () => _pushDetail(d.medicineId),
                  onRecord: _record,
                ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _myMedicines(
    MedicineListController controller,
    MedicineOverviewController overview,
  ) {
    if (controller.isLoading && controller.medicines.isEmpty) {
      return const LoadingCard();
    }
    if (controller.error != null && controller.medicines.isEmpty) {
      return UnavailableCard(name: 'Medicines', onRetry: controller.refresh);
    }
    final shown = [
      for (final m in controller.medicines)
        if (m.status != MedicineStatus.archived) m,
    ];
    if (shown.isEmpty) {
      return EmptyCard(
        message: 'No medicines yet. Add one to start a routine.',
        action: 'Add',
        onAction: _pushAdd,
      );
    }
    return GlassList(
      children: [
        for (final m in shown)
          MedicineRow(
            medicine: m,
            snapshot: overview.of(m.id),
            onTap: () => _pushDetail(m.id),
          ),
      ],
    );
  }

  Future<void> _record(ExpectedDose dose, DoseStatus status) async {
    final today = _today;
    if (today == null) return;
    final ok = status == DoseStatus.skipped
        ? await today.skipDose(dose)
        : await today.takeDose(dose);
    if (!mounted) return;
    if (ok) {
      _syncOverview(force: true);
      await refreshHomeDashboard(context);
    }
    if (!mounted) return;
    if (!ok && today.recordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(today.recordError.toString())),
      );
    }
  }

  void _onMenu(String value) {
    switch (value) {
      case 'search':
        _openSearch();
      case 'reminders':
        _openReminders();
      case 'history':
        _openHistoryPicker();
      case 'summary':
        _showAdherence(_today!);
    }
  }

  Future<void> _refreshAll() async {
    final controller = _controller;
    final today = _today;
    if (controller == null || today == null) return;
    await Future.wait([
      controller.refresh(),
      today.refresh(),
    ]);
    if (!mounted) return;
    _syncOverview(force: true);
  }

  Future<void> _pushAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedicineFormPage()),
    );
    await _afterMutation();
  }

  Future<void> _pushDetail(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MedicineDetailPage(medicineId: id)),
    );
    await _afterMutation();
  }

  Future<void> _pushHistory(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoseHistoryPage(medicineId: id)),
    );
    await _afterMutation();
  }

  Future<void> _pushAll() async {
    final api = _api;
    final overview = _overview;
    if (api == null || overview == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AllMedicinesPage(
          api: api,
          overview: overview,
          onOpen: (id) => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MedicineDetailPage(medicineId: id)),
          ),
          onAdd: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MedicineFormPage()),
          ),
        ),
      ),
    );
    await _afterMutation();
  }

  Future<void> _afterMutation() async {
    if (!mounted) return;
    await _refreshAll();
    if (!mounted) return;
    await refreshHomeDashboard(context);
  }

  void _openReminders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Reminders')),
          body: RemindersScreen(onRefresh: _refreshAll),
        ),
      ),
    );
  }

  void _openSearch() {
    final api = context.read<ApiClient>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          api: SearchApi(api),
          onOpenRoute: _openSearchRoute,
        ),
      ),
    );
  }

  Future<void> _openSearchRoute(String route) async {
    final destination = AppRoutes.resolveSearchRoute(route);
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    if (destination.detail != null) {
      final detail = destination.detail!;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => detail(context)),
      );
    } else if (destination.tab == AppTab.medicines) {
      _showMessage('Use the Medicines tab to continue browsing medicines.');
    } else {
      _showMessage('Open the matching tab to view this result.');
    }
  }

  Future<void> _openHistoryPicker() async {
    final controller = _controller;
    if (controller == null || controller.medicines.isEmpty) {
      _showMessage('Add a medicine and record a dose to see its history.');
      return;
    }
    final medicine = await showModalBottomSheet<Medicine>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final colors = BlistraColors.resolve(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 16),
              children: [
                Text('Dose history', style: BlistraText.serif(20, colors.text)),
                const SizedBox(height: 4),
                Text(
                  'Choose a medicine',
                  style: TextStyle(fontSize: 12.5, color: colors.muted),
                ),
                const SizedBox(height: 14),
                GlassList(
                  children: [
                    for (final m in controller.medicines)
                      GlassRow(
                        leading: IconWell(
                          medicineIcon(m),
                          color: medicineTint(context, m.name),
                        ),
                        title: medicineTitle(m),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: colors.muted,
                        ),
                        onTap: () => Navigator.pop(context, m),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (medicine != null && mounted) await _pushHistory(medicine.id);
  }

  Future<void> _showAdherence(MedicineTodayController today) async {
    final data = today.today;
    if (data == null) {
      _showMessage('Today\'s adherence is not available yet.');
      return;
    }
    final week = _overview?.weekAdherence;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Today\'s adherence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdherenceLine(label: 'Taken', value: '${data.takenDoses}'),
            _AdherenceLine(label: 'Due later', value: '${_dueLater(data)}'),
            _AdherenceLine(label: 'Overdue', value: '${_overdue(data)}'),
            _AdherenceLine(label: 'Missed', value: '${data.missedDoses}'),
            _AdherenceLine(label: 'Skipped', value: '${data.skippedDoses}'),
            if (week != null)
              _AdherenceLine(
                label: 'Last 7 days',
                value: '${(week * 100).round()}%',
              ),
            const SizedBox(height: 12),
            Text(
              'Based on recorded medicine doses.',
              style: TextStyle(
                fontSize: 12,
                color: BlistraColors.resolve(context).muted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// One expected dose: check circle, name and dose, status line, and Take /
/// Skip when due, otherwise the slot time.
class _DoseRow extends StatelessWidget {
  const _DoseRow({
    required this.dose,
    required this.today,
    required this.onDetail,
    required this.onRecord,
  });

  final ExpectedDose dose;
  final MedicineTodayController today;
  final VoidCallback onDetail;
  final Future<void> Function(ExpectedDose, DoseStatus) onRecord;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final future = dose.scheduledAt.isAfter(DateTime.now());
    final due = dose.isPending && !future;
    final recording = today.isRecording(dose);
    final time = DateFormat('h:mm a').format(dose.scheduledAt);

    final (String subtitle, Color? subColor) = switch (dose.status) {
      DoseStatus.taken => (
          'Taken ${DateFormat('h:mm a').format(dose.takenAt ?? dose.scheduledAt)}',
          null,
        ),
      DoseStatus.missed => ('Missed · $time', colors.danger),
      DoseStatus.skipped => ('Skipped · $time', colors.warning),
      null when future => ('Due ${dueIn(dose.scheduledAt)}', null),
      null => ('Overdue · due $time', colors.danger),
    };

    return GlassRow(
      leading: CheckCircle(
        checked: dose.isTaken,
        urgent: due || dose.status == DoseStatus.missed,
        busy: recording,
        semanticLabel:
            due ? 'Take ${dose.medicineName}' : 'Open ${dose.medicineName}',
        // Always tappable so every circle gets the same inset.
        onTap: due ? () => onRecord(dose, DoseStatus.taken) : onDetail,
      ),
      title: dose.doseLabel.isEmpty
          ? dose.medicineName
          : '${dose.medicineName} · ${dose.doseLabel}',
      subtitle: subtitle,
      subtitleColor: subColor,
      done: dose.status == DoseStatus.skipped,
      onTap: onDetail,
      trailing: due
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DoseActionButton(
                  label: 'Take',
                  filled: true,
                  busy: recording,
                  onTap: () => onRecord(dose, DoseStatus.taken),
                ),
                const SizedBox(width: 6),
                DoseActionButton(
                  label: 'Skip',
                  busy: recording,
                  onTap: () => onRecord(dose, DoseStatus.skipped),
                ),
              ],
            )
          : RowMeta(DateFormat('HH:mm').format(dose.scheduledAt)),
    );
  }
}

/// A medicine with its schedule summary and stock left; REFILL when low.
class MedicineRow extends StatelessWidget {
  const MedicineRow({
    super.key,
    required this.medicine,
    required this.snapshot,
    required this.onTap,
  });

  final Medicine medicine;
  final MedicineSnapshot? snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final snap = snapshot;
    final summary = snap == null ? '' : scheduleSummary(snap.schedules);
    final left = snap?.latest?.remainingQuantity == null
        ? ''
        : '${snap!.latest!.remainingLabel} left';
    final parts = [
      if (summary.isNotEmpty) summary,
      if (left.isNotEmpty) left,
    ];
    final fallback = [
      if (medicine.genericName?.isNotEmpty ?? false) medicine.genericName!,
      if (medicine.form?.isNotEmpty ?? false) medicine.form!,
    ];
    final subtitle = parts.isNotEmpty
        ? parts.join(' · ')
        : fallback.isNotEmpty
            ? fallback.join(' · ')
            : 'Medicine';

    final Widget trailing;
    if (snap?.lowStock ?? false) {
      trailing = Pill('REFILL', color: colors.warning);
    } else if (medicine.status != MedicineStatus.active) {
      trailing = Pill(
        medicineStatusLabel(medicine.status).toUpperCase(),
        color: medicineStatusColor(context, medicine.status),
      );
    } else {
      trailing = Icon(Icons.chevron_right_rounded, size: 18, color: colors.muted);
    }

    return GlassRow(
      leading: IconWell(
        medicineIcon(medicine),
        color: medicineTint(context, medicine.name),
      ),
      title: medicineTitle(medicine),
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Every medicine with a status filter; swipe a row to archive it.
class _AllMedicinesPage extends StatefulWidget {
  const _AllMedicinesPage({
    required this.api,
    required this.overview,
    required this.onOpen,
    required this.onAdd,
  });

  final MedicinesApiClient api;
  final MedicineOverviewController overview;
  final Future<void> Function(String id) onOpen;
  final Future<void> Function() onAdd;

  @override
  State<_AllMedicinesPage> createState() => _AllMedicinesPageState();
}

class _AllMedicinesPageState extends State<_AllMedicinesPage> {
  static const _filters = <MedicineStatus?>[
    null,
    MedicineStatus.active,
    MedicineStatus.paused,
    MedicineStatus.completed,
    MedicineStatus.archived,
  ];

  late final MedicineListController _controller =
      MedicineListController(widget.api)..refresh();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _archive(Medicine medicine) async {
    final ok = await confirmAction(
      context,
      title: 'Archive medicine?',
      message: 'Archive "${medicine.name}"?',
      confirmLabel: 'Archive',
    );
    if (!ok || !mounted) return;
    await _controller.archive(medicine.id);
    if (!mounted) return;
    await refreshHomeDashboard(context);
  }

  Future<void> _open(String id) async {
    await widget.onOpen(id);
    if (mounted) await _controller.refresh();
  }

  Future<void> _add() async {
    await widget.onAdd();
    if (mounted) await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: Listenable.merge([_controller, widget.overview]),
        builder: (context, _) {
          final c = _controller;
          return RefreshIndicator(
            onRefresh: c.refresh,
            child: SafeArea(
              bottom: false,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  BlistraPageHeader(
                    eyebrow: 'Medicines',
                    title: 'All medicines',
                    subtitle: c.isLoading && c.medicines.isEmpty
                        ? 'Loading…'
                        : '${c.medicines.length}${c.hasMore ? '+' : ''} '
                            '${c.medicines.length == 1 ? 'medicine' : 'medicines'}'
                            ' · swipe left to archive',
                    showAvatar: false,
                    actions: [
                      GlassIconButton(
                        tooltip: 'Add a medicine',
                        icon: Icons.add_rounded,
                        onTap: _add,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ChipRow(
                    labels: [
                      for (final s in _filters)
                        s == null ? 'All' : medicineStatusLabel(s),
                    ],
                    selected: _filters.indexOf(c.statusFilter),
                    onSelected: (i) => c.setStatusFilter(_filters[i]),
                  ),
                  const SizedBox(height: 16),
                  if (c.isLoading && c.medicines.isEmpty)
                    const PagePad(LoadingCard())
                  else if (c.error != null && c.medicines.isEmpty)
                    PagePad(UnavailableCard(name: 'Medicines', onRetry: c.refresh))
                  else if (c.medicines.isEmpty)
                    PagePad(
                      EmptyCard(
                        message: c.statusFilter == null
                            ? 'No medicines yet.'
                            : 'No ${medicineStatusLabel(c.statusFilter!).toLowerCase()} medicines.',
                        action: c.statusFilter == null ? 'Add' : null,
                        onAction: c.statusFilter == null ? _add : null,
                      ),
                    )
                  else
                    PagePad(
                      GlassList(
                        children: [
                          for (final m in c.medicines)
                            Dismissible(
                              key: ValueKey(m.id),
                              direction: c.isArchived(m)
                                  ? DismissDirection.none
                                  : DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                await _archive(m);
                                return false;
                              },
                              background: ColoredBox(
                                color: colors.danger.withValues(alpha: 0.22),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Icon(
                                      Icons.archive_outlined,
                                      color: colors.danger,
                                    ),
                                  ),
                                ),
                              ),
                              child: MedicineRow(
                                medicine: m,
                                snapshot: widget.overview.of(m.id),
                                onTap: () => _open(m.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (c.hasMore && c.medicines.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: _LoadMore(onVisible: c.loadMore)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdherenceLine extends StatelessWidget {
  const _AdherenceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: BlistraText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.onVisible});

  final Future<void> Function() onVisible;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: BlistraColors.resolve(context).accentText,
      ),
    );
  }
}

int _dueLater(MedicineToday data) => data.doses
    .where((dose) => dose.isPending && dose.scheduledAt.isAfter(DateTime.now()))
    .length;

int _overdue(MedicineToday data) => data.doses
    .where((dose) => dose.isPending && !dose.scheduledAt.isAfter(DateTime.now()))
    .length;
