import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../models.dart';

/// One recorded payment, as a row inside a [GlassList]: who paid whom, its
/// confirmation status, and confirm / reject / withdraw actions.
class PaymentTile extends StatelessWidget {
  const PaymentTile({
    super.key,
    required this.settlement,
    this.onDelete,
    this.onDecision,
    this.busy = false,
  });
  final Settlement settlement;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onDecision;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final pending = settlement.status == 'PENDING';
    final legacy = settlement.status == 'LEGACY_RECORDED';
    final hasActions = onDecision != null || onDelete != null;
    final note = TextStyle(fontSize: 11, height: 1.4, color: colors.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconWell(
            Icons.swap_horiz_rounded,
            color: pending ? colors.warning : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${settlement.payer.displayName} → ${settlement.payee.displayName}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      settlement.amount.display(
                        currencyCode: settlement.currency,
                      ),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: BlistraText.tabular,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${isoDate(settlement.settledOn)} · ${settlement.status.toLowerCase()}${settlement.note == null ? '' : '\n${settlement.note}'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: pending ? colors.warning : colors.muted,
                  ),
                ),
                if (pending) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Awaiting the other participant. Balance unchanged.',
                    style: note,
                  ),
                ],
                if (legacy) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Recorded before confirmations were introduced. Historical balance effect retained.',
                    style: note,
                  ),
                ],
                if (hasActions) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (onDecision != null) ...[
                        Pill(
                          'Confirm payment',
                          onTap: busy ? null : () => _confirm(context, true),
                        ),
                        Pill(
                          'Reject',
                          color: colors.danger,
                          onTap: busy ? null : () => _confirm(context, false),
                        ),
                      ],
                      if (onDelete != null)
                        Pill(
                          'Withdraw',
                          color: colors.muted,
                          onTap: busy ? null : () => _withdraw(context),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _withdraw(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Withdraw this payment record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete!();
  }

  Future<void> _confirm(BuildContext context, bool confirmed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          confirmed ? 'Confirm this payment?' : 'Reject this payment?',
        ),
        content: Text(
          confirmed
              ? 'Confirm only if this payment happened. It will update balances and cannot be deleted.'
              : 'The balance will stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirmed ? 'Confirm' : 'Reject'),
          ),
        ],
      ),
    );
    if (ok == true) onDecision!(confirmed);
  }
}
