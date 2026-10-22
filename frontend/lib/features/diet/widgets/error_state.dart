import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/glass.dart';

/// Error message in a glass card with an optional retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          IconWell(Icons.cloud_off_outlined, color: colors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: colors.text),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            Pill('Try again', onTap: onRetry),
          ],
        ],
      ),
    );
  }
}
