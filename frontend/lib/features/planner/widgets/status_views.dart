import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/glass.dart';

/// Glass error panel with a retry pill.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 16, kPageGutter, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            IconWell(Icons.cloud_off_rounded, color: colors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            Pill('Retry', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

/// Glass empty-state card with an icon and a message.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          IconWell(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: colors.muted)),
          ),
        ],
      ),
    );
  }
}
