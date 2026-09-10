import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact meal row used across the day and history lists.
class MealTile extends StatelessWidget {
  const MealTile({
    super.key,
    required this.label,
    required this.title,
    required this.consumedAt,
    this.itemCount,
    this.onTap,
  });

  final String label;
  final String title;
  final DateTime consumedAt;
  final int? itemCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(label.isEmpty ? '•' : label.substring(0, 1)),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(DateFormat('h:mm a').format(consumedAt), style: textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (itemCount != null && itemCount! > 0)
            Text(
              '$itemCount ${itemCount! == 1 ? 'item' : 'items'}',
              style: textTheme.bodySmall,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}