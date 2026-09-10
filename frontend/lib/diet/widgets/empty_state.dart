import 'package:flutter/material.dart';

/// Friendly empty state used when a day has no recorded food.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: scheme.outline),
          const SizedBox(height: 12),
          Text(title, style: textTheme.titleSmall, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}