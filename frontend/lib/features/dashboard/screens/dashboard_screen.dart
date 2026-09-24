import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../models/dashboard_response.dart';

/// Homepage replica of Homepage.png — Blistra "Everything you need. One app."
///
/// Every business value on this screen is derived from the authenticated
/// user's backend dashboard payload ([DashboardResponse], scoped server-side
/// to the JWT identity). Missing data renders an explicit empty state —
/// never a hardcoded fallback number, name, or schedule entry.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigate});

  /// Navigate to a primary tab: 0 Home, 1 Planner, 2 Add, 3 Modules, 4 Profile.
  final void Function(int tabIndex)? onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _teal = Color(0xFF0C6B6B);

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.dashboard, scope.authState]),
      builder: (context, _) {
        final controller = scope.dashboard;
        final email = scope.authState.userEmail;
        final dashboard = controller.dashboard;
        final name = resolveDisplayName(user: dashboard?.user, email: email);
        final now = DateTime.now();
        return Scaffold(
          backgroundColor: const Color(0xFFFFFBF6),
          floatingActionButton: _QuickAddFab(
            onTap: () => _openQuickAdd(context),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endFloat,
          body: RefreshIndicator(
            color: _teal,
            onRefresh: () => controller.refresh(
              date: DateTime.now(),
              offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _TopBar(displayName: name),
                  _GreetingHeader(name: name, now: now),
                  const SizedBox(height: 6),
                  _DayAtAGlanceCard(
                      dashboard: dashboard, now: now),
                  const SizedBox(height: 14),
                  _ModuleGrid(
                    dashboard: dashboard,
                    now: now,
                    onNavigate: widget.onNavigate,
                  ),
                  const SizedBox(height: 18),
                  _TimelineSection(
                    dashboard: dashboard,
                    now: now,
                    onNavigate: widget.onNavigate,
                  ),
                  if (controller.isLoading && dashboard == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(color: _teal),
                      ),
                    ),
                  if (controller.error != null && dashboard == null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        controller.error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Space for FAB overlap + bottom nav.
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openQuickAdd(BuildContext context) {
    final scope = AppScope.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _QuickAddSheet(
        onNavigate: widget.onNavigate,
        onRefresh: () => scope.dashboard.refresh(
          date: DateTime.now(),
          offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        ),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final initials = initialsForName(displayName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blistra',
                      style: TextStyle(
                        fontSize: 42,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: Color(0xFF0C6B6B),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 2, left: 2),
                      child: Icon(Icons.auto_awesome,
                          size: 20, color: Color(0xFF2AA198)),
                    ),
                  ],
                ),
                Text(
                  'Everything you need. One app.',
                  style:
                      TextStyle(fontSize: 14.5, color: Color(0xFF8A94A6)),
                ),
              ],
            ),
          ),
          _IconCircle(icon: Icons.search, onTap: () {}),
          const SizedBox(width: 10),
          _IconCircle(
              icon: Icons.notifications_none_outlined,
              dot: true,
              onTap: () {}),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: const Color(0xFFE3F0F0), width: 2),
              color: const Color(0xFFF3D9C8),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: Color(0xFF5B3A29))),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, this.dot = false, this.onTap});

  final IconData icon;
  final bool dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F4F6),
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            Center(
                child: Icon(icon, size: 24, color: Color(0xFF3E4A5A))),
            if (dot)
              const Positioned(
                right: 11,
                top: 10,
                child: CircleAvatar(
                    radius: 5, backgroundColor: Color(0xFFE5484D)),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Greeting + illustration ──────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name, required this.now});

  final String name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final greeting = greetingForHour(now.hour);
    final dateLine = DateFormat('EEEE, d MMMM').format(now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 0, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('$greeting,',
                    style: const TextStyle(
                        fontSize: 19, color: Color(0xFFC4C9D4))),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: Color(0xFF101828),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋', style: TextStyle(fontSize: 30)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateLine,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667085)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A healthier, happier and more organized you is a step closer today.',
                  style: TextStyle(
                      fontSize: 15, height: 1.35, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          const Expanded(flex: 4, child: _HeroArt()),
        ],
      ),
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(90),
          bottomLeft: Radius.circular(90),
        ),
        child: CustomPaint(
          painter: _HillsPainter(),
          child: const Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(top: 18, right: 26),
              child: Text(
                'Small\nsteps,\nbig changes.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                  height: 1.15,
                  color: Color(0xFF3E5A5A),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFDCEBE6),
    );
    // Sun
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.42),
      26,
      Paint()..color = const Color(0xFFF2D38A),
    );
    // Hills
    final hills = [
      _Hill(const Color(0xFFCFE0D8), 0.30),
      _Hill(const Color(0xFFA9CFC0), 0.48),
      _Hill(const Color(0xFF7FB5A3), 0.62),
      _Hill(const Color(0xFF4E8D7E), 0.76),
    ];
    for (final h in hills) {
      final path = Path()
        ..moveTo(0, size.height)
        ..lineTo(0, size.height * h.y)
        ..quadraticBezierTo(size.width * 0.35,
            size.height * (h.y - 0.14), size.width * 0.7, size.height * h.y)
        ..quadraticBezierTo(size.width * 0.9,
            size.height * (h.y + 0.05), size.width, size.height * (h.y - 0.04))
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = h.color);
    }
    // Leaves
    final leaf = Paint()..color = const Color(0xFF35655A);
    for (int i = 0; i < 5; i++) {
      final x = size.width - 14 - i * 3.0;
      final y = size.height - 18 - i * 22.0;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 14, height: 30),
          leaf);
    }
    for (int i = 0; i < 4; i++) {
      final x = 14 + i * 12.0;
      final y = size.height - 8 - i * 7.0;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 22, height: 12),
          leaf);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Hill {
  const _Hill(this.color, this.y);
  final Color color;
  final double y;
}

// ─── Day at a glance ──────────────────────────────────────

class _DayAtAGlanceCard extends StatelessWidget {
  const _DayAtAGlanceCard({required this.dashboard, required this.now});

  final DashboardResponse? dashboard;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final progress = computeDayProgress(dashboard, now: now);
    final pct = progress.pct ?? 0.0;
    final attentionLine = progress.isEmpty
        ? 'Nothing scheduled yet'
        : progress.attention == 0
            ? "You're all caught up"
            : '${progress.attention} thing${progress.attention == 1 ? '' : 's'} need${progress.attention == 1 ? 's' : ''} your attention';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E6E6E), Color(0xFF0A4E4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18, color: Color(0xFF7DF0DD)),
                    SizedBox(width: 8),
                    Text('Your day at a glance',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right,
                        color: Colors.white, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  progress.status,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4),
                ),
                const SizedBox(height: 4),
                Text(progress.label,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 2),
                Text(attentionLine,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 12,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.18),
                          valueColor: const AlwaysStoppedAnimation(
                              _DayAtAGlanceCardMint.mint),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                        progress.isEmpty
                            ? '—'
                            : '${(pct * 100).round()}%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 130,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white.withValues(alpha: 0.22),
          ),
          const Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 26),
                Text(
                  '"A more balanced you, every day."',
                  style: TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.3),
                ),
                SizedBox(height: 10),
                Icon(Icons.spa_outlined,
                    color: Color(0xFF8FE3C8), size: 34),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayAtAGlanceCardMint {
  static const mint = Color(0xFF5EEAD4);
}

// ─── Module grid ──────────────────────────────────────────

class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid(
      {required this.dashboard,
      required this.now,
      required this.onNavigate});

  final DashboardResponse? dashboard;
  final DateTime now;
  final void Function(int tabIndex)? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _healthTile(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _medicinesTile(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _dietTile(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _habitsTile(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _plannerTile(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _financeTile(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Health: latest WEIGHT + HEART_RATE measurements; steps unavailable ──

  MeasurementSummary? _measurement(String type) {
    final list = dashboard?.health?.latestMeasurements ?? const [];
    for (final m in list) {
      if (m.type.toUpperCase() == type) return m;
    }
    return null;
  }

  Widget _healthTile() {
    final health = dashboard?.health;
    final weight = _measurement('WEIGHT');
    MeasurementSummary? heart;
    for (final m
        in health?.latestMeasurements ?? const <MeasurementSummary>[]) {
      final t = m.type.toUpperCase();
      if (t.contains('HEART') || t.contains('PULSE')) {
        heart = m;
        break;
      }
    }
    final hasHealth = health != null && !health.unavailable;
    final subtitle = !hasHealth
        ? 'No health data'
        : weight?.value != null
            ? '${weight!.value}${weight.unit != null && weight.unit!.isNotEmpty ? ' ${weight.unit}' : ''}'
            : 'No weight recorded';
    return _Tile(
      color: const Color(0xFFFFECEC),
      icon: Icons.favorite,
      iconBg: const Color(0xFFFFD9D9),
      iconColor: const Color(0xFFE5484D),
      title: 'Health',
      subtitle: subtitle,
      onTap: () => onNavigate?.call(3),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        weight?.value != null
                            ? _shortNumber(weight!.value!)
                            : '—',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(
                        weight?.unit?.isNotEmpty == true
                            ? weight!.unit!
                            : 'weight',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF667085))),
                  ],
                ),
              ),
              Container(
                  width: 1,
                  height: 30,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFFE5D5D5)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite,
                            color: Color(0xFFE5484D), size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                              heart?.value != null
                                  ? _shortNumber(heart!.value!)
                                  : '—',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    Text(
                        heart?.value != null
                            ? 'bpm'
                            : 'No heart-rate data',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF667085))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Text('👟', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Expanded(
                child: Text('Steps unavailable',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF667085))),
              ),
            ],
          ),
          if (!hasHealth || weight?.value == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Add measurement',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5484D))),
            ),
        ],
      ),
    );
  }

  // ── Medicines: today's doses + next upcoming dose ──

  Widget _medicinesTile() {
    final meds = dashboard?.medicines;
    final available = meds != null && !meds.unavailable;
    final doses = available ? meds.dosesToday : const <DoseSummary>[];
    if (!available || doses.isEmpty) {
      return _Tile(
        color: const Color(0xFFEAF5FF),
        icon: Icons.medication,
        iconBg: Colors.white,
        iconColor: const Color(0xFF3E9BE9),
        title: 'Medicines',
        subtitle: 'No medicines scheduled',
        onTap: () => onNavigate?.call(3),
        body: const Text('No medicines scheduled',
            style: TextStyle(
                fontSize: 13, color: Color(0xFF3E5A6B))),
      );
    }
    final taken =
        doses.where((d) => d.status.toUpperCase() == 'TAKEN').length;
    final total = doses.length;
    final remaining = total - taken;
    final next = _nextDose(doses);
    final subtitle = remaining == 0
        ? 'All doses completed'
        : '$remaining dose${remaining == 1 ? '' : 's'} left today';
    return _Tile(
      color: const Color(0xFFEAF5FF),
      icon: Icons.medication,
      iconBg: Colors.white,
      iconColor: const Color(0xFF3E9BE9),
      title: 'Medicines',
      subtitle: subtitle,
      onTap: () => onNavigate?.call(3),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: _DoseDots(done: taken, total: total)),
              Text('$taken/$total',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E5A6B))),
            ],
          ),
          const SizedBox(height: 8),
          if (next != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Next: ${next.medicineName}',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF3E5A6B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(_formatTime(next.scheduledAt),
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF3E5A6B))),
              ],
            )
          else
            const Text('All doses completed',
                style: TextStyle(
                    fontSize: 12.5, color: Color(0xFF3E5A6B))),
        ],
      ),
    );
  }

  DoseSummary? _nextDose(List<DoseSummary> doses) {
    DoseSummary? best;
    DateTime? bestAt;
    for (final d in doses) {
      final s = d.status.toUpperCase();
      if (s == 'TAKEN' || s == 'CANCELLED' || s == 'SKIPPED') continue;
      final at = DateTime.tryParse(d.scheduledAt);
      if (at == null) continue;
      if (at.isBefore(now)) continue;
      if (bestAt == null || at.isBefore(bestAt)) {
        bestAt = at;
        best = d;
      }
    }
    return best;
  }

  // ── Diet: today's logged calories + macros (no invented target) ──

  Widget _dietTile() {
    final diet = dashboard?.diet;
    final available = diet != null && !diet.unavailable;
    final kcalTotal = available ? diet.nutrition?.caloriesKcal?.total : null;
    final kcalItems =
        available ? diet.nutrition?.caloriesKcal?.recordedItems ?? 0 : 0;
    final hasFood = available &&
        (diet.mealCount > 0 || (kcalTotal != null && kcalItems > 0));
    if (!hasFood) {
      return _Tile(
        color: const Color(0xFFEDF9E8),
        icon: Icons.ramen_dining,
        iconBg: const Color(0xFFD9F0D2),
        iconColor: const Color(0xFF3E8E41),
        title: 'Diet',
        subtitle: 'No meals logged today',
        onTap: () => onNavigate?.call(3),
        body: const Text('Log meal',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3E8E41))),
      );
    }
    final kcalLabel = kcalTotal != null && kcalItems > 0
        ? '${_shortNumber(kcalTotal)} kcal logged'
        : '${diet.mealCount} meal${diet.mealCount == 1 ? '' : 's'} logged';
    return _Tile(
      color: const Color(0xFFEDF9E8),
      icon: Icons.ramen_dining,
      iconBg: const Color(0xFFD9F0D2),
      iconColor: const Color(0xFF3E8E41),
      title: 'Diet',
      subtitle: kcalLabel,
      onTap: () => onNavigate?.call(3),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Macro(
              dot: const Color(0xFF4CAF50),
              label: _macroLabel(diet.nutrition?.proteinG)),
          _Macro(
              dot: const Color(0xFFFF9800),
              label: _macroLabel(diet.nutrition?.carbohydratesG)),
          _Macro(
              dot: const Color(0xFFC6A700),
              label: _macroLabel(diet.nutrition?.fatG)),
        ],
      ),
    );
  }

  String _macroLabel(MacroSummary? macro) {
    if (macro == null ||
        macro.recordedItems == 0 ||
        macro.total == null) {
      return '—';
    }
    return '${_shortNumber(macro.total!)}g';
  }

  // ── Habits: today's occurrences, dots mirror real completion ──

  Widget _habitsTile() {
    final habits = dashboard?.habits;
    final available = habits != null && !habits.unavailable;
    final total = available ? habits.expectedToday : 0;
    final done = available ? habits.completedToday : 0;
    if (!available || total == 0) {
      return _Tile(
        color: const Color(0xFFF1EAFE),
        icon: Icons.adjust,
        iconBg: const Color(0xFFDCCBFF),
        iconColor: const Color(0xFF7C3AED),
        title: 'Habits',
        subtitle: 'No habits scheduled today',
        onTap: () => onNavigate?.call(3),
        body: const Text('Add habit',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7C3AED))),
      );
    }
    final todayHabits = habits.todayHabits;
    final List<bool> states = todayHabits.isNotEmpty
        ? todayHabits.map((h) => h.completedToday).toList()
        : List<bool>.generate(total, (i) => i < done);
    return _Tile(
      color: const Color(0xFFF1EAFE),
      icon: Icons.adjust,
      iconBg: const Color(0xFFDCCBFF),
      iconColor: const Color(0xFF7C3AED),
      title: 'Habits',
      subtitle: '$done of $total completed',
      onTap: () => onNavigate?.call(3),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final s in states) _HabitDot(done: s)],
      ),
    );
  }

  // ── Planner: real upcoming events ──

  Widget _plannerTile() {
    final planner = dashboard?.planner;
    final available = planner != null && !planner.unavailable;
    final events = available ? planner.todayEvents : const <EventSummary>[];
    final upcoming = events.where((e) {
      final start = DateTime.tryParse(e.startAt);
      final end =
          e.endAt != null ? DateTime.tryParse(e.endAt!) : null;
      if (end != null) return !end.isBefore(now);
      if (start != null) return !start.isBefore(now);
      return true;
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (!available || events.isEmpty) {
      return _Tile(
        color: const Color(0xFFFFF4E3),
        icon: Icons.calendar_month,
        iconBg: const Color(0xFFFFE3B3),
        iconColor: const Color(0xFFE8890C),
        title: 'Planner',
        subtitle: 'No upcoming events',
        onTap: () => onNavigate?.call(1),
        body: const Text('Nothing scheduled',
            style: TextStyle(
                fontSize: 13, color: Color(0xFF667085))),
      );
    }
    final shown = upcoming.isEmpty ? events : upcoming;
    final countLabel = upcoming.isEmpty
        ? '${events.length} event${events.length == 1 ? '' : 's'} today'
        : '${upcoming.length} upcoming event${upcoming.length == 1 ? '' : 's'}';
    const dots = [Color(0xFF12B5CB), Color(0xFF7C3AED)];
    return _Tile(
      color: const Color(0xFFFFF4E3),
      icon: Icons.calendar_month,
      iconBg: const Color(0xFFFFE3B3),
      iconColor: const Color(0xFFE8890C),
      title: 'Planner',
      subtitle: countLabel,
      onTap: () => onNavigate?.call(1),
      body: Column(
        children: [
          for (int i = 0; i < shown.take(2).length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _PlannerRow(
              dot: dots[i % dots.length],
              label: shown[i].title,
              time: _formatTime(shown[i].startAt),
            ),
          ],
        ],
      ),
    );
  }

  // ── Finance: current-month income/expense (no invented budget) ──

  Widget _financeTile() {
    final finance = dashboard?.finance;
    final available = finance != null && !finance.unavailable;
    final currencies =
        available ? finance.currencies : const <CurrencySection>[];
    final active = currencies.where((c) {
      final income = double.tryParse(c.income) ?? 0;
      final expense = double.tryParse(c.expense) ?? 0;
      return income != 0 || expense != 0;
    }).toList();
    if (!available || active.isEmpty) {
      return _Tile(
        color: const Color(0xFFE9F8F1),
        icon: Icons.account_balance_wallet,
        iconBg: const Color(0xFFC9EBDD),
        iconColor: const Color(0xFF0C6B6B),
        title: 'Finance',
        subtitle: 'No transactions yet',
        onTap: () => onNavigate?.call(3),
        body: const Text('No transactions yet',
            style: TextStyle(
                fontSize: 13, color: Color(0xFF3E5A5A))),
      );
    }
    final c = active.first;
    final symbol = _currencySymbol(c.currency);
    final expense = _shortNumber(c.expense);
    final income = _shortNumber(c.income);
    return _Tile(
      color: const Color(0xFFE9F8F1),
      icon: Icons.account_balance_wallet,
      iconBg: const Color(0xFFC9EBDD),
      iconColor: const Color(0xFF0C6B6B),
      title: 'Finance',
      subtitle: 'Spent this month',
      onTap: () => onNavigate?.call(3),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$symbol$expense',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                Text('$symbol$income income',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF3E5A5A))),
              ],
            ),
          ),
          _MiniBars(values: _categoryBars(c)),
        ],
      ),
    );
  }

  List<double> _categoryBars(CurrencySection c) {
    final amounts = c.topCategories
        .map((t) => double.tryParse(t.amount) ?? 0)
        .where((v) => v > 0)
        .take(5)
        .toList();
    if (amounts.isEmpty) return const [];
    final max = amounts.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return const [];
    return amounts.map((v) => (v / max * 38).clamp(8.0, 38.0)).toList();
  }
}

String _shortNumber(String raw) {
  final v = double.tryParse(raw.replaceAll(',', ''));
  if (v == null) return raw;
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}

String _formatTime(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return DateFormat('h:mm a').format(dt);
}

String _currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'INR':
      return '₹';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    default:
      return code.isEmpty ? '' : '$code ';
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.color,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.body,
    this.onTap,
  });

  final Color color;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF3E5A6B))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFF5B6B7B)),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

class _DoseDots extends StatelessWidget {
  const _DoseDots({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final n = total.clamp(1, 5);
    return Row(
      children: [
        for (int i = 0; i < n; i++) ...[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done
                  ? const Color(0xFF12A5A5)
                  : Colors.white,
              border: Border.all(
                  color: const Color(0xFFB9D6E4)),
            ),
          ),
          if (i < n - 1)
            Expanded(
              child: Container(
                  height: 5,
                  color: i < done - 1
                      ? const Color(0xFF12A5A5)
                      : Colors.white),
            ),
        ],
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.dot, required this.label});
  final Color dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    String letter = 'P';
    if (dot == const Color(0xFFFF9800)) letter = 'C';
    if (dot == const Color(0xFFC6A700)) letter = 'F';
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration:
              BoxDecoration(color: dot, shape: BoxShape.circle),
          child: Center(
              child: Text(letter,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white))),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}

class _HabitDot extends StatelessWidget {
  const _HabitDot({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? const Color(0xFF12A5A5) : Colors.transparent,
        border: Border.all(
            color: done
                ? const Color(0xFF12A5A5)
                : const Color(0xFFB9AEE0),
            width: 1.6),
      ),
      child: done
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}

class _PlannerRow extends StatelessWidget {
  const _PlannerRow(
      {required this.dot, required this.label, required this.time});
  final Color dot;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
        Text(time,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF667085))),
      ],
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({this.values = const []});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final v in values)
          Container(
            width: 8,
            height: v,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2EC4B6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

// ─── Timeline (merged real schedule, sorted ASC) ────────────────────

enum TimelineStatus {
  upcoming,
  due,
  completed,
  missed,
  overdue,
  cancelled,
}

class TimelineItem {
  TimelineItem({
    required this.at,
    required this.title,
    required this.meta,
    required this.status,
  });

  final DateTime at;
  final String title;
  final String meta;
  final TimelineStatus status;

  bool get done => status == TimelineStatus.completed;
}

List<TimelineItem> buildTimeline(DashboardResponse? dashboard,
    {required DateTime now, int limit = 5}) {
  if (dashboard == null) return const [];
  final items = <TimelineItem>[];

  final planner = dashboard.planner;
  if (planner != null && !planner.unavailable) {
    for (final e in planner.todayEvents) {
      final start = DateTime.tryParse(e.startAt);
      if (start == null) continue;
      final end =
          e.endAt != null ? DateTime.tryParse(e.endAt!) : null;
      items.add(TimelineItem(
        at: start,
        title: e.title,
        meta: end != null
            ? '${_formatTime(e.startAt)} – ${_formatTime(e.endAt)}'
            : _formatTime(e.startAt),
        status: _eventStatus(start, end, now),
      ));
    }
    for (final t in planner.todayTasks) {
      final s = (t.status ?? '').toUpperCase();
      if (s == 'CANCELLED') continue;
      final due =
          t.dueAt != null ? DateTime.tryParse(t.dueAt!) : null;
      if (due == null) continue;
      items.add(TimelineItem(
        at: due,
        title: t.title,
        meta: _formatTime(t.dueAt),
        status: s == 'COMPLETED'
            ? TimelineStatus.completed
            : due.isBefore(now)
                ? TimelineStatus.overdue
                : TimelineStatus.upcoming,
      ));
    }
    for (final t in planner.overdueTasks) {
      final s = (t.status ?? '').toUpperCase();
      if (s == 'COMPLETED' || s == 'CANCELLED') continue;
      final due =
          t.dueAt != null ? DateTime.tryParse(t.dueAt!) : null;
      if (due == null) continue;
      items.add(TimelineItem(
        at: due,
        title: t.title,
        meta: 'Overdue · ${_formatTime(t.dueAt)}',
        status: TimelineStatus.overdue,
      ));
    }
  }

  final meds = dashboard.medicines;
  if (meds != null && !meds.unavailable) {
    for (final d in meds.dosesToday) {
      final at = DateTime.tryParse(d.scheduledAt);
      if (at == null) continue;
      final s = d.status.toUpperCase();
      items.add(TimelineItem(
        at: at,
        title: d.medicineName,
        meta: 'Medicine · ${_formatTime(d.scheduledAt)}',
        status: s == 'TAKEN'
            ? TimelineStatus.completed
            : s == 'CANCELLED' || s == 'SKIPPED'
                ? TimelineStatus.cancelled
                : at.isBefore(now)
                    ? TimelineStatus.missed
                    : at.difference(now).inMinutes <= 60
                        ? TimelineStatus.due
                        : TimelineStatus.upcoming,
      ));
    }
  }

  final diet = dashboard.diet;
  if (diet != null && !diet.unavailable) {
    for (final m in diet.meals) {
      if (m.consumedAt == null) continue;
      final at = DateTime.tryParse(m.consumedAt!);
      if (at == null) continue;
      items.add(TimelineItem(
        at: at,
        title: _mealTitle(m.type),
        meta: 'Meal · ${_formatTime(m.consumedAt)}',
        status: TimelineStatus.completed,
      ));
    }
  }

  final health = dashboard.health;
  if (health != null && !health.unavailable) {
    for (final a in health.upcomingAppointments) {
      final at = DateTime.tryParse(a.scheduledAt);
      if (at == null) continue;
      // Timeline shows today only; appointments span 30 days.
      if (at.year != now.year ||
          at.month != now.month ||
          at.day != now.day) {
        continue;
      }
      final s = (a.status ?? '').toUpperCase();
      items.add(TimelineItem(
        at: at,
        title: a.title,
        meta: 'Appointment · ${_formatTime(a.scheduledAt)}',
        status: s == 'COMPLETED'
            ? TimelineStatus.completed
            : s == 'CANCELLED'
                ? TimelineStatus.cancelled
                : at.isBefore(now)
                    ? TimelineStatus.overdue
                    : TimelineStatus.upcoming,
      ));
    }
  }

  items.sort((a, b) => a.at.compareTo(b.at));
  return items.take(limit).toList();
}

TimelineStatus _eventStatus(
    DateTime start, DateTime? end, DateTime now) {
  final finish = end ?? start;
  if (finish.isBefore(now)) return TimelineStatus.completed;
  if (start.difference(now).inMinutes <= 60 && !start.isAfter(now)) {
    return TimelineStatus.due;
  }
  if (start.isBefore(now)) return TimelineStatus.due;
  return TimelineStatus.upcoming;
}

String _mealTitle(String? type) {
  if (type == null || type.isEmpty) return 'Meal';
  final lower = type.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection(
      {required this.dashboard,
      required this.now,
      required this.onNavigate});

  final DashboardResponse? dashboard;
  final DateTime now;
  final void Function(int tabIndex)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final items = buildTimeline(dashboard, now: now);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Row(
            children: [
              const Text("Today's timeline",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              InkWell(
                onTap: () => onNavigate?.call(1),
                child: const Row(
                  children: [
                    Text('View all',
                        style: TextStyle(
                            color: Color(0xFF667085), fontSize: 14)),
                    Icon(Icons.chevron_right,
                        color: Color(0xFF667085)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: const Color(0xFFF0EDE8)),
              ),
              child: const Text(
                'Nothing scheduled yet',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF667085)),
              ),
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      const _RailDot(top: true),
                      Expanded(
                          child: Container(
                              width: 2,
                              color: const Color(0xFF0C6B6B))),
                      const _RailDot(top: false),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        for (int i = 0; i < items.length; i++)
                          _TimelineRow(
                            done: items[i].done,
                            title: items[i].title,
                            time: DateFormat('h:mm a')
                                .format(items[i].at),
                            meta: items[i].meta,
                            trailing: _statusChip(items[i].status),
                            showDivider: i != items.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _statusChip(TimelineStatus status) {
    switch (status) {
      case TimelineStatus.completed:
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFE6F6F3),
              borderRadius: BorderRadius.circular(10)),
          child: const Text('Completed',
              style: TextStyle(
                  color: Color(0xFF0C6B6B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        );
      case TimelineStatus.overdue:
      case TimelineStatus.missed:
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(10)),
          child: Text(
              status == TimelineStatus.overdue
                  ? 'Overdue'
                  : 'Missed',
              style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        );
      case TimelineStatus.due:
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF4E3),
              borderRadius: BorderRadius.circular(10)),
          child: const Text('Due now',
              style: TextStyle(
                  color: Color(0xFFE8890C),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        );
      case TimelineStatus.cancelled:
        return const Text('Cancelled',
            style: TextStyle(
                color: Color(0xFF98A2B3), fontSize: 13));
      case TimelineStatus.upcoming:
        return const Icon(Icons.chevron_right,
            color: Color(0xFF98A2B3));
    }
  }
}

class _RailDot extends StatelessWidget {
  const _RailDot({required this.top});
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: const Color(0xFF0C6B6B), width: 2.4),
        color: top ? Colors.white : const Color(0xFF0C6B6B),
      ),
      child: top
          ? const Center(
              child: CircleAvatar(
                  radius: 3,
                  backgroundColor: Color(0xFF0C6B6B)))
          : null,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.done,
    required this.title,
    required this.time,
    this.meta,
    this.trailing,
    this.showDivider = true,
  });

  final bool done;
  final String title;
  final String time;
  final String? meta;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF0C8A8A)
                      : Colors.white,
                  border: Border.all(
                      color: done
                          ? const Color(0xFF0C8A8A)
                          : const Color(0xFF98A2B3),
                      width: 1.8),
                ),
                child: done
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Text(time,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF667085))),
                        if (meta != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(meta!,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF667085)),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF0EDE8)),
      ],
    );
  }
}

// ─── Quick add (routes to the owning module's real create flow) ───

class _QuickAddFab extends StatelessWidget {
  const _QuickAddFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      margin: const EdgeInsets.only(bottom: 96),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF0E8A8A), Color(0xFF0A5656)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0C6B6B).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
    );
  }
}

/// Quick-create entries. Each item routes to the owning module (Planner for
/// scheduled items, Modules for the rest) where the real backend create flow
/// lives. Home never creates dashboard-local records.
class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet({required this.onNavigate, required this.onRefresh});
  final void Function(int tabIndex)? onNavigate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // (label, icon, tab): 1 = Planner, 3 = Modules (Health/Meds/Diet/...).
    final items = [
      ('Planner event', Icons.event, 1),
      ('Task', Icons.add_task, 1),
      ('Medicine', Icons.medication_outlined, 3),
      ('Meal', Icons.restaurant, 3),
      ('Water', Icons.water_drop_outlined, 3),
      ('Habit', Icons.check_circle_outline, 3),
      ('Expense', Icons.account_balance_wallet_outlined, 3),
      ('Health measurement', Icons.monitor_heart_outlined, 3),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            const Text('Quick add',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (label, icon, tab) in items)
                    ListTile(
                      leading: Icon(icon,
                          color: const Color(0xFF0C6B6B)),
                      title: Text(label),
                      trailing:
                          const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        onNavigate?.call(tab);
                        // Refresh Home so the newly created record appears
                        // once the user returns (creation itself happens in
                        // the owning module against the real backend API).
                        Future.delayed(
                            const Duration(milliseconds: 500),
                            () => onRefresh());
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
