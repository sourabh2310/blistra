import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_scope.dart';
import '../../features/diet/diet_controller.dart';
import '../../features/diet/models/water.dart';
import '../../features/diet/screens/add_edit_meal_screen.dart';
import '../../features/finance/finance_controller.dart';
import '../../features/finance/finance_scope.dart';
import '../../features/finance/screens/transactions_screen.dart';
import '../../features/habits/habits_controller.dart';
import '../../features/habits/habits_scope.dart';
import '../../features/habits/screens/habit_form_screen.dart';
import '../../features/health/health_repository.dart';
import '../../features/health/presentation/measurement_form_screen.dart';
import '../../features/medicines/pages/medicine_form_page.dart';
import '../../features/planner/models/task_priority.dart';
import '../../features/planner/planner_controller.dart';
import '../../features/planner/screens/event_form_screen.dart';
import '../../features/planner/screens/task_form_screen.dart';

enum QuickAddKind {
  task,
  event,
  meal,
  medicine,
  habit,
  health,
  expense,
  water,
  quickAdd,
}

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

List<QuickAddAction> get quickAddActions => const [
      QuickAddAction(
        kind: QuickAddKind.task,
        label: 'Task',
        description: 'To do, work, personal',
        icon: Icons.description_outlined,
        semanticLabel: 'Add task',
        tab: 1,
        tint: Color(0xFFE7F0FF),
        iconColor: Color(0xFF438FE8),
      ),
      QuickAddAction(
        kind: QuickAddKind.event,
        label: 'Event',
        description: 'Meeting, appointment',
        icon: Icons.calendar_today_outlined,
        semanticLabel: 'Add event',
        tab: 1,
        tint: Color(0xFFFBEAF0),
        iconColor: Color(0xFFF05267),
      ),
      QuickAddAction(
        kind: QuickAddKind.meal,
        label: 'Meal',
        description: 'Breakfast, lunch, dinner, snack',
        icon: Icons.restaurant_outlined,
        semanticLabel: 'Add meal',
        tab: 3,
        tint: Color(0xFFFCEBDB),
        iconColor: Color(0xFFF56B16),
      ),
      QuickAddAction(
        kind: QuickAddKind.medicine,
        label: 'Medicine',
        description: 'Take a dose, log medicine',
        icon: Icons.medication_outlined,
        semanticLabel: 'Add medicine',
        tab: 3,
        tint: Color(0xFFE8F0FF),
        iconColor: Color(0xFF3F8FE7),
      ),
      QuickAddAction(
        kind: QuickAddKind.habit,
        label: 'Habit',
        description: 'Track your habits',
        icon: Icons.radio_button_unchecked,
        semanticLabel: 'Add habit',
        tab: 3,
        tint: Color(0xFFF1E7FC),
        iconColor: Color(0xFF9B32D4),
      ),
      QuickAddAction(
        kind: QuickAddKind.health,
        label: 'Health',
        description: 'Weight, BP, measurements',
        icon: Icons.eco_outlined,
        semanticLabel: 'Add health measurement',
        tab: 2,
        tint: Color(0xFFE8F4EE),
        iconColor: Color(0xFF208A5A),
      ),
      QuickAddAction(
        kind: QuickAddKind.expense,
        label: 'Expense',
        description: 'Track your spending',
        icon: Icons.account_balance_wallet_outlined,
        semanticLabel: 'Add expense',
        tab: 4,
        tint: Color(0xFFF8ECD9),
        iconColor: Color(0xFFC47A27),
      ),
      QuickAddAction(
        kind: QuickAddKind.water,
        label: 'Water',
        description: 'Log water intake',
        icon: Icons.water_drop_outlined,
        semanticLabel: 'Add water',
        tab: 3,
        tint: Color(0xFFE5F4FC),
        iconColor: Color(0xFF35A9E8),
      ),
    ];

QuickAddAction get quickAddMinimalAction => const QuickAddAction(
      kind: QuickAddKind.quickAdd,
      label: 'Quick add',
      description: 'Add with minimal details',
      icon: Icons.auto_awesome,
      semanticLabel: 'Quick add a task',
      tab: 1,
      tint: Color(0xFFE7F3EF),
      iconColor: Color(0xFF147563),
    );

Future<void> openQuickAddCreation(
  BuildContext context,
  QuickAddAction action,
) async {
  switch (action.kind) {
    case QuickAddKind.task:
      final PlannerController planner = _planner(context);
      final bool? saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TaskFormScreen(planner: planner),
        ),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created')),
        );
      }
      return;
    case QuickAddKind.event:
      final PlannerController planner = _planner(context);
      final bool? saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EventFormScreen(planner: planner),
        ),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created')),
        );
      }
      return;
    case QuickAddKind.medicine:
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MedicineFormPage()),
      );
      if (context.mounted) {
        _refreshDashboardQuiet(context);
      }
      return;
    case QuickAddKind.meal:
      final bool? saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AddEditMealScreen()),
      );
      if (saved == true && context.mounted) {
        _refreshDashboardQuiet(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal saved')),
        );
      }
      return;
    case QuickAddKind.habit:
      final HabitsController habits;
      try {
        habits = context.read<HabitsController>();
      } catch (_) {
        assert(false, 'HabitsController missing for Quick Add');
        return;
      }
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HabitsScope(
          controller: habits,
          child: const _HabitSheetHost(),
        ),
      );
      if (context.mounted) {
        _refreshDashboardQuiet(context);
      }
      return;
    case QuickAddKind.health:
      final HealthRepository repository = context.read<HealthRepository>();
      final bool? saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => MeasurementFormScreen(repository: repository),
        ),
      );
      if (saved == true && context.mounted) {
        _refreshDashboardQuiet(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Measurement saved')),
        );
      }
      return;
    case QuickAddKind.expense:
      final FinanceController finance = context.read<FinanceController>();
      if (finance.status == FinanceLoadStatus.idle) {
        await finance.loadAll();
      }
      if (!context.mounted) {
        return;
      }
      final bool? saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FinanceScope(
            controller: finance,
            child: const TransactionFormScreen(),
          ),
        ),
      );
      if (saved == true && context.mounted) {
        _refreshDashboardQuiet(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved')),
        );
      }
      return;
    case QuickAddKind.water:
      final bool? saved = await showModalBottomSheet<bool>(
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
    case QuickAddKind.quickAdd:
      final PlannerController planner = _planner(context);
      final bool? saved = await showDialog<bool>(
        context: context,
        builder: (_) => _MinimalTaskDialog(planner: planner),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created')),
        );
      }
      return;
  }
}

PlannerController _planner(BuildContext context) {
  try {
    return context.read<PlannerController>();
  } catch (_) {
    return AppScope.of(context).planner;
  }
}

void _refreshDashboardQuiet(BuildContext context) {
  Future<void> refresh() async {
    try {
      await AppScope.of(context).dashboard.refresh(
            date: DateTime.now(),
            offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
          );
    } catch (_) {}
  }

  unawaited(refresh());
}

Future<QuickAddAction?> showQuickAdd(BuildContext context) {
  return showGeneralDialog<QuickAddAction?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close quick add',
    barrierColor: const Color(0xFF101828).withValues(alpha: 0.46),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => const _QuickAddDialog(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.08),
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
      duration: const Duration(milliseconds: 340),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<QuickAddAction> actions = quickAddActions;
    final EdgeInsets insets = MediaQuery.viewInsetsOf(context);
    final double availableHeight = MediaQuery.sizeOf(context).height * 0.92;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: const Color(0xFFFCFDFB),
          elevation: 16,
          shadowColor: Colors.black.withValues(alpha: 0.24),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: availableHeight,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 18 + insets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _staggered(
                    index: 0,
                    child: const Text(
                      'What would you like to add?',
                      style: TextStyle(
                        color: Color(0xFF292D33),
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  _staggered(
                    index: 1,
                    child: const Text(
                      'Choose a category to get started',
                      style: TextStyle(
                        color: Color(0xFF7C8799),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _staggered(
                    index: 2,
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 9,
                      crossAxisSpacing: 9,
                      childAspectRatio: 0.72,
                      children: [
                        for (final QuickAddAction action in actions)
                          _CategoryTile(
                            action: action,
                            onTap: () => Navigator.pop(context, action),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _staggered(
                    index: 3,
                    child: _MinimalRow(
                      action: quickAddMinimalAction,
                      onTap: () =>
                          Navigator.pop(context, quickAddMinimalAction),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _staggered(
                    index: 4,
                    child: Semantics(
                      button: true,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F0),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF07594F),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
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
    final double start =
        (index * 0.08).clamp(0.0, 0.68).toDouble();
    final double end = (start + 0.32).clamp(0.0, 1.0).toDouble();
    final Animation<double> animation = CurvedAnimation(
      parent: _stagger,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.action, required this.onTap});

  final QuickAddAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: action.semanticLabel,
      button: true,
      child: Material(
        color: action.tint,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 11, 7, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, color: action.iconColor, size: 31),
                const SizedBox(height: 7),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3D424A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(
                    action.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7C8799),
                      fontSize: 10.5,
                      height: 1.08,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalRow extends StatelessWidget {
  const _MinimalRow({required this.action, required this.onTap});

  final QuickAddAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: action.semanticLabel,
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEFF1EF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: action.iconColor, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.label,
                        style: const TextStyle(
                          color: Color(0xFF3D424A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        action.description,
                        style: const TextStyle(
                          color: Color(0xFF7C8799),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF657083)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimalTaskDialog extends StatefulWidget {
  const _MinimalTaskDialog({required this.planner});

  final PlannerController planner;

  @override
  State<_MinimalTaskDialog> createState() => _MinimalTaskDialogState();
}

class _MinimalTaskDialogState extends State<_MinimalTaskDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.planner.createTask(
        title: _title.text.trim(),
        priority: TaskPriority.medium,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save task. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Quick add'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _title,
            autofocus: true,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Task name',
              hintText: 'What needs to get done?',
            ),
            validator: (String? value) =>
                value == null || value.trim().isEmpty
                    ? 'Enter a task name'
                    : null,
            onFieldSubmitted: (_) => _save(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add task'),
          ),
        ],
      ),
    );
  }
}

class _HabitSheetHost extends StatelessWidget {
  const _HabitSheetHost();

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF6),
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        child: const SingleChildScrollView(child: HabitFormScreen()),
      ),
    );
  }
}

class _WaterQuickLogSheet extends StatefulWidget {
  const _WaterQuickLogSheet();

  @override
  State<_WaterQuickLogSheet> createState() => _WaterQuickLogSheetState();
}

class _WaterQuickLogSheetState extends State<_WaterQuickLogSheet> {
  final TextEditingController _amount = TextEditingController(text: '250');
  WaterUnit _unit = WaterUnit.ml;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final double? parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final DietController controller = context.read<DietController>();
      final bool ok = await controller.addWater(
        amount: parsed,
        unit: _unit.wireName,
      );
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      if (ok) {
        controller.selectDate(DateTime.now());
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              controller.lastActionError ?? 'Could not save water.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save water: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.viewInsetsOf(context).bottom;
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
            const Text(
              'Log water',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Quickly record your water intake.',
              style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Water amount',
                    textField: true,
                    child: TextField(
                      controller: _amount,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                    DropdownMenuItem(value: WaterUnit.ml, child: Text('ml')),
                    DropdownMenuItem(
                      value: WaterUnit.L,
                      child: Text('litres'),
                    ),
                    DropdownMenuItem(
                      value: WaterUnit.glass,
                      child: Text('glasses'),
                    ),
                    DropdownMenuItem(value: WaterUnit.cup, child: Text('cups')),
                  ],
                  onChanged: _saving
                      ? null
                      : (WaterUnit? unit) {
                          if (unit != null) {
                            setState(() => _unit = unit);
                          }
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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
