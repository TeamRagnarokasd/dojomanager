import 'package:flutter/material.dart';

/// Shown right before starting ANY SumUp/Satispay payment (piani,
/// convenzioni, nuovi pagamenti) — a brief confirmation of who is actually
/// being paid for. The active profile (adult or a specific child) is
/// chosen elsewhere (the dashboard profile switcher) and stays silently in
/// effect here; this dialog exists only so the payer sees it spelled out
/// before money moves, never to change it. Returns true only if the
/// student taps "Conferma" — false (including a dismissed dialog) means
/// the payment must not start at all.
Future<bool> showPaymentConfirmDialog(
  BuildContext context, {
  required String beneficiaryName,
  required bool isChild,
  required String planTitle,
  required double amount,
}) async {
  final amountText = '€${amount.toStringAsFixed(2).replaceAll('.', ',')}';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).cardColor,
      title: Text(
        'Confermi il pagamento?',
        style: Theme.of(dialogContext)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Stai pagando per: $beneficiaryName (${isChild ? 'minore' : 'adulto'}) '
        '— $planTitle — $amountText',
        style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Conferma'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
