/// Global Quick Add overlay: the single, reusable "+" experience.
///
/// Used from every authenticated screen with the bottom navigation (Home,
/// Planner, Modules, …). Actions route to the owning module's existing
/// creation flow — this overlay never duplicates forms, controllers, or API
/// clients. Presented via [showQuickAdd] with a fade/slide transition,
/// subtle dimming, and staggered action entrance.
library;

import 'package:flutter/material.dart';

/// One Quick Add destination: an existing creation flow in its owning module.
///
/// [tab] is the [AppShell] tab index that owns the flow (1 = Planner,
/// 3 = Modules). The overlay closes first, then [onSelect] fires.
class QuickAddAction {
  const QuickAddAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.semanticLabel,
    required this.tab,
    required this.tint,
    required this.iconColor,
  });

  final String label;
  final String description;
  final IconData icon;
  final String semanticLabel;
  final int tab;
  final Color tint;
  final Color iconColor;
}

/// The supported actions — only flows that actually exist in the app.
List<QuickAddAction> get quickAddActions => const [
        QuickAddAction(
          label: 'Task',
          description: 'Something you need to get done',
          icon: Icons.add_task_outlined,
          semanticLabel: 'Add task',
          tab: 1,
          tint: Color(0xFFE6F6F3),
          iconColor: Color(0xFF0C6B6B),
        ),
        QuickAddAction(
          label: 'Event',
          description: 'Schedule a time-bound commitment',
          icon: Icons.event_outlined,
          semanticLabel: 'Add event',
          tab: 1,
          tint: Color(0xFFEAF2FF),
          iconColor: Color(0xFF2E5AAC),
        ),
        QuickAddAction(
          label: 'Medicine',
          description: 'Record or schedule a medicine',
          icon: Icons.medication_outlined,
          semanticLabel: 'Add medicine',
          tab: 3,
          tint: Color(0xFFEAF5FF),
          iconColor: Color(0xFF3E9BE9),
        ),
        QuickAddAction(
          label: 'Meal',
          description: 'Add a meal or food',
          icon: Icons.restaurant_outlined,
          semanticLabel: 'Add meal',
          tab: 3,
          tint: Color(0xFFEDF9E8),
          iconColor: Color(0xFF3E8E41),
        ),
        QuickAddAction(
          label: 'Water',
          description: 'Log your water intake',
          icon: Icons.water_drop_outlined,
          semanticLabel: 'Add water',
          tab: 3,
          tint: Color(0xFFE8F6FD),
          iconColor: Color(0xFF0E94C9),
        ),
        QuickAddAction(
          label: 'Habit',
          description: 'Create or complete a habit',
          icon: Icons.check_circle_outline,
          semanticLabel: 'Add habit',
          tab: 3,
          tint: Color(0xFFF1EAFE),
          iconColor: Color(0xFF7C3AED),
        ),
        QuickAddAction(
          label: 'Expense',
          description: 'Track money going out',
          icon: Icons.account_balance_wallet_outlined,
          semanticLabel: 'Add expense',
          tab: 3,
          tint: Color(0xFFE9F8F1),
          iconColor: Color(0xFF0C6B6B),
        ),
        QuickAddAction(
          label: 'Health measurement',
          description: 'Log weight, heart-rate and more',
          icon: Icons.monitor_heart_outlined,
          semanticLabel: 'Add health measurement',
          tab: 3,
          tint: Color(0xFFFFECEC),
          iconColor: Color(0xFFE5484D),
        ),
      ];

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
    final today = actions.sublist(2, 6);
    final more = actions.sublist(6);
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
                          onTap: () =>
                              Navigator.pop(context, primary[i]),
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
                  _staggered(
                    index: 4,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 4),
                      child: Text('MORE',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF667085))),
                    ),
                  ),
                  for (int i = 0; i < more.length; i++)
                    _staggered(
                      index: 5 + i,
                      child: _MoreRow(
                        action: more[i],
                        onTap: () =>
                            Navigator.pop(context, more[i]),
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
                child: Icon(action.icon,
                    color: action.iconColor, size: 24),
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
              const Icon(Icons.chevron_right,
                  color: Color(0xFF98A2B3)),
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
                child: Icon(action.icon,
                    color: action.iconColor, size: 20),
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
                            fontSize: 11.5,
                            color: Color(0xFF667085))),
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

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.action, required this.onTap});

  final QuickAddAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: action.semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Row(
            children: [
              Icon(action.icon,
                  color: action.iconColor, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(action.label,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D2939))),
              ),
              const Icon(Icons.chevron_right,
                  size: 19, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}
