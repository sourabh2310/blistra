import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/routing/routes.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/today_doses.dart';
import '../state/medicine_list_controller.dart';
import '../state/medicine_today_controller.dart';
import '../util/home_refresh.dart';
import '../../notifications/screens/reminders_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../search/search_api.dart';
import 'dose_history_page.dart';
import 'medicine_detail_page.dart';
import 'medicine_form_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';

class MedicineListPage extends StatefulWidget {
  const MedicineListPage({super.key});

  @override
  State<MedicineListPage> createState() => _MedicineListPageState();
}

class _MedicineListPageState extends State<MedicineListPage> {
  MedicineListController? _controller;
  MedicineTodayController? _today;
  bool _initialized = false;
  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final authState = context.read<AuthState>();
      final api = MedicinesApiClient(
        tokenProvider: () => authState.apiClient.token ?? '',
        onUnauthorized: () => authState.handleUnauthorized(),
      );
      _controller = MedicineListController(api);
      _today = MedicineTodayController(api);
      _controller!.refresh();
      _today!.refresh();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _today?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final today = _today;
    if (controller == null || today == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: Listenable.merge([controller, today]),
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: SafeArea(
              top: true,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                children: [
                  BlistraPageHeader(
                    title: 'Medicines',
                    subtitle: 'Stay consistent. Take control.',
                    padding: EdgeInsets.zero,
                    actions: [
                      GlassIconButton(
                        tooltip: 'Search',
                        icon: Icons.search_rounded,
                        onTap: _openSearch,
                      ),
                      GlassIconButton(
                        tooltip: 'Reminders',
                        icon: Icons.notifications_none_rounded,
                        onTap: _openReminders,
                      ),
                      GlassIconButton(
                        tooltip: 'Add a medicine',
                        icon: Icons.add_rounded,
                        onTap: _pushAdd,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MedicineTabs(
                    selectedIndex: _selectedTab,
                    onSelected: (index) => setState(() => _selectedTab = index),
                  ),
                  const SizedBox(height: 16),
                  ..._buildTabContent(controller, today),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTabContent(
    MedicineListController controller,
    MedicineTodayController today,
  ) {
    return switch (_selectedTab) {
      0 => _buildTodayTab(controller, today),
      1 => _buildScheduleTab(controller),
      2 => _buildMedicinesTab(controller),
      3 => _buildHistoryTab(controller),
      _ => _buildRemindersTab(),
    };
  }

  List<Widget> _buildTodayTab(
    MedicineListController controller,
    MedicineTodayController today,
  ) {
    return [
      _SummaryCards(today: today, controller: controller),
      const SizedBox(height: 16),
              _TodayMedicinesCard(
                today: today,
                onRefresh: today.refresh,
                onDetail: _pushDetail,
              ),
      const SizedBox(height: 12),
      _ActionCard(
        icon: Icons.add,
        title: 'Add a medicine',
        subtitle: 'Add a new medicine or supplement',
        onTap: _pushAdd,
        color: softBg(context, Color(0xFFEAF6EF)),
        iconColor: BlistraColors.resolve(context).accentText,
      ),
      const SizedBox(height: 12),
      _EntryCards(
        onReminders: _openReminders,
        onAdherence: () => _showAdherence(today),
        hasAdherence: today.today != null,
      ),
      const SizedBox(height: 12),
      _RecentActivity(
        today: today,
        controller: controller,
        onDetail: _pushDetail,
        onSeeAll: _openHistoryPicker,
      ),
    ];
  }

  List<Widget> _buildScheduleTab(MedicineListController controller) {
    return [
      _SectionHeading(
        icon: Icons.calendar_month_outlined,
        title: 'Schedules',
        trailing: 'Manage in medicine details',
      ),
      const SizedBox(height: 8),
      if (controller.isLoading && controller.medicines.isEmpty)
        const _LoadingCard()
      else if (controller.error != null && controller.medicines.isEmpty)
        _ErrorRetry(
          message: controller.error.toString(),
          onRetry: controller.refresh,
        )
      else if (controller.medicines.isEmpty)
        const _InlineEmpty(
          icon: Icons.calendar_month_outlined,
          title: 'No medicine schedules yet',
          message: 'Add a medicine first, then manage its schedule.',
        )
      else
        ...controller.medicines.map(
          (medicine) => _MedicineTile(
            medicine: medicine,
            onTap: () => _pushDetail(medicine.id),
            onArchive: _archive,
          ),
        ),
      const SizedBox(height: 12),
      const _InlineNote(
        icon: Icons.info_outline,
        text: 'Schedules are managed per medicine from its detail screen.',
      ),
    ];
  }

  List<Widget> _buildMedicinesTab(MedicineListController controller) {
    return [
      _SectionHeading(
        icon: Icons.medication_outlined,
        title: 'All medicines',
        trailing: '${controller.medicines.length} loaded',
      ),
      const SizedBox(height: 8),
      _StatusFilterChips(controller: controller),
      if (controller.isLoading && controller.medicines.isEmpty)
        const _LoadingCard()
      else if (controller.error != null && controller.medicines.isEmpty)
        _ErrorRetry(
          message: controller.error.toString(),
          onRetry: controller.refresh,
        )
      else if (controller.medicines.isEmpty)
        _EmptyState(onAdd: _pushAdd)
      else
        ...controller.medicines.map(
          (medicine) => _MedicineTile(
            medicine: medicine,
            onTap: () => _pushDetail(medicine.id),
            onArchive: _archive,
          ),
        ),
      if (controller.hasMore)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _LoadMore(onVisible: controller.loadMore),
          ),
        ),
    ];
  }

  List<Widget> _buildHistoryTab(MedicineListController controller) {
    return [
      _SectionHeading(
        icon: Icons.history_outlined,
        title: 'Dose history',
        trailing: 'Choose a medicine',
      ),
      const SizedBox(height: 8),
      const _InlineNote(
        icon: Icons.info_outline,
        text: 'Open a medicine to review, edit, or delete its recorded doses.',
      ),
      const SizedBox(height: 8),
      if (controller.isLoading && controller.medicines.isEmpty)
        const _LoadingCard()
      else if (controller.medicines.isEmpty)
        const _InlineEmpty(
          icon: Icons.history_outlined,
          title: 'No dose history available',
          message: 'Add a medicine and record a dose to begin.',
        )
      else
        ...controller.medicines.map(
          (medicine) => _MedicineHistoryTile(
            medicine: medicine,
            onTap: () => _pushHistory(medicine.id),
          ),
        ),
    ];
  }

  List<Widget> _buildRemindersTab() {
    return [
      _SectionHeading(
        icon: Icons.notifications_none_outlined,
        title: 'Reminders',
        trailing: 'Real reminder data',
      ),
      const SizedBox(height: 8),
      _ActionCard(
        icon: Icons.notifications_none,
        title: 'Manage reminders',
        subtitle: 'View and edit your medicine and general reminders',
        onTap: _openReminders,
        color: softBg(context, Color(0xFFEAF3FF)),
        iconColor: const Color(0xFF2D78C5),
      ),
      const SizedBox(height: 12),
      const _InlineNote(
        icon: Icons.notifications_active_outlined,
        text: 'Reminder schedules and delivery settings are managed in Reminders.',
      ),
    ];
  }

  Future<void> _refreshAll() async {
    final controller = _controller;
    final today = _today;
    if (controller == null || today == null) return;
    await Future.wait([
      controller.refresh(),
      today.refresh(),
    ]);
  }

  Future<void> _archive(String id) async {
    final controller = _controller;
    final today = _today;
    if (controller == null || today == null) return;
    await controller.archive(id);
    if (!mounted) return;
    await today.refresh();
    if (!mounted) return;
    await refreshHomeDashboard(context);
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
    if (controller == null || controller.medicines.isEmpty) return;
    final medicine = await showModalBottomSheet<Medicine>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Choose a medicine for history',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            ...controller.medicines.map(
              (medicine) => ListTile(
                leading: CircleAvatar(child: Text(_initials(medicine.name))),
                title: Text(medicine.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, medicine),
              ),
            ),
          ],
        ),
      ),
    );
    if (medicine != null && mounted) await _pushHistory(medicine.id);
  }

  Future<void> _showAdherence(MedicineTodayController today) async {
    final data = today.today;
    if (data == null) {
      _showMessage('Today\'s adherence is not available yet.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.bar_chart_rounded),
        title: const Text('Today\'s adherence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdherenceLine(label: 'Taken', value: data.takenDoses),
            _AdherenceLine(label: 'Due later', value: _dueLater(data)),
            _AdherenceLine(label: 'Overdue', value: _overdue(data)),
            _AdherenceLine(label: 'Missed', value: data.missedDoses),
            _AdherenceLine(label: 'Skipped', value: data.skippedDoses),
            const SizedBox(height: 12),
            Text('Based on today\'s recorded medicine doses.'),
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

class _MedicineTabs extends StatelessWidget {
  const _MedicineTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Today', 'Schedule', 'Medicines', 'History', 'Reminders'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ActiveColors.glassFill,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: softBg(context, Color(0xFFE7EAED))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              GestureDetector(
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: index == selectedIndex
                        ? softBg(context, Color(0xFFDDEFE8))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: BlistraColors.resolve(context).text,
                      fontWeight: index == selectedIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.today, required this.controller});

  final MedicineTodayController today;
  final MedicineListController controller;

  @override
  Widget build(BuildContext context) {
    final data = today.today;
    final int active = controller.medicines
        .where((medicine) => medicine.status == MedicineStatus.active)
        .length;
    final double progress = data == null || data.totalDoses == 0
        ? 0.0
        : data.takenDoses / data.totalDoses;
    // Cards grow with their content (large text, progress bar) but stay the
    // same height as each other.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        _SummaryCard(
          value: data == null ? '—' : '${data.takenDoses}/${data.totalDoses}',
          label: 'Taken today',
          icon: Icons.check_rounded,
          color: softBg(context, Color(0xFFE5F7EC)),
          iconColor: const Color(0xFF15934C),
          progress: progress,
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: data == null ? '—' : '${_dueLater(data)}',
          label: 'Due later',
          icon: Icons.schedule_rounded,
          color: softBg(context, Color(0xFFE8F3FF)),
          iconColor: const Color(0xFF2385E8),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: data == null ? '—' : '${_overdue(data)}',
          label: 'Overdue',
          icon: Icons.notifications_active_outlined,
          color: softBg(context, Color(0xFFFFEBEE)),
          iconColor: const Color(0xFFE24454),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: controller.isLoading || controller.error != null ? '—' : '$active',
          label: 'Active\nmedicines',
          icon: Icons.medical_services_outlined,
          color: softBg(context, Color(0xFFF3EAFF)),
          iconColor: const Color(0xFF9145E8),
        ),
      ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.progress,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: BlistraColors.resolve(context).text,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: BlistraColors.resolve(context).muted,
                    height: 1.05,
                  ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: BlistraColors.resolve(context).glassFill,
                  color: const Color(0xFF19A853),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayMedicinesCard extends StatelessWidget {
  const _TodayMedicinesCard({
    required this.today,
    required this.onRefresh,
    required this.onDetail,
  });

  final MedicineTodayController today;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onDetail;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: today,
      builder: (context, _) {
        final data = today.today;
        if (data == null && today.isLoading) return const _LoadingCard();
        if (data == null && today.error != null) {
          return _ErrorRetry(
            message: today.error.toString(),
            onRetry: onRefresh,
          );
        }
        final current = data;
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: ActiveColors.glassFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: softBg(context, Color(0xFFE8EBEE))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: BlistraColors.resolve(context).accentText, size: 23),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Today's medicines",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: BlistraColors.resolve(context).text,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: softBg(context, Color(0xFFF0F2F3)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      current == null
                          ? 'Today'
                          : DateFormat('EEE, d MMM').format(current.date),
                      style: TextStyle(
                        color: BlistraColors.resolve(context).muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (current == null)
                const Text('Today\'s doses are not available yet.')
              else if (current.doses.isEmpty)
                const _InlineEmpty(
                  icon: Icons.water_drop_outlined,
                  title: 'No medicines scheduled today',
                  message: 'Your schedule is clear for today.',
                )
              else ...[
                for (var index = 0; index < current.doses.length; index++)
                  _TimelineDoseRow(
                    dose: current.doses[index],
                    first: index == 0,
                    last: index == current.doses.length - 1,
                    today: today,
                    onDetail: onDetail,
                  ),
                if (current.allCompleted) const _AllDoneBanner(),
                if (today.recordError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      today.recordError.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TimelineDoseRow extends StatelessWidget {
  const _TimelineDoseRow({
    required this.dose,
    required this.first,
    required this.last,
    required this.today,
    required this.onDetail,
  });

  final ExpectedDose dose;
  final bool first;
  final bool last;
  final MedicineTodayController today;
  final Future<void> Function(String) onDetail;

  @override
  Widget build(BuildContext context) {
    final future = dose.scheduledAt.isAfter(DateTime.now());
    final color = _medicineColor(dose.medicineName);
    final background = _medicineBackground(color);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 65,
            child: Padding(
              padding: const EdgeInsets.only(top: 17),
              child: Text(
                DateFormat('h:mm a').format(dose.scheduledAt),
                style: TextStyle(
                  color: BlistraColors.resolve(context).muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 25,
            child: CustomPaint(
              painter: _TimelinePainter(
                first: first,
                last: last,
                color: _timelineColor(dose, future),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: BlistraColors.resolve(context).glassFill,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        _medicineIcon(dose.medicineName),
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: InkWell(
                        onTap: () => onDetail(dose.medicineId),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dose.medicineName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: BlistraColors.resolve(context).text,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dose.doseLabel.isEmpty
                                  ? 'Scheduled dose'
                                  : dose.doseLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: BlistraColors.resolve(context).muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _DoseAction(dose: dose, future: future, today: today),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseAction extends StatelessWidget {
  const _DoseAction({
    required this.dose,
    required this.future,
    required this.today,
  });

  final ExpectedDose dose;
  final bool future;
  final MedicineTodayController today;

  @override
  Widget build(BuildContext context) {
    final status = dose.status;
    if (status == DoseStatus.taken) {
      return const _MiniStatus(
        icon: Icons.check_circle,
        label: 'Taken',
        color: Color(0xFF15934C),
      );
    }
    if (status == DoseStatus.missed) {
      return const _MiniStatus(
        icon: Icons.cancel_outlined,
        label: 'Missed',
        color: Color(0xFFE24454),
      );
    }
    if (status == DoseStatus.skipped) {
      return const _MiniStatus(
        icon: Icons.remove_circle_outline,
        label: 'Skipped',
        color: Color(0xFFE08A22),
      );
    }
    if (future) {
      final hours = dose.scheduledAt.difference(DateTime.now()).inMinutes;
      final label = hours < 60
          ? 'Due in ${hours.clamp(1, 59)}m'
          : 'Due in ${(hours / 60).round()}h';
      return _MiniStatus(
        icon: Icons.schedule_outlined,
        label: label,
        color: BlistraColors.resolve(context).muted,
      );
    }
    final recording = today.isRecording(dose);
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: recording
            ? null
            : () async {
                final ok = await today.takeDose(dose);
                if (!context.mounted) return;
                if (ok) await refreshHomeDashboard(context);
                if (!context.mounted) return;
                if (!ok && today.recordError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(today.recordError.toString())),
                  );
                }
              },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0C8A64),
          minimumSize: const Size(58, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        child: recording
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Take'),
      ),
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: softBg(context, Color(0xFFEAF8EE)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Color(0xFF15934C), size: 18),
          SizedBox(width: 7),
          Text(
            'All doses completed',
            style: TextStyle(
              color: Color(0xFF15934C),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: BlistraColors.resolve(context).glassFill,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: BlistraColors.resolve(context).text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BlistraColors.resolve(context).muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: BlistraColors.resolve(context).text),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCards extends StatelessWidget {
  const _EntryCards({
    required this.onReminders,
    required this.onAdherence,
    required this.hasAdherence,
  });

  final VoidCallback onReminders;
  final VoidCallback onAdherence;
  final bool hasAdherence;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _EntryCard(
            icon: Icons.notifications_none_outlined,
            title: 'Reminders',
            subtitle: 'Manage reminders and notifications',
            onTap: onReminders,
            color: softBg(context, Color(0xFFEAF3FF)),
            iconColor: const Color(0xFF2D78C5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _EntryCard(
            icon: Icons.bar_chart_rounded,
            title: 'Adherence',
            subtitle: hasAdherence
                ? 'Track your consistency today'
                : 'Available after today loads',
            onTap: onAdherence,
            color: softBg(context, Color(0xFFEAF3FF)),
            iconColor: const Color(0xFF2385E8),
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ActiveColors.glassFill,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: BlistraColors.resolve(context).text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BlistraColors.resolve(context).muted,
                        fontSize: 11,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: BlistraColors.resolve(context).text, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.today,
    required this.controller,
    required this.onDetail,
    required this.onSeeAll,
  });

  final MedicineTodayController today;
  final MedicineListController controller;
  final Future<void> Function(String) onDetail;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: today,
      builder: (context, _) {
        final data = today.today;
        final records = data?.doses
                .where((dose) => dose.status != null)
                .take(5)
                .toList() ??
            const <ExpectedDose>[];
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 7),
          decoration: BoxDecoration(
            color: ActiveColors.glassFill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: softBg(context, Color(0xFFE8EBEE))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.history_rounded, color: BlistraColors.resolve(context).accentText),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Recent activity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: BlistraColors.resolve(context).text,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (controller.medicines.isNotEmpty)
                    TextButton.icon(
                      onPressed: onSeeAll,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: const Text('See all'),
                      style: TextButton.styleFrom(
                        foregroundColor: BlistraColors.resolve(context).text,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
              if (records.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No recorded activity today yet.',
                      style: TextStyle(color: BlistraColors.resolve(context).muted),
                    ),
                  ),
                )
              else
                for (final record in records) _ActivityRow(
                  dose: record,
                  onTap: () => onDetail(record.medicineId),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.dose, required this.onTap});

  final ExpectedDose dose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = dose.status!;
    final color = _doseColor(status);
    final label = switch (status) {
      DoseStatus.taken => 'Took',
      DoseStatus.missed => 'Missed',
      DoseStatus.skipped => 'Skipped',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_doseIcon(status), color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label ${dose.medicineName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BlistraColors.resolve(context).text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${dose.doseLabel.isEmpty ? 'Dose' : dose.doseLabel} · ${DateFormat('h:mm a').format(dose.scheduledAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('d MMM').format(dose.scheduledAt),
              style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
            ),
            const SizedBox(width: 5),
            Icon(Icons.chevron_right, size: 18, color: BlistraColors.resolve(context).text),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: BlistraColors.resolve(context).accentText, size: 23),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BlistraColors.resolve(context).text,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.controller});

  final MedicineListController controller;

  @override
  Widget build(BuildContext context) {
    const statuses = <MedicineStatus?>[
      null,
      MedicineStatus.active,
      MedicineStatus.paused,
      MedicineStatus.completed,
      MedicineStatus.archived,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          for (final status in statuses)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: FilterChip(
                label: Text(status == null ? 'All' : medicineStatusLabel(status)),
                selected: controller.statusFilter == status,
                onSelected: (_) => controller.setStatusFilter(status),
                selectedColor: softBg(context, Color(0xFFDDEFE8)),
                labelStyle: TextStyle(fontSize: 12, color: BlistraColors.resolve(context).text),
                side: BorderSide(color: softBg(context, Color(0xFFE2E6E5))),
              ),
            ),
        ],
      ),
    );
  }
}

class _MedicineTile extends StatelessWidget {
  const _MedicineTile({
    required this.medicine,
    required this.onTap,
    required this.onArchive,
  });

  final Medicine medicine;
  final VoidCallback onTap;
  final Future<void> Function(String) onArchive;

  @override
  Widget build(BuildContext context) {
    final color = _medicineColor(medicine.name);
    return Dismissible(
      key: ValueKey(medicine.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Archive medicine?'),
                content: Text('Archive "${medicine.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Archive'),
                  ),
                ],
              ),
            ) ??
            false;
        if (ok && context.mounted) await onArchive(medicine.id);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      child: Material(
        color: ActiveColors.glassFill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _medicineBackground(color),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(_medicineIcon(medicine.name), color: color, size: 25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: BlistraColors.resolve(context).text,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (medicine.genericName != null &&
                          medicine.genericName!.isNotEmpty)
                        Text(
                          medicine.genericName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _medicineDetails(medicine),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: medicine.status),
                const SizedBox(width: 3),
                Icon(Icons.chevron_right, color: BlistraColors.resolve(context).text, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicineHistoryTile extends StatelessWidget {
  const _MedicineHistoryTile({required this.medicine, required this.onTap});

  final Medicine medicine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _medicineColor(medicine.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: ActiveColors.glassFill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _medicineBackground(color),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_medicineIcon(medicine.name), color: color),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: TextStyle(
                          color: BlistraColors.resolve(context).text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'View recorded doses',
                        style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: BlistraColors.resolve(context).text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdherenceLine extends StatelessWidget {
  const _AdherenceLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MedicineStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        medicineStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 34, color: BlistraColors.resolve(context).muted),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BlistraColors.resolve(context).text,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softBg(context, Color(0xFFF2F8F5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: BlistraColors.resolve(context).accentText, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ActiveColors.glassFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: softBg(context, Color(0xFFE8EBEE))),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, size: 44, color: BlistraColors.resolve(context).muted),
          const SizedBox(height: 10),
          Text(
            'No medicines yet',
            style: TextStyle(color: BlistraColors.resolve(context).text, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first medicine to start building a routine.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BlistraColors.resolve(context).muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add medicine'),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: ActiveColors.glassFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
          const SizedBox(height: 8),
          Text(
            'Could not load this section',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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
    return const CircularProgressIndicator();
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.first,
    required this.last,
    required this.color,
  });

  final bool first;
  final bool last;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = ActiveColors.scene(Color(0xFFD5E5E0))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (!first) {
      canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height / 2), line);
    }
    if (!last) {
      canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(size.width / 2, size.height), line);
    }
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 7, Paint()..color = color);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      3,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.first != first || oldDelegate.last != last || oldDelegate.color != color;
}

IconData _medicineIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('syrup') || value.contains('liquid')) {
    return Icons.local_drink_outlined;
  }
  if (value.contains('cream') || value.contains('ointment')) {
    return Icons.spa_outlined;
  }
  if (value.contains('vitamin')) return Icons.wb_sunny_outlined;
  return Icons.medication_outlined;
}

Color _medicineColor(String name) {
  final value = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  const colors = [
    Color(0xFFEF6B7C),
    Color(0xFF269BD2),
    Color(0xFF35B89A),
    Color(0xFF8A69D9),
    Color(0xFFE99B38),
  ];
  return colors[value % colors.length];
}

Color _medicineBackground(Color color) => color.withValues(alpha: 0.11);

Color _timelineColor(ExpectedDose dose, bool future) {
  if (dose.isTaken) return const Color(0xFF16A34A);
  if (dose.status == DoseStatus.missed) return const Color(0xFFE24454);
  if (dose.status == DoseStatus.skipped) return const Color(0xFFE08A22);
  return future ? const Color(0xFF2385E8) : const Color(0xFF9AA7B4);
}

Color _statusColor(MedicineStatus status) => switch (status) {
      MedicineStatus.active => const Color(0xFF15934C),
      MedicineStatus.paused => const Color(0xFFE08A22),
      MedicineStatus.completed => const Color(0xFF2385E8),
      MedicineStatus.archived => const Color(0xFF7C8796),
    };

Color _doseColor(DoseStatus status) => switch (status) {
      DoseStatus.taken => const Color(0xFF15934C),
      DoseStatus.missed => const Color(0xFFE24454),
      DoseStatus.skipped => const Color(0xFFE08A22),
    };

IconData _doseIcon(DoseStatus status) => switch (status) {
      DoseStatus.taken => Icons.check_rounded,
      DoseStatus.missed => Icons.close_rounded,
      DoseStatus.skipped => Icons.remove_rounded,
    };

int _dueLater(MedicineToday data) => data.doses
    .where((dose) => dose.isPending && dose.scheduledAt.isAfter(DateTime.now()))
    .length;

int _overdue(MedicineToday data) => data.doses
    .where((dose) => dose.isPending && !dose.scheduledAt.isAfter(DateTime.now()))
    .length;

String _medicineDetails(Medicine medicine) {
  final details = [
    if (medicine.form != null && medicine.form!.isNotEmpty) medicine.form,
    if (medicine.strength != null) medicine.strengthLabel,
  ].whereType<String>();
  return details.isEmpty ? 'Medicine' : details.join(' · ');
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'B' : trimmed.substring(0, 1).toUpperCase();
}
