/// Building blocks for every Blistra page, matching the Home design:
/// frosted glass on the theme glow, Fraunces headings, Inter body.
///
/// Presentation only. Pair with [BlistraPageHeader], [SectionHeader] and
/// [BlistraSegmentedTabs] for page structure, and [GlassCard] for surfaces.
///
/// Page anatomy (see design/app-pages.html):
/// header → status card or stat strip → sections of [GlassList] rows →
/// optional [StickyActionBar] for the page's one primary action.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// Shared text styles.
abstract final class BlistraText {
  /// Fraunces heading/number style.
  static TextStyle serif(double size, Color color, {double height = 1.15}) =>
      TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: height,
        color: color,
      );

  /// Small tracked uppercase label (dates, card captions).
  static TextStyle eyebrow(Color color) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: color,
      );

  /// Uppercase caption above a value ("ADHERENCE", "INCOME").
  static TextStyle caption(Color color) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: color,
      );

  static const tabular = [FontFeature.tabularFigures()];
}

/// Standard horizontal page gutter used by every page.
const double kPageGutter = 18;

/// Pads [child] with the page gutter and an optional top gap.
class PagePad extends StatelessWidget {
  const PagePad(this.child, {super.key, this.top = 0});

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(kPageGutter, top, kPageGutter, 0),
        child: child,
      );
}

/// Circular progress ring.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.color,
    this.size = 34,
    this.stroke = 4,
    this.child,
  });

  final double progress;
  final Color? color;
  final double size;
  final double stroke;

  /// Centered content, e.g. "5/9".
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.isNaN ? 0 : progress.clamp(0.0, 1.0),
          color: color ?? colors.accentText,
          track: colors.inkAt(0.12),
          stroke: stroke,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final arc = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (progress > 0) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Thin rounded progress bar.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.color,
    this.gradient,
    this.height = 6,
  });

  final double value;
  final Color? color;
  final Gradient? gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.inkAt(0.12)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.isNaN ? 0 : value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: gradient == null ? (color ?? colors.accentText) : null,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded label ("HIGH", "2 days"), or a tappable action pill when
/// [onTap] is set ("Log", "+ Water", "Retry").
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.onTap});

  final String text;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final c = color ?? colors.accentText;
    final action = onTap != null;
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: action ? 12 : 9,
        vertical: action ? 7 : 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: colors.isDark ? 0.2 : 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: action ? 11 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: action ? 0 : 0.4,
          color: c,
        ),
      ),
    );
    if (!action) return pill;
    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(onTap: onTap, child: pill),
    );
  }
}

/// Round completion check used for tasks, doses and habits.
class CheckCircle extends StatelessWidget {
  const CheckCircle({
    super.key,
    required this.checked,
    this.onTap,
    this.busy = false,
    this.urgent = false,
    this.size = 22,
    this.semanticLabel,
  });

  final bool checked;
  final VoidCallback? onTap;
  final bool busy;

  /// Red ring for overdue or due-now items.
  final bool urgent;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final ring = checked
        ? colors.accentText
        : urgent
            ? colors.danger
            : colors.inkAt(0.55);
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? colors.accentText : Colors.transparent,
        border: Border.all(color: ring, width: 1.8),
      ),
      child: busy
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: colors.accentText,
              ),
            )
          : checked
              ? Icon(Icons.check_rounded,
                  size: size * 0.6, color: colors.onAccent)
              : null,
    );
    if (onTap == null) return circle;
    return Semantics(
      button: true,
      checked: checked,
      label: semanticLabel,
      child: InkResponse(
        onTap: busy ? null : onTap,
        radius: size,
        child: Padding(padding: const EdgeInsets.all(6), child: circle),
      ),
    );
  }
}

/// Rounded square icon well used at the start of list rows.
class IconWell extends StatelessWidget {
  const IconWell(this.icon, {super.key, this.color, this.size = 36});

  final IconData icon;

  /// Tints the well and icon; neutral when null.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.18) ?? colors.inkAt(0.08),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(icon, size: size * 0.46, color: color ?? colors.text),
    );
  }
}

/// A glass card holding rows separated by hairlines.
class GlassList extends StatelessWidget {
  const GlassList({super.key, required this.children, this.radius = 22});

  final List<Widget> children;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: radius,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: colors.inkAt(0.08))),
              ),
              child: children[i],
            ),
        ],
      ),
    );
  }
}

/// One row in a [GlassList]: leading widget, title, subtitle, trailing.
class GlassRow extends StatelessWidget {
  const GlassRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.done = false,
    this.subtitleColor,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Strikes through and fades the text for completed items.
  final bool done;
  final Color? subtitleColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(leading is CheckCircle ? 9 : 15, 12, 15, 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Opacity(
                opacity: done ? 0.55 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? colors.text,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: colors.muted,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: subtitleColor ?? colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Muted trailing text for rows ("8:00", "›").
class RowMeta extends StatelessWidget {
  const RowMeta(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: colors.muted,
        fontFeatures: BlistraText.tabular,
      ),
    );
  }
}

/// Data for one tile in a [StatStrip].
class StatData {
  const StatData({
    required this.label,
    required this.value,
    this.sub = '',
    this.unit = '',
    this.total,
    this.progress,
    this.color,
    this.icon,
    this.badge,
    this.onTap,
  });

  final String label;
  final String value;
  final String unit;

  /// Shown as " / total" after [value].
  final String? total;
  final String sub;

  /// Shows a ring in the corner when set.
  final double? progress;
  final Color? color;

  /// Shows an icon well in the corner when [progress] is null.
  final IconData? icon;

  /// Shows a pill in the corner instead of a ring or icon ("LOW").
  final String? badge;
  final VoidCallback? onTap;
}

/// Horizontally scrolling row of [StatTile]s that bleeds to the screen edge.
/// Place it outside [PagePad].
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.stats});

  final List<StatData> stats;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
        clipBehavior: Clip.none,
        itemCount: stats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => StatTile(stat: stats[i]),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.stat, this.width = 138});

  final StatData stat;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final Widget? corner = stat.badge != null
        ? Pill(stat.badge!, color: stat.color ?? colors.warning)
        : stat.progress != null
            ? ProgressRing(progress: stat.progress!, color: stat.color)
            : stat.icon != null
                ? Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.inkAt(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stat.icon, size: 17, color: colors.muted),
                  )
                : null;
    return SizedBox(
      width: width,
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
        onTap: stat.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stat.label.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BlistraText.caption(colors.muted),
                    ),
                  ),
                  ?corner,
                ],
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  text: stat.value,
                  children: [
                    if (stat.total != null || stat.unit.isNotEmpty)
                      TextSpan(
                        text: stat.total != null
                            ? ' / ${stat.total}'
                            : ' ${stat.unit}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.muted,
                        ),
                      ),
                  ],
                ),
                style: BlistraText.serif(24, colors.text, height: 1.1),
              ),
            ),
            if (stat.sub.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                stat.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: colors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Glass card with a ring (or any leading visual) and a summary, used at the
/// top of module pages ("5/9 · 4 tasks left").
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.caption,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String caption;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption.toUpperCase(), style: BlistraText.caption(colors.muted)),
                const SizedBox(height: 3),
                Text(title, style: BlistraText.serif(19, colors.text)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: colors.muted),
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

/// Labelled figure ("INCOME ₹62,000") for summary rows; use inside a [Row]
/// with [Expanded].
class Figure extends StatelessWidget {
  const Figure({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: BlistraText.caption(colors.muted)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: BlistraText.serif(18, color ?? colors.text)),
        ),
      ],
    );
  }
}

/// Horizontally scrolling filter chips ("All 24", "Medical 9").
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
  });

  final List<String> labels;
  final List<IconData>? icons;

  /// Index of the selected chip, or null for none.
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
        clipBehavior: Clip.none,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = selected == i;
          return Semantics(
            button: true,
            selected: on,
            label: labels[i],
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: on ? colors.accentSoft : colors.glassFill,
                  border: Border.all(
                    color: on
                        ? colors.accentText.withValues(alpha: 0.45)
                        : colors.glassBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icons != null) ...[
                      Icon(icons![i],
                          size: 15, color: on ? colors.accentText : colors.muted),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: on ? colors.accentText : colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Glass field wrapper for forms: small uppercase label above any input.
/// For text input prefer [GlassTextField].
class FieldCard extends StatelessWidget {
  const FieldCard({super.key, required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: BlistraText.caption(colors.muted)),
            const SizedBox(height: 4),
            DefaultTextStyle.merge(
              style: TextStyle(fontSize: 14, color: colors.text),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Borderless text input inside a [FieldCard].
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.autofocus = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return FieldCard(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: obscureText ? 1 : maxLines,
        validator: validator,
        onChanged: onChanged,
        textInputAction: textInputAction,
        obscureText: obscureText,
        autofocus: autofocus,
        enabled: enabled,
        style: TextStyle(fontSize: 14, color: colors.text),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: hint,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          suffixIcon: suffix,
          suffixIconConstraints: const BoxConstraints(minHeight: 20),
        ),
      ),
    );
  }
}

/// Glass segmented control with a filled accent selection; options share
/// the width equally. Use for 2–4 short options in forms and pages.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                label: label,
                child: GestureDetector(
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == selected
                          ? colors.accentText
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: value == selected ? colors.onAccent : colors.muted,
                      ),
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

/// The page's one primary action, pinned to the bottom over a fade.
/// Use as `Scaffold.bottomNavigationBar` or the last child of a [Stack].
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.secondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Optional secondary action shown to the left (e.g. Delete).
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.background.withValues(alpha: 0), colors.background],
          stops: const [0, 0.35],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPageGutter, 18, kPageGutter, 14),
          child: Row(
            children: [
              if (secondary != null) ...[secondary!, const SizedBox(width: 10)],
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onPressed,
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Short message in a glass card for empty sections.
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.message, this.action, this.onAction});

  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: colors.muted)),
          ),
          if (action != null && onAction != null) Pill(action!, onTap: onAction),
        ],
      ),
    );
  }
}

/// A section whose data failed to load; the rest of the page keeps working.
class UnavailableCard extends StatelessWidget {
  const UnavailableCard({super.key, required this.name, required this.onRetry});

  final String name;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$name couldn't load",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The rest of this page is fine.',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          Pill('Retry', onTap: onRetry),
        ],
      ),
    );
  }
}
