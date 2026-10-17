import 'package:flutter/material.dart';

import '../models.dart';

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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              '${settlement.payer.displayName} → ${settlement.payee.displayName}',
            ),
            subtitle: Text(
              '${isoDate(settlement.settledOn)} · ${settlement.status.toLowerCase()}${settlement.note == null ? '' : '\n${settlement.note}'}',
            ),
            trailing: Text(
              settlement.amount.display(currencyCode: settlement.currency),
            ),
          ),
          if (settlement.status == 'PENDING')
            const Text('Awaiting the other participant. Balance unchanged.'),
          if (settlement.status == 'LEGACY_RECORDED')
            const Text(
              'Recorded before confirmations were introduced. Historical balance effect retained.',
            ),
          Wrap(
            spacing: 8,
            children: [
              if (onDecision != null) ...[
                FilledButton(
                  onPressed: busy ? null : () => _confirm(context, true),
                  child: const Text('Confirm payment'),
                ),
                TextButton(
                  onPressed: busy ? null : () => _confirm(context, false),
                  child: const Text('Reject'),
                ),
              ],
              if (onDelete != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text(
                                'Withdraw this payment record?',
                              ),
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
                        },
                  child: const Text('Withdraw'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
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
