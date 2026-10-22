/// Finance home: log expenses, track monthly spending, and split costs with
/// friends. Tabs: Overview, Expenses, Friends, Groups.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/money/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/page_header.dart';
import 'finance_controller.dart';
import 'models.dart';
import 'screens/expense_detail_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/expenses_tab.dart';
import 'screens/friend_detail_screen.dart';
import 'screens/friends_tab.dart';
import 'screens/overview_tab.dart';
import 'screens/groups_tab.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<FinanceController>();
      if (controller.status == FinanceLoadStatus.idle) {
        controller.loadAll();
      } else {
        controller.refresh();
      }
    });
  }

  Future<void> _push(Widget screen) async {
    final controller = context.read<FinanceController>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ChangeNotifierProvider.value(value: controller, child: screen),
      ),
    );
    if (saved == true && mounted && screen is ExpenseFormScreen) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense saved')));
    }
  }

  void _addExpense() => _push(const ExpenseFormScreen());

  void _openExpense(Expense e) => _push(ExpenseDetailScreen(expense: e));

  /// The month's spending in the primary currency, as the page title.
  String _title(FinanceController controller) {
    final section = controller.primaryOverview;
    if (controller.overview == null) return 'Finance';
    final spent = (section?.spent ?? Money.zero())
        .display(currencyCode: section?.currency ?? controller.currency);
    return '$spent spent';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FinanceController>();
    final pending = controller.friends.incoming.length;
    final monthName = DateFormat(
      controller.month.year == DateTime.now().year ? 'MMMM' : 'MMMM yyyy',
    ).format(controller.month);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BlistraPageHeader(
              eyebrow: 'Finance · $monthName',
              title: _title(controller),
              actions: [
                _CurrencyButton(controller: controller),
                GlassIconButton(
                  key: const Key('finance-add-expense'),
                  tooltip: 'Add expense',
                  icon: Icons.add_rounded,
                  onTap: _addExpense,
                ),
              ],
            ),
            BlistraSegmentedTabs(
              labels: [
                'Overview',
                'Expenses',
                pending > 0 ? 'Friends ($pending)' : 'Friends',
                'Groups',
              ],
              selected: _tab,
              onSelected: (i) => setState(() => _tab = i),
            ),
            if (_tab < 2) _MonthBar(controller: controller),
            Expanded(child: _body(controller)),
          ],
        ),
      ),
    );
  }

  Widget _body(FinanceController controller) {
    final colors = BlistraColors.resolve(context);
    if (controller.status == FinanceLoadStatus.error &&
        controller.overview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: colors.muted),
              const SizedBox(height: 10),
              Text(
                controller.errorMessage ?? 'Could not load Finance',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: controller.loadAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (controller.overview == null &&
        controller.status != FinanceLoadStatus.error) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: IndexedStack(
        index: _tab,
        children: [
          OverviewTab(
            onOpenFriends: () => setState(() => _tab = 2),
            onAddExpense: _addExpense,
            onOpenExpenses: () => setState(() => _tab = 1),
            onOpenExpense: _openExpense,
          ),
          ExpensesTab(onOpen: _openExpense),
          FriendsTab(
            onOpen: (UserSummary u) =>
                _push(FriendDetailScreen(userId: u.id, initial: u)),
          ),
          const GroupsTab(),
        ],
      ),
    );
  }
}

/// Default-currency picker in the header.
class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Default currency',
      onSelected: controller.setCurrency,
      itemBuilder: (_) => [
        for (final c in FinanceController.commonCurrencies)
          CheckedPopupMenuItem(
            value: c,
            checked: c == controller.currency,
            child: Text(c),
          ),
      ],
      child: const IgnorePointer(
        child: GlassIconButton(
          tooltip: null,
          icon: Icons.currency_exchange_rounded,
          onTap: null,
        ),
      ),
    );
  }
}

/// Month switcher for the Overview and Expenses tabs.
class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.controller});

  final FinanceController controller;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final label = DateFormat('MMMM yyyy').format(controller.month);
    Widget arrow(IconData icon, String tip, VoidCallback? onTap) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 20),
          color: colors.text,
          disabledColor: colors.inkAt(0.25),
          onPressed: onTap,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, kPageGutter, 2),
      child: Row(
        children: [
          arrow(
            Icons.chevron_left_rounded,
            'Previous month',
            () => controller.shiftMonth(-1),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          arrow(
            Icons.chevron_right_rounded,
            'Next month',
            controller.isCurrentMonth ? null : () => controller.shiftMonth(1),
          ),
          const Spacer(),
          Pill(controller.currency),
        ],
      ),
    );
  }
}
