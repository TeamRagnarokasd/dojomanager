import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../presentation/payment_history/widgets/sumup_waiting_sheet.dart';
import 'pending_purchases_service.dart';

/// True while [processPendingPurchases] is already draining the queue
/// somewhere (a screen's own resume hook, or the app-wide hook in
/// main.dart) — a second concurrent call is a safe no-op, since the first
/// one will keep looping until the list is empty anyway. Without this
/// guard, two call sites firing on the same resume event could each claim
/// a different purchase and show two dialogs stacked on top of each other.
bool _isProcessing = false;

/// Processes ALL pending purchases, oldest first, one at a time. Every
/// purchase created today always carries an intent id (the create-payment
/// flow is the only way to start one) and is watched with
/// [SumUpWaitingSheet], which only ever activates a subscription after a
/// verified 'matched'/'confirmed' intent — there is no other path left to
/// activate anything from here.
///
/// A purchase with no intent id is a leftover from the old fixed-link flow
/// (a build that predates this check) and is discarded outright, never
/// shown as something to confirm by hand — see the incident that removed
/// that flow entirely: a plain "sì" used to be enough to activate a
/// subscription and print a receipt with nothing behind it.
///
/// Each purchase is atomically claimed via [PendingPurchasesService.takeNext]
/// before its sheet is shown (or it is discarded), so it can never be
/// confirmed twice even if this is called from more than one place in a row.
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
      if (!hasIntentId) {
        debugPrint(
          '⚠️ processPendingPurchases: discarding pending purchase with no '
          'intent id (leftover from the old manual-confirmation flow): '
          '${purchase.id}',
        );
        continue;
      }

      if (!context.mounted) {
        // Already claimed via takeNext() — put it back rather than
        // dropping it, since there is no context left to show it in.
        await PendingPurchasesService.requeue(purchase);
        return;
      }

      try {
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
