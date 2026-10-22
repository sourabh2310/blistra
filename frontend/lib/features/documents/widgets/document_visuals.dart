/// Documents-only visuals: category colours and icons, the file-type badge
/// and the glass search field. Kept private to this module.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../models/document.dart';

/// Category colour, readable on the current theme's background.
Color categoryColor(BuildContext context, DocumentCategory category) {
  final colors = BlistraColors.resolve(context);
  final hue = switch (category) {
    DocumentCategory.medical => 0.0,
    DocumentCategory.prescription => 335.0,
    DocumentCategory.report => 262.0,
    DocumentCategory.finance => 146.0,
    DocumentCategory.receipt => 175.0,
    DocumentCategory.insurance => 40.0,
    DocumentCategory.personal => 215.0,
    DocumentCategory.other => null,
  };
  if (hue == null) return colors.muted;
  return HSLColor.fromAHSL(
    1,
    hue,
    colors.isDark ? 0.8 : 0.7,
    colors.isDark ? 0.7 : 0.4,
  ).toColor();
}

IconData categoryIcon(DocumentCategory category) => switch (category) {
      DocumentCategory.medical => Icons.local_hospital_outlined,
      DocumentCategory.prescription => Icons.medication_outlined,
      DocumentCategory.report => Icons.assignment_outlined,
      DocumentCategory.finance => Icons.account_balance_wallet_outlined,
      DocumentCategory.receipt => Icons.receipt_long_outlined,
      DocumentCategory.insurance => Icons.shield_outlined,
      DocumentCategory.personal => Icons.badge_outlined,
      DocumentCategory.other => Icons.description_outlined,
    };

/// Short file-type label ("PDF", "JPG") from the content type or filename.
String fileTypeLabel(AppDocument doc) {
  if (doc.isPdf) return 'PDF';
  final name = doc.originalFilename;
  final dot = name.lastIndexOf('.');
  if (dot > 0 && dot < name.length - 1) {
    final ext = name.substring(dot + 1).toUpperCase();
    if (ext.length <= 4) return ext == 'JPEG' ? 'JPG' : ext;
  }
  if (doc.isImage) return 'IMG';
  return 'FILE';
}

/// Rounded tile with the file type in the category colour.
class FileTypeBadge extends StatelessWidget {
  const FileTypeBadge({
    super.key,
    required this.document,
    this.width = 36,
    this.height = 36,
    this.fontSize = 10,
  });

  final AppDocument document;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(context, document.category);
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(height >= 50 ? 14 : 12),
      ),
      child: Text(
        fileTypeLabel(document),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

/// Every category as wrapping chips, so the selection is always visible
/// (forms); styled like [ChipRow].
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final DocumentCategory selected;
  final ValueChanged<DocumentCategory>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in DocumentCategory.values)
          Semantics(
            button: true,
            selected: c == selected,
            label: c.label,
            child: GestureDetector(
              onTap: onSelected == null ? null : () => onSelected!(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: c == selected ? colors.accentSoft : colors.glassFill,
                  border: Border.all(
                    color: c == selected
                        ? colors.accentText.withValues(alpha: 0.45)
                        : colors.glassBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryIcon(c),
                      size: 15,
                      color: c == selected ? colors.accentText : colors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c == selected ? colors.accentText : colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Glass search input with a leading search icon and a clear button.
class DocumentSearchField extends StatelessWidget {
  const DocumentSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: colors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14, color: colors.text),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: 'Search documents',
                hintStyle: TextStyle(fontSize: 13, color: colors.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Tooltip(
                message: 'Clear',
                child: Icon(Icons.close_rounded, size: 18, color: colors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
