import 'package:flutter/material.dart';

import '../../features/app_scope.dart';
import '../dashboard_controller.dart';
import '../models/dashboard_response.dart';
import '../widgets/section_card.dart';

/// Main dashboard screen showing aggregated view across all modules.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final controller = scope.dashboard;
    final authState = scope.authState;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(
          date: DateTime.now(),
          offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        ),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildHeader(context, controller, authState),
            if (controller.isLoading && controller.dashboard == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.dashboard != null)
              _buildDashboardContent(context, controller)
            else if (controller.error != null)
              SliverFillRemaining(
                child: _buildErrorState(context, controller),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    DashboardController controller,
    dynamic authState,
  ) {
    final userEmail = authState.userEmail.isNotEmpty
        ? authState.userEmail
        : 'User';

    return SliverAppBar.large(
      floating: true,
      pinned: true,
      snap: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            userEmail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        if (controller.refreshing)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refresh(
              date: DateTime.now(),
              offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
            ),
          ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              authState.logout();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout),
                title: Text('Logout'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildDashboardContent(
    BuildContext context,
    DashboardController controller,
  ) {
    final dashboard = controller.dashboard!;

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 8),
        _buildSection(
          context,
          title: 'Today',
          child: _buildTodaySection(context, dashboard),
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          title: 'Health',
          child: _buildHealthSection(context, dashboard),
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          title: 'Diet',
          child: _buildDietSection(context, dashboard),
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          title: 'Finance',
          child: _buildFinanceSection(context, dashboard),
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          title: 'Upcoming',
          child: _buildUpcomingSection(context, dashboard),
        ),
        const SizedBox(height: 16),
        _buildQuickActions(context),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTodaySection(BuildContext context, DashboardResponse dashboard) {
    final planner = dashboard.planner;
    final medicines = dashboard.medicines;
    final habits = dashboard.habits;

    if (planner == null && medicines == null && habits == null) {
      return const _EmptySection(message: 'No data for today');
    }

    return Column(
      children: [
        if (planner != null && !planner.unavailable) ...[
          _TodayCard(
            title: 'Tasks',
            overdueCount: planner.overdueTasks.length,
            todayCount: planner.todayTasks.length,
            onTap: () {
              // TODO: Navigate to planner
            },
          ),
        ],
        if (medicines != null && !medicines.unavailable) ...[
          const SizedBox(height: 8),
          _TodayCard(
            title: 'Medicines',
            overdueCount: medicines.dosesRemainingToday,
            todayCount: medicines.dosesTakenToday,
            onTap: () {
              // TODO: Navigate to medicines
            },
            subtitle:
                '${medicines.activeMedicineCount} active • ${medicines.dosesToday.length} doses today',
          ),
        ],
        if (habits != null && !habits.unavailable) ...[
          const SizedBox(height: 8),
          _TodayCard(
            title: 'Habits',
            overdueCount: habits.remainingToday,
            todayCount: habits.completedToday,
            onTap: () {
              // TODO: Navigate to habits
            },
            subtitle:
                '${habits.expectedToday} expected • ${habits.completedToday} done',
          ),
        ],
      ],
    );
  }

  Widget _buildHealthSection(BuildContext context, DashboardResponse dashboard) {
    final health = dashboard.health;

    if (health == null || health.unavailable) {
      return const _EmptySection(message: 'Health data unavailable');
    }

    final measurements = health.latestMeasurements;
    final appointments = health.upcomingAppointments;

    if (measurements.isEmpty && appointments.isEmpty) {
      return const _EmptySection(message: 'No health data recorded yet');
    }

    return Column(
      children: [
        if (measurements.isNotEmpty)
          SectionCard(
            title: 'Latest Measurements',
            child: Column(
              children: measurements.map((m) {
                String display = '${m.type}';
                if (m.value != null) {
                  display += ': ${m.value}';
                  if (m.valueDiastolic != null) {
                    display += '/${m.valueDiastolic}';
                  }
                  if (m.unit != null) display += ' ${m.unit}';
                }
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.monitor_heart, size: 20),
                  title: Text(display),
                  subtitle: m.measuredAt != null
                      ? Text(_formatDateTime(m.measuredAt!))
                      : null,
                );
              }).toList(),
            ),
          ),
        if (appointments.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionCard(
            title: 'Upcoming Appointments',
            child: Column(
              children: appointments.map((a) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: Text(a.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDateTime(a.scheduledAt)),
                      if (a.location != null)
                        Text(a.location!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDietSection(BuildContext context, DashboardResponse dashboard) {
    final diet = dashboard.diet;

    if (diet == null || diet.unavailable) {
      return const _EmptySection(message: 'Diet data unavailable');
    }

    if (diet.mealCount == 0 && diet.waterCount == 0) {
      return const _EmptySection(message: 'No meals or water recorded today');
    }

    return Column(
      children: [
        if (diet.mealCount > 0)
          SectionCard(
            title: 'Meals (${diet.mealCount})',
            child: Column(
              children: diet.meals.map((meal) {
                String subtitle = '';
                if (meal.consumedAt != null) {
                  subtitle = _formatDateTime(meal.consumedAt!);
                }
                if (meal.items.isNotEmpty) {
                  subtitle += ' • ${meal.items.length} item${meal.items.length == 1 ? '' : 's'}';
                }
                return ListTile(
                  dense: true,
                  leading: Icon(
                    meal.type == 'BREAKFAST'
                        ? Icons.free_breakfast
                        : meal.type == 'LUNCH'
                            ? Icons.lunch_dining
                            : meal.type == 'DINNER'
                                ? Icons.dinner_dining
                                : Icons.restaurant,
                    size: 20,
                  ),
                  title: Text(meal.type ?? 'Meal'),
                  subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                );
              }).toList(),
            ),
          ),
        if (diet.waterCount > 0) ...[
          const SizedBox(height: 8),
          SectionCard(
            title: 'Water (${diet.waterCount})',
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.water_drop, size: 20, color: Colors.blue),
                  title: Text(
                    diet.waterTotalMilliliters != null
                        ? '${diet.waterTotalMilliliters} ml'
                        : '${diet.waterCount} entries',
                  ),
                  subtitle: diet.nutrition != null
                      ? Text('Calories: ${diet.nutrition!.caloriesKcal?.total ?? '—'} kcal')
                      : null,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFinanceSection(BuildContext context, DashboardResponse dashboard) {
    final finance = dashboard.finance;

    if (finance == null || finance.unavailable) {
      return const _EmptySection(message: 'Finance data unavailable');
    }

    if (finance.currencies.isEmpty) {
      return const _EmptySection(message: 'No financial data for this period');
    }

    return SectionCard(
      title: 'Summary (${_formatDate(finance.from)} – ${_formatDate(finance.to)})',
      child: Column(
        children: finance.currencies.map((currency) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currency.currency,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _FinanceStat(
                      label: 'Income',
                      value: currency.income,
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _FinanceStat(
                      label: 'Expense',
                      value: currency.expense,
                      color: Colors.red,
                    ),
                  ),
                  Expanded(
                    child: _FinanceStat(
                      label: 'Net',
                      value: currency.net,
                      color: double.tryParse(currency.net) != null &&
                              double.parse(currency.net) >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
              if (currency.topCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Top categories:',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: currency.topCategories.take(3).map((cat) {
                    return Chip(
                      label: Text('${cat.categoryName}: ${cat.amount}'),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
              if (currency != finance.currencies.last) const Divider(height: 24),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUpcomingSection(BuildContext context, DashboardResponse dashboard) {
    final planner = dashboard.planner;
    final health = dashboard.health;

    final events = <Widget>[];

    if (planner != null && !planner.unavailable) {
      for (final event in planner.todayEvents) {
        events.add(
          ListTile(
            dense: true,
            leading: const Icon(Icons.event, size: 20),
            title: Text(event.title),
            subtitle: Text(_formatDateTime(event.startAt)),
          ),
        );
      }
    }

    if (health != null && !health.unavailable) {
      for (final appt in health.upcomingAppointments) {
        events.add(
          ListTile(
            dense: true,
            leading: const Icon(Icons.medical_services, size: 20),
            title: Text(appt.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDateTime(appt.scheduledAt)),
                if (appt.location != null)
                  Text(appt.location!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        );
      }
    }

    if (events.isEmpty) {
      return const _EmptySection(message: 'Nothing upcoming');
    }

    return SectionCard(title: 'Upcoming', child: Column(children: events));
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.add_task,
        label: 'Add Task',
        onTap: () {
          // TODO: Navigate to task creation
        },
      ),
      _QuickAction(
        icon: Icons.medication,
        label: 'Log Dose',
        onTap: () {
          // TODO: Navigate to medicine dose
        },
      ),
      _QuickAction(
        icon: Icons.check_circle,
        label: 'Log Habit',
        onTap: () {
          // TODO: Navigate to habit
        },
      ),
      _QuickAction(
        icon: Icons.restaurant,
        label: 'Add Meal',
        onTap: () {
          // TODO: Navigate to meal
        },
      ),
      _QuickAction(
        icon: Icons.water_drop,
        label: 'Add Water',
        onTap: () {
          // TODO: Navigate to water
        },
      ),
      _QuickAction(
        icon: Icons.monitor_heart,
        label: 'Log Health',
        onTap: () {
          // TODO: Navigate to health
        },
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet,
        label: 'Add Expense',
        onTap: () {
          // TODO: Navigate to finance
        },
      ),
    ];

    return SectionCard(
      title: 'Quick Actions',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions.map((action) {
          return ActionChip(
            avatar: Icon(action.icon, size: 18),
            label: Text(action.label),
            onPressed: action.onTap,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DashboardController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              controller.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => controller.refresh(
                date: DateTime.now(),
                offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dateTimeLocal(dt)}';
    } catch (_) {
      return isoString;
    }
  }

  String dateTimeLocal(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.title,
    required this.overdueCount,
    required this.todayCount,
    this.subtitle,
    required this.onTap,
  });

  final String title;
  final int overdueCount;
  final int todayCount;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (overdueCount > 0)
                    _CountBadge(
                      label: 'Overdue',
                      count: overdueCount,
                      color: Colors.red,
                    ),
                  if (overdueCount > 0) const SizedBox(height: 4),
                  _CountBadge(
                    label: 'Today',
                    count: todayCount,
                    color: overdueCount > 0 ? Theme.of(context).colorScheme.primary : Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FinanceStat extends StatelessWidget {
  const _FinanceStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}