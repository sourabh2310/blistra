/// Finance home shell: bottom navigation, month navigation and shared
/// loading / error states.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'finance_controller.dart';
import 'finance_scope.dart';

import 'screens/accounts_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/overview_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/transfers_screen.dart';

class FinanceHome extends StatefulWidget {
  const FinanceHome({super.key});

  @override
  State<FinanceHome> createState() => _FinanceHomeState();
}

class _FinanceHomeState extends State<FinanceHome> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final FinanceController controller = FinanceScope.of(context);
      if (controller.status == FinanceLoadStatus.idle) {
        controller.loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle(controller)),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(controller, -1),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftMonth(controller, 1),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: controller.isLoading ? null : controller.loadAll,
          ),
        ],
      ),
      body: _body(controller),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (int index) =>
            setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_vert_outlined),
            selectedIcon: Icon(Icons.swap_vert),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.currency_exchange_outlined),
            selectedIcon: Icon(Icons.currency_exchange),
            label: 'Transfers',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
        ],
      ),
    );
  }

  Widget _body(FinanceController controller) {
    if (controller.status == FinanceLoadStatus.error &&
        controller.accounts.isEmpty) {
      return _ErrorState(
        message: controller.errorMessage ??
            'Failed to load your finance data',
        onRetry: controller.loadAll,
      );
    }
    if (controller.status == FinanceLoadStatus.loading &&
        controller.accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: controller.loadMonthData,
      child: IndexedStack(
        index: _tabIndex,
        children: const [
          OverviewScreen(),
          TransactionsScreen(),
          TransfersScreen(),
          AccountsScreen(),
          CategoriesScreen(),
        ],
      ),
    );
  }

  String _appBarTitle(FinanceController controller) {
    final DateFormat month = DateFormat('MMMM yyyy');
    switch (_tabIndex) {
      case 0:
        return 'Overview · ${month.format(controller.from)}';
      case 1:
        return 'Transactions · ${month.format(controller.from)}';
      case 2:
        return 'Transfers · ${month.format(controller.from)}';
      case 3:
        return 'Accounts';
      case 4:
        return 'Categories';
      default:
        return 'Blistra';
    }
  }

  void _shiftMonth(FinanceController controller, int delta) {
    final DateTime from = DateTime(
      controller.from.year,
      controller.from.month + delta,
    );
    final DateTime to = DateTime(from.year, from.month + 1, 0);
    controller.setRange(from, to);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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