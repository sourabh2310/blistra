/// Small Planner-only building blocks used by the redesigned screens. They
/// sit on top of the shared components in `core/widgets/blistra_ui.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../formats.dart';
import '../models/task_priority.dart';

/// "HIGH" / "MED" pill. Low priority shows nothing to keep rows quiet.
class PriorityPill extends StatelessWidget {
  const PriorityPill(this.priority, {super.key});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return switch (priority) {
      TaskPriority.high => Pill('HIGH', color: colors.danger),
      TaskPriority.medium => Pill('MED', color: colors.warning),
      TaskPriority.low => const SizedBox.shrink(),
    };
  }
}

/// One entry in a [RowMenu].
class RowMenuItem {
  const RowMenuItem(this.label, this.onSelected, {this.destructive = false});

  final String label;
  final VoidCallback onSelected;
  final bool destructive;
}

/// Compact "⋯" menu at the end of a list row.
class RowMenu extends StatelessWidget {
  const RowMenu({super.key, required this.items, this.tooltip = 'More actions'});

  final List<RowMenuItem> items;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return PopupMenuButton<int>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz_rounded, size: 18, color: colors.muted),
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelected: (index) => items[index].onSelected(),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            child: Text(
              items[i].label,
              style: items[i].destructive ? TextStyle(color: colors.danger) : null,
            ),
          ),
      ],
    );
  }
}

/// Glass text field with a hidden length counter and sentence capitalisation;
/// [GlassTextField] has neither, and Planner forms need both.
class PlannerTextField extends StatelessWidget {
  const PlannerTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.autofocus = false,
    this.textInputAction,
    this.large = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final FormFieldValidator<String>? validator;
  final bool autofocus;
  final TextInputAction? textInputAction;

  /// Bigger serif-free title input for the form's main field.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return FieldCard(
      label: label,
      child: TextFormField(
        controller: controller,
        autofocus: autofocus,
        maxLines: maxLines,
        minLines: minLines,
        validator: validator,
        textInputAction: textInputAction,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ],
        style: TextStyle(
          fontSize: large ? 16 : 14,
          fontWeight: large ? FontWeight.w600 : FontWeight.w400,
          color: colors.text,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: hint,
          hintStyle: TextStyle(color: colors.muted),
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Tappable [FieldCard] showing a value, e.g. a date or time picker field.
/// Greys out when [onTap] is null.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  /// Shows [value] muted, as a prompt rather than a chosen value.
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Semantics(
        button: onTap != null,
        label: '$label: $value',
        excludeSemantics: true,
        child: FieldCard(
          label: label,
          onTap: onTap,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: placeholder ? colors.muted : colors.text),
          ),
        ),
      ),
    );
  }
}

/// Small caps label above a non-field control (segmented, chips).
class FormCaption extends StatelessWidget {
  const FormCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 0, 8),
      child: Text(text.toUpperCase(), style: BlistraText.caption(colors.muted)),
    );
  }
}

/// Shared date labels for Planner rows and headers.
abstract final class PlannerDates {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  /// "Fri, 24 Oct" (year added outside the current year).
  static String short(DateTime d) => Formats.shortDate(d);

  /// "October 2026".
  static String month(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  /// "Today", "Tomorrow", "Yesterday" or [short].
  static String relative(DateTime d, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return short(d);
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
