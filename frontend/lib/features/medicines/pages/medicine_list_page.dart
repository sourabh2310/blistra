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
import '../../planner/screens/home_screen.dart';
import '../../profile/profile_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../search/search_api.dart';
import 'dose_history_page.dart';
import 'medicine_detail_page.dart';
import 'medicine_form_page.dart';

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
      backgroundColor: const Color(0xFFFFFBF6),
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
                  _BrandHeader(
                    onSearch: _openSearch,
                    onNotifications: _openReminders,
                    onCalendar: _openPlanner,
                    onProfile: _openProfile,
                  ),
                  const SizedBox(height: 22),
                  _PageIntro(onAdd: _pushAdd),
                  const SizedBox(height: 12),
                  _HeroBanner(onAdd: _pushAdd),
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
        color: const Color(0xFFEAF6EF),
        iconColor: const Color(0xFF0A785A),
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
        color: const Color(0xFFEAF3FF),
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

  void _openPlanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
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

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.onSearch,
    required this.onNotifications,
    required this.onCalendar,
    required this.onProfile,
  });

  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onCalendar;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthState>();
    final name = auth.account?.username ?? auth.userEmail;
    final initials = name.isEmpty ? 'B' : _initials(name);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Blistra',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0B4F46),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                        ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.eco_rounded, color: Color(0xFF4A9B64), size: 24),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                'EVERYTHING YOU NEED. ONE APP.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF52717A),
                      letterSpacing: 1.3,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        _ActionCircle(icon: Icons.search, tooltip: 'Search', onTap: onSearch),
        const SizedBox(width: 5),
        _ActionCircle(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Reminders',
          onTap: onNotifications,
        ),
        const SizedBox(width: 5),
        _ActionCircle(
          icon: Icons.calendar_today_outlined,
          tooltip: 'Planner',
          onTap: onCalendar,
        ),
        const SizedBox(width: 5),
        Semantics(
          label: 'Profile',
          button: true,
          child: InkWell(
            onTap: onProfile,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE2F1EE),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF0B4F46),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medicines',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: const Color(0xFF070B3B),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stay consistent. Take control.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF5163A1),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: const BorderSide(color: Color(0xFFB5D9D1)),
            foregroundColor: const Color(0xFF0B6B5C),
          ),
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 144,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F0),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD5E9E1)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MedicineHeroPainter()),
          ),
          Positioned(
            left: 18,
            right: 100,
            top: 18,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A healthier rhythm\nstarts here.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF0B4F46),
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Start a routine'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: const Color(0xFF0B6B5C),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7EAED)),
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
                        ? const Color(0xFFDDEFE8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: const Color(0xFF071047),
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
    return Row(
      children: [
        _SummaryCard(
          value: data == null ? '—' : '${data.takenDoses}/${data.totalDoses}',
          label: 'Taken today',
          icon: Icons.check_rounded,
          color: const Color(0xFFE5F7EC),
          iconColor: const Color(0xFF15934C),
          progress: progress,
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: data == null ? '—' : '${_dueLater(data)}',
          label: 'Due later',
          icon: Icons.schedule_rounded,
          color: const Color(0xFFE8F3FF),
          iconColor: const Color(0xFF2385E8),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: data == null ? '—' : '${_overdue(data)}',
          label: 'Overdue',
          icon: Icons.notifications_active_outlined,
          color: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFE24454),
        ),
        const SizedBox(width: 8),
        _SummaryCard(
          value: controller.isLoading || controller.error != null ? '—' : '$active',
          label: 'Active\nmedicines',
          icon: Icons.medical_services_outlined,
          color: const Color(0xFFF3EAFF),
          iconColor: const Color(0xFF9145E8),
        ),
      ],
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
        height: 112,
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
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF071047),
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF53618A),
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
                  backgroundColor: Colors.white.withValues(alpha: 0.75),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8EBEE)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF0A6B59), size: 23),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Today's medicines",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF071047),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      current == null
                          ? 'Today'
                          : DateFormat('EEE, d MMM').format(current.date),
                      style: const TextStyle(
                        color: Color(0xFF53618A),
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
                style: const TextStyle(
                  color: Color(0xFF53618A),
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
                        color: Colors.white.withValues(alpha: 0.78),
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
                              style: const TextStyle(
                                color: Color(0xFF071047),
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
                              style: const TextStyle(
                                color: Color(0xFF53618A),
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
        color: const Color(0xFF53618A),
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
        color: const Color(0xFFEAF8EE),
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
                  color: Colors.white.withValues(alpha: 0.7),
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
                      style: const TextStyle(
                        color: Color(0xFF071047),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF53618A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF071047)),
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
            color: const Color(0xFFEAF3FF),
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
            color: const Color(0xFFEAF3FF),
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
      color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF071047),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF53618A),
                        fontSize: 11,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF071047), size: 20),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8EBEE)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF0A6B59)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Recent activity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF071047),
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
                        foregroundColor: const Color(0xFF071047),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No recorded activity today yet.',
                      style: TextStyle(color: Color(0xFF53618A)),
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
                    style: const TextStyle(
                      color: Color(0xFF071047),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${dose.doseLabel.isEmpty ? 'Dose' : dose.doseLabel} · ${DateFormat('h:mm a').format(dose.scheduledAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF53618A), fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('d MMM').format(dose.scheduledAt),
              style: const TextStyle(color: Color(0xFF6B78A3), fontSize: 12),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF071047)),
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
        Icon(icon, color: const Color(0xFF0A6B59), size: 23),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF071047),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(color: Color(0xFF6B78A3), fontSize: 12),
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
                selectedColor: const Color(0xFFDDEFE8),
                labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF071047)),
                side: const BorderSide(color: Color(0xFFE2E6E5)),
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
        color: Colors.white,
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
                        style: const TextStyle(
                          color: Color(0xFF071047),
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
                          style: const TextStyle(color: Color(0xFF53618A), fontSize: 12),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        _medicineDetails(medicine),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF6B78A3), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: medicine.status),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right, color: Color(0xFF071047), size: 20),
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
        color: Colors.white,
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
                        style: const TextStyle(
                          color: Color(0xFF071047),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'View recorded doses',
                        style: TextStyle(color: Color(0xFF53618A), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF071047)),
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
          Icon(icon, size: 34, color: const Color(0xFF8AA39D)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF071047),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF53618A), fontSize: 12),
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
        color: const Color(0xFFF2F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A6B59), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF53618A), fontSize: 12),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EBEE)),
      ),
      child: Column(
        children: [
          const Icon(Icons.medication_outlined, size: 44, color: Color(0xFF8AA39D)),
          const SizedBox(height: 10),
          const Text(
            'No medicines yet',
            style: TextStyle(color: Color(0xFF071047), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add your first medicine to start building a routine.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF53618A), fontSize: 12),
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
        color: Colors.white,
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

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.78),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: const Color(0xFF071047), size: 22),
          ),
        ),
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
      ..color = const Color(0xFFD5E5E0)
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

class _MedicineHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final back = Paint()..color = const Color(0xFFDCEFE8);
    final mid = Paint()..color = const Color(0xFFB8DCC9);
    final dark = Paint()..color = const Color(0xFF4A9B64);
    final blue = Paint()..color = const Color(0xFF2D9FD0);
    final white = Paint()..color = Colors.white;
    final shadow = Paint()..color = const Color(0xFF0A6B59).withValues(alpha: 0.12);
    final center = Offset(size.width * 0.78, size.height * 0.52);
    canvas.drawCircle(center, size.height * 0.55, back);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.24), size.height * 0.22, mid);
    canvas.save();
    canvas.translate(size.width * 0.75, size.height * 0.52);
    canvas.rotate(-0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 52, height: 65),
        const Radius.circular(10),
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -28), width: 55, height: 18),
        const Radius.circular(5),
      ),
      blue,
    );
    canvas.drawRect(const Rect.fromLTWH(-18, -4, 36, 24), shadow);
    canvas.drawCircle(const Offset(-10, 8), 7, mid);
    canvas.drawCircle(const Offset(9, 2), 8, blue);
    canvas.restore();
    _drawLeaf(canvas, size, const Offset(0.87, 0.16), 0.65, dark, 0.4);
    _drawLeaf(canvas, size, const Offset(0.94, 0.67), 0.9, mid, -0.65);
    _drawLeaf(canvas, size, const Offset(0.65, 0.11), 0.42, const Color(0xFF78B58A), -0.35);
    final pill = Paint()..color = const Color(0xFFEA7B8C);
    canvas.save();
    canvas.translate(size.width * 0.62, size.height * 0.78);
    canvas.rotate(-0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 34, height: 14),
        const Radius.circular(7),
      ),
      pill,
    );
    canvas.drawLine(const Offset(-3, -7), const Offset(-3, 7), white, width: 2);
    canvas.restore();
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.78), 9, white);
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.78), 4, const Color(0xFFEA7B8C));
  }

  void _drawLeaf(
    Canvas canvas,
    Size size,
    Offset position,
    double scale,
    Color color,
    double rotation,
  ) {
    final center = Offset(position.dx * size.width, position.dy * size.height);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(-12 * scale, -6 * scale, -12 * scale, -22 * scale, 0, -30 * scale)
      ..cubicTo(12 * scale, -22 * scale, 12 * scale, -6 * scale, 0, 0)
      ..close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawPath(leaf, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MedicineHeroPainter oldDelegate) => false;
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
