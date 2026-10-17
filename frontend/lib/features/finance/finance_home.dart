/// Finance home: log expenses, track monthly spending, and split costs with
/// friends. Tabs: Overview, Expenses, Friends.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/page_header.dart';
import 'finance_controller.dart';
import 'models.dart';
import 'screens/expense_detail_screen.dart';
import 'screens/expense_form_screen.dart';
import 'screens/expenses_tab.dart';
import 'screens/friend_detail_screen.dart';
import 'screens/friends_tab.dart';
import 'screens/overview_tab.dart';

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
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: controller, child: screen),
    ));
    if (saved == true && mounted && screen is ExpenseFormScreen) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense saved')));
    }
  }

  void _addExpense() => _push(const ExpenseFormScreen());

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FinanceController>();
    final pending = controller.friends.incoming.length;
    final monthLabel = DateFormat('MMMM yyyy').format(controller.month);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BlistraPageHeader(
              title: 'Finance',
              subtitle: _tab == 2 ? 'Split costs with friends' : 'Track spending and split costs',
              actions: [
                GlassIconButton(
                  key: const Key('finance-add-expense'),
                  tooltip: 'Add expense',
                  icon: Icons.add_rounded,
                  onTap: _addExpense,
                ),
              ],
            ),
            BlistraSegmentedTabs(
              labels: ['Overview', 'Expenses', pending > 0 ? 'Friends ($pending)' : 'Friends'],
              selected: _tab,
              onSelected: (i) => setState(() => _tab = i),
            ),
            if (_tab != 2) _MonthBar(controller: controller, label: monthLabel),
            Expanded(child: _body(controller)),
          ],
        ),
      ),
    );
  }

  Widget _body(FinanceController controller) {
    if (controller.status == FinanceLoadStatus.error && controller.overview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 10),
              Text(controller.errorMessage ?? 'Could not load Finance', textAlign: TextAlign.center),
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
    if (controller.overview == null && controller.status != FinanceLoadStatus.error) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: IndexedStack(
        index: _tab,
        children: [
          OverviewTab(onOpenFriends: () => setState(() => _tab = 2), onAddExpense: _addExpense),
          ExpensesTab(onOpen: (Expense e) => _push(ExpenseDetailScreen(expense: e))),
          FriendsTab(onOpen: (UserSummary u) => _push(FriendDetailScreen(userId: u.id, initial: u))),
        ],
      ),
    );
  }
}

/// Month switcher and default-currency picker for the Overview and Expenses tabs.
class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.controller, required this.label});

  final FinanceController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => controller.shiftMonth(-1),
          ),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: controller.isCurrentMonth ? null : () => controller.shiftMonth(1),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Default currency',
            onSelected: controller.setCurrency,
            itemBuilder: (_) => [
              for (final c in FinanceController.commonCurrencies)
                CheckedPopupMenuItem(value: c, checked: c == controller.currency, child: Text(c)),
            ],
            child: Chip(
              avatar: const Icon(Icons.currency_exchange_rounded, size: 16),
              label: Text(controller.currency),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
