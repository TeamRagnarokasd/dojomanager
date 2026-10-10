import 'package:flutter/material.dart';

import '../presentation/payment_history/widgets/payment_confirmation_dialog.dart';
import '../presentation/payment_history/widgets/sumup_waiting_sheet.dart';
import 'feature_flags_service.dart';
import 'pending_purchases_service.dart';

/// True while [processPendingPurchases] is already draining the queue
/// somewhere (a screen's own resume hook, or the app-wide hook in
/// main.dart) — a second concurrent call is a safe no-op, since the first
/// one will keep looping until the list is empty anyway. Without this
/// guard, two call sites firing on the same resume event could each claim
/// a different purchase and show two dialogs stacked on top of each other.
bool _isProcessing = false;

/// Processes ALL pending purchases, oldest first, one at a time — using
/// the exact same per-purchase UI as before a single purchase could be
/// remembered (SumUpWaitingSheet for an auto-watched SumUp/Satispay click,
/// PaymentConfirmationDialog otherwise). Each purchase is atomically
/// claimed via [PendingPurchasesService.takeNext] before its dialog/sheet
/// is shown, so it can never be confirmed twice even if this is called
/// from more than one place in a row.
Future<void> processPendingPurchases(
  BuildContext context, {
  VoidCallback? onConfirmed,
}) async {
  if (_isProcessing) return;
  _isProcessing = true;
  try {
    while (true) {
      // Checked BEFORE claiming the next purchase, not after: once
      // takeNext() removes an entry from storage there is no way back, so
      // a purchase must never be claimed if there is already no context
      // left to show it in.
      if (!context.mounted) return;
      final purchase = await PendingPurchasesService.takeNext();
      if (purchase == null) return;

      final hasIntentId =
          purchase.intentId != null && purchase.intentId!.isNotEmpty;
      final showWaitingSheet = hasIntentId &&
          (purchase.method == 'satispay' ||
              (purchase.method == 'sumup' &&
                  await FeatureFlagsService.instance.isEnabled(
                    'sumup_auto_confirm',
                  )));

      if (!context.mounted) {
        // Already claimed via takeNext() — put it back rather than
        // dropping it, since there is no context left to show it in.
        await PendingPurchasesService.requeue(purchase);
        return;
      }

      try {
        if (showWaitingSheet) {
          await showModalBottomSheet<void>(
            context: context,
            isDismissible: false,
            enableDrag: false,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => SumUpWaitingSheet(
              intentId: purchase.intentId,
              onConfirmed: onConfirmed,
            ),
          );
        } else {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => PaymentConfirmationDialog(
              planData: {
                'plan_id': purchase.planId,
                'plan_title': purchase.planTitle,
                'amount': purchase.amount,
                'payment_method': purchase.method,
                'beneficiary_id': purchase.beneficiaryId,
              },
              onConfirmed: onConfirmed,
            ),
          );
        }
      } catch (e) {
        // The purchase was already claimed above — if it couldn't actually
        // be shown (e.g. the Navigator was torn down mid-call), put it
        // back instead of losing it forever; the next resume picks it up.
        await PendingPurchasesService.requeue(purchase);
        rethrow;
      }
      // Loop continues to the next pending purchase, if any.
    }
  } finally {
    _isProcessing = false;
  }
}
