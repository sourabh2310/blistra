/// Global Quick Add overlay: the single, reusable "+" experience.
///
/// Used from every authenticated screen with the bottom navigation (Home,
/// Planner, Modules, …). Actions route to the owning module's existing
/// creation flow — this overlay never duplicates forms, controllers, or API
/// clients. Presented via [showQuickAdd] with a fade/slide transition,
/// subtle dimming, and staggered action entrance.
///
/// Navigation: [showQuickAdd] returns the selected [QuickAddAction] (or null
/// on dismiss). Call [openQuickAddCreation] with that action to open the
/// existing domain creation flow. Dashboard refresh is quiet + non-blocking
/// and failures never leave the Add button stuck.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_scope.dart';
import '../../features/diet/diet_controller.dart';
import '../../features/diet/models/water.dart';
import '../../features/diet/screens/add_edit_meal_screen.dart';
import '../../features/habits/habits_controller.dart';
import '../../features/habits/habits_scope.dart';
import '../../features/habits/screens/habit_form_screen.dart';
import '../../features/medicines/pages/medicine_form_page.dart';
import '../../features/planner/planner_controller.dart';
import '../../features/planner/screens/event_form_screen.dart';
import '../../features/planner/screens/task_form_screen.dart';

/// Stable identity for each Quick Add destination. Drives
/// [openQuickAddCreation]; [QuickAddAction.tab] is only a fallback hint.
enum QuickAddKind { task, event, medicine, meal, water, habit }

/// One Quick Add destination: an existing creation flow in its owning module.
class QuickAddAction {
  const QuickAddAction({
    required this.kind,
    required this.label,
    required this.description,
    required this.icon,
    required this.semanticLabel,
    required this.tab,
    required this.tint,
    required this.iconColor,
  });

  final QuickAddKind kind;
  final String label;
  final String description;
  final IconData icon;
  final String semanticLabel;
  final int tab;
  final Color tint;
  final Color iconColor;
}

/// The supported actions — only flows that actually exist in the app.
///
/// Primary (general planning): Task, Event.
/// Secondary (domain): Medicine, Meal, Water, Habit.
/// Fixed visual hierarchy; no analytics-based ranking.
List<QuickAddAction> get quickAddActions => const [
      QuickAddAction(
        kind: QuickAddKind.task,
        label: 'Task',
        description: 'Something you need to get done',
        icon: Icons.add_task_outlined,
        semanticLabel: 'Add task',
        tab: 1,
        tint: Color(0xFFE6F6F3),
        iconColor: Color(0xFF0C6B6B),
      ),
      QuickAddAction(
        kind: QuickAddKind.event,
        label: 'Event',
        description: 'Schedule a time-bound commitment',
        icon: Icons.event_outlined,
        semanticLabel: 'Add event',
        tab: 1,
        tint: Color(0xFFEAF2FF),
        iconColor: Color(0xFF2E5AAC),
      ),
      QuickAddAction(
        kind: QuickAddKind.medicine,
        label: 'Medicine',
        description: 'Record or schedule a medicine',
        icon: Icons.medication_outlined,
        semanticLabel: 'Add medicine',
        tab: 3,
        tint: Color(0xFFEAF5FF),
        iconColor: Color(0xFF3E9BE9),
      ),
      QuickAddAction(
        kind: QuickAddKind.meal,
        label: 'Meal',
        description: 'Add a meal or food',
        icon: Icons.restaurant_outlined,
        semanticLabel: 'Add meal',
        tab: 3,
        tint: Color(0xFFEDF9E8),
        iconColor: Color(0xFF3E8E41),
      ),
      QuickAddAction(
        kind: QuickAddKind.water,
        label: 'Water',
        description: 'Log your water intake',
        icon: Icons.water_drop_outlined,
        semanticLabel: 'Add water',
        tab: 3,
        tint: Color(0xFFE8F6FD),
        iconColor: Color(0xFF0E94C9),
      ),
      QuickAddAction(
        kind: QuickAddKind.habit,
        label: 'Habit',
        description: 'Create or complete a habit',
        icon: Icons.check_circle_outline,
        semanticLabel: 'Add habit',
        tab: 3,
        tint: Color(0xFFF1EAFE),
        iconColor: Color(0xFF7C3AED),
      ),
    ];

/// Opens the existing creation flow for [action] using the app's real
/// controllers/routes. Never throws to the caller: domain screens own their
/// error UI, and dashboard refresh is best-effort + non-blocking.
Future<void> openQuickAddCreation(
    BuildContext context, QuickAddAction action) async {
  switch (action.kind) {
    case QuickAddKind.task:
      PlannerController planner;
      try {
        planner = context.read<PlannerController>();
      } catch (_) {
        planner = AppScope.of(context).planner;
      }
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => TaskFormScreen(planner: planner)),
      );
      if (saved == true && context.mounted) {
        // ignore: discarded_futures
        planner.loadSchedule();
        // ignore: discarded_futures
        planner.loadToday();
        _refreshDashboardQuiet(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created')),
        );
      }
      return;
    case QuickAddKind.event:
      PlannerController planner;
      try {
        planner = context.read<PlannerController>();
      } catch (_) {
        planner = AppScope.of(context).planner;
      }
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EventFormScreen(planner: planner)),
      );
      if (saved == true && context.mounted) {
        // ignore: discarded_futures
        planner.loadSchedule();
        // ignore: discarded_futures
        planner.loadToday();
        _refreshDashboardQuiet(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created')),
        );
      }
      return;
    case QuickAddKind.medicine:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MedicineFormPage()),
      );
      if (context.mounted) _refreshDashboardQuiet(context);
      return;
    case QuickAddKind.meal:
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AddEditMealScreen()),
      );
      if (saved == true && context.mounted) {
        // DietController.onMutated already refreshes the dashboard;
        // quiet refresh is a harmless best-effort fallback.
        _refreshDashboardQuiet(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal saved')),
        );
      }
      return;
    case QuickAddKind.water:
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _WaterQuickLogSheet(),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Water logged')),
        );
      }
      return;
    case QuickAddKind.habit:
      HabitsController habits;
      try {
        habits = context.read<HabitsController>();
      } catch (_) {
        // HabitFormScreen requires HabitsScope; without a controller we
        // cannot open the real form — fail loudly in debug, quietly in prod.
        assert(false, 'HabitsController missing for Quick Add');
        return;
      }
      // Existing habit creation is a bottom sheet; reuse that presentation
      // with an explicit HabitsScope so it works from any tab.
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HabitsScope(
          controller: habits,
          child: const _HabitSheetHost(),
        ),
      );
      if (context.mounted) _refreshDashboardQuiet(context);
      return;
  }
}

/// Best-effort dashboard refresh after a Quick Add mutation. Never throws and
/// never blocks creation: failures are swallowed by design (the owning
/// module's data is already correct).
void _refreshDashboardQuiet(BuildContext context) {
  Future<void> refresh() async {
    try {
      await AppScope.of(context).dashboard.refresh(
            date: DateTime.now(),
            offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          );
    } catch (_) {
      // Dashboard staleness is non-fatal.
    }
  }

  // ignore: discarded_futures
  refresh();
}

/// Shows the premium Quick Add surface. Returns the selected action, or null
/// when dismissed (outside tap, Android back, or close button).
Future<QuickAddAction?> showQuickAdd(BuildContext context) {
  return showGeneralDialog<QuickAddAction?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close quick add',
    barrierColor: const Color(0xFF101828).withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => const _QuickAddDialog(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
          parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _QuickAddDialog extends StatefulWidget {
  const _QuickAddDialog();

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = quickAddActions;
    final primary = actions.take(2).toList();
    final today = actions.sublist(2);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF6),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E7EC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text('Quick add',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Color(0xFF101828))),
                  ),
                  const SizedBox(height: 2),
                  const Center(
                    child: Text('What would you like to add?',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF667085))),
                  ),
                  const SizedBox(height: 14),
                  for (int i = 0; i < primary.length; i++)
                    _staggered(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PrimaryCard(
                          action: primary[i],
                          onTap: () => Navigator.pop(context, primary[i]),
                        ),
                      ),
                    ),
                  _staggered(
                    index: 2,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 8),
                      child: Text('TODAY',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF667085))),
                    ),
                  ),
                  _staggered(
                    index: 3,
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.9,
                      children: [
                        for (final a in today)
                          _GridCard(
                            action: a,
                            onTap: () => Navigator.pop(context, a),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _staggered({required int index, required Widget child}) {
    final start = (index * 0.09).clamp(0.0, 0.6);
    return FadeTransition(
      opacity: _stagger.drive(CurveTween(
          curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
              curve: Curves.easeOut))),
      child: SlideTransition(
        position: _stagger.drive(Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).chain(CurveTween(
            curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
                curve: Curves.easeOut)))),
        child: child,
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({required this.action, required this.onTap});

  final QuickAddAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: action.semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0EDE8)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: action.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(action.icon, color: action.iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.label,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF101828))),
                    const SizedBox(height: 1),
                    Text(action.description,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF667085))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.action, required this.onTap});

  final QuickAddAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: action.semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0EDE8)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: action.tint,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(action.icon, color: action.iconColor, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF101828))),
                    Text(action.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF667085))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Host matching the existing habit bottom-sheet presentation: warm rounded
/// sheet with safe-area + keyboard insets, hosting the real [HabitFormScreen].
class _HabitSheetHost extends StatelessWidget {
  const _HabitSheetHost();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.only(bottom: bottom),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF6),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const SingleChildScrollView(child: HabitFormScreen()),
      ),
    );
  }
}

/// Compact water logging sheet reusing the existing [DietController.addWater]
/// domain path (same API/client/validation as Diet Today). Never stuck:
/// failures show the controller's error and stay on the sheet for retry.
class _WaterQuickLogSheet extends StatefulWidget {
  const _WaterQuickLogSheet();

  @override
  State<_WaterQuickLogSheet> createState() => _WaterQuickLogSheetState();
}

class _WaterQuickLogSheetState extends State<_WaterQuickLogSheet> {
  final _amount = TextEditingController(text: '250');
  WaterUnit _unit = WaterUnit.ml;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final controller = context.read<DietController>();
      final ok = await controller.addWater(
        amount: parsed,
        unit: _unit.wireName,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  controller.lastActionError ?? 'Could not save water.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save water: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottom),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF6),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E7EC),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Log water',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Color(0xFF101828))),
            const SizedBox(height: 2),
            const Text('Quickly record your water intake.',
                style: TextStyle(fontSize: 14, color: Color(0xFF667085))),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Water amount',
                    textField: true,
                    child: TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFF0EDE8)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFF0EDE8)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<WaterUnit>(
                  value: _unit,
                  items: const [
                    DropdownMenuItem(
                        value: WaterUnit.ml, child: Text('ml')),
                    DropdownMenuItem(
                        value: WaterUnit.L, child: Text('litres')),
                    DropdownMenuItem(
                        value: WaterUnit.glass, child: Text('glasses')),
                    DropdownMenuItem(
                        value: WaterUnit.cup, child: Text('cups')),
                  ],
                  onChanged: (u) {
                    if (u != null) setState(() => _unit = u);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.water_drop_outlined),
                label: const Text('Log water'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
