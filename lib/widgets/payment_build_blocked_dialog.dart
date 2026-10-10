import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown instead of starting a SumUp/Satispay payment when the installed
/// APK is older than `app_version.min_payment_build` — these are builds
/// that still had (or might still have, if somehow reinstalled) the manual
/// "hai pagato?" confirmation flow removed for the security incident of
/// 27/09/2026. Only the payment action is blocked here: the rest of the
/// app keeps working, and this same check runs again next time the user
/// tries to pay, so there is no "later" — only "update, then pay".
Future<void> showPaymentBuildBlockedDialog(
  BuildContext context, {
  required String apkUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).cardColor,
      title: Text(
        'Aggiornamento obbligatorio',
        style: Theme.of(dialogContext)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Per la sicurezza dei pagamenti, anche per i minori, '
        'l\'aggiornamento dell\'app è obbligatorio per continuare.',
        style: Theme.of(dialogContext).textTheme.bodyLarge?.copyWith(height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Chiudi'),
        ),
        if (apkUrl.isNotEmpty)
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await launchUrl(
                Uri.parse(apkUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Aggiorna ora'),
          ),
      ],
    ),
  );
}
