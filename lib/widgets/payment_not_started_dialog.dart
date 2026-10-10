import 'package:flutter/material.dart';

/// Shown whenever a SumUp/Satispay payment could not be started — the
/// create-payment call failed, or the feature is currently disabled. There
/// is no fixed-link/manual fallback to offer any more: the only option is
/// to retry, or close and come back later / contact the gym.
Future<void> showPaymentNotStartedDialog(
  BuildContext context, {
  required VoidCallback onRetry,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).cardColor,
      title: Text(
        'Pagamento non avviato',
        style: Theme.of(dialogContext)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Pagamento non avviato. Riprova tra poco o contatta la palestra.',
        style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Chiudi'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            onRetry();
          },
          child: const Text('Riprova'),
        ),
      ],
    ),
  );
}
