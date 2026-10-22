/// Blistra design system: one-product look across every module.
///
/// Presentation-only widgets. No business logic, no API calls.
/// Each module keeps its own controller/repository; these widgets only render.
/// Newer building blocks (stat strips, glass lists, rings, form fields) live
/// in `blistra_ui.dart`.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'blistra_ui.dart';
import 'glass.dart';

/// Standard page header: serif title + subtitle + optional trailing.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 16, kPageGutter, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BlistraText.serif(28, colors.text, height: 1.1)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: colors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Section heading: serif title with an optional accent action on the right
/// ("See all ›"). Includes the page gutter.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Kept for compatibility; the design uses plain serif headings.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: BlistraText.serif(17, colors.text)),
            ),
          ),
          if (actionLabel != null)
            Semantics(
              button: onAction != null,
              child: GestureDetector(
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.accentText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Glass card wrapper used by module pages.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: padding ?? const EdgeInsets.all(15),
        onTap: onTap,
        child: child,
      );
}

/// Small status pill (Upcoming / Taken / Overdue / ...). Never color-only:
/// always includes a label.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final c = colors.isDark ? Color.lerp(color, Colors.white, 0.25)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: colors.isDark ? 0.2 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metric tile for overviews (weight, balance, streak, ...).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String? delta;
  final bool? deltaPositive;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BlistraText.caption(colors.muted),
                ),
              ),
              if (icon != null) Icon(icon, size: 16, color: colors.muted),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: BlistraText.serif(22, colors.text)),
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: deltaPositive == null
                    ? colors.muted
                    : (deltaPositive! ? colors.accentText : colors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Primary action button with built-in progress state. Disables itself while
/// [busy] to prevent duplicate submissions.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    this.busyLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.check),
      label: Text(busy ? (busyLabel ?? 'Saving…') : label),
    );
  }
}

/// Skeleton placeholder for lists/dashboards (meaningful loading structure).
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key, this.rows = 3, this.rowHeight = 64});

  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Container(
            height: rowHeight,
            margin: const EdgeInsets.symmetric(
              horizontal: kPageGutter,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: colors.inkAt(0.06),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
      ],
    );
  }
}

/// Confirmation dialog helper (delete/archive destructive actions).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = BlistraColors.resolve(context);
      return AlertDialog(
        title: Text(title),
        content: Text(message, style: TextStyle(color: colors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              backgroundColor: destructive ? colors.danger : null,
              foregroundColor: destructive ? Colors.white : null,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Human-friendly error snackbar (logs stay technical, UI stays friendly).
void showAppMessage(BuildContext context, String message, {bool error = false}) {
  final colors = BlistraColors.resolve(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(color: error ? Colors.white : colors.text),
      ),
      backgroundColor: error ? colors.danger : null,
    ),
  );
}
