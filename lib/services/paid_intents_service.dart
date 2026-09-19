import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_service.dart';

/// Reconciles Satispay `payment_intents` that were created up to a purchase
/// flow ago and activates the corresponding subscription automatically,
/// without requiring the user to answer "did you pay?" — the backend is the
/// single source of truth, so this works even hours later and with no local
/// data at all (safe to call on web too).
///
/// Every network call here is wrapped so that a failure simply leaves the
/// intent as-is to be retried on the next call (app resume): nothing here
/// can put the app in a worse state than before calling it.
class PaidIntentsService {
  PaidIntentsService._();
  static final PaidIntentsService instance = PaidIntentsService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  // Guards against overlapping runs (e.g. a resume event firing while the
  // startup call is still in flight).
  bool _isProcessing = false;

  /// Looks at the current user's own `payment_intents` rows (provider
  /// 'satispay', created in the last 24h), checks pending ones with Satispay,
  /// and activates the subscription for any that have been matched/paid.
  ///
  /// Returns the number of subscriptions actually activated in this call —
  /// callers can use this to decide whether to show an "Abbonamento
  /// attivato" toast.
  Future<int> processPaidIntents() async {
    if (_isProcessing) return 0;
    _isProcessing = true;
    var activatedCount = 0;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final since = DateTime.now().toUtc().subtract(const Duration(hours: 24));

      List<Map<String, dynamic>> intents;
      try {
        final response = await _supabase
            .from('payment_intents')
            .select(
              'id, status, provider, provider_payment_id, custom_plan_id, '
              'plan_name, amount, beneficiary_profile_id, created_at',
            )
            .eq('user_id', userId)
            .eq('provider', 'satispay')
            .gte('created_at', since.toIso8601String());
        intents = List<Map<String, dynamic>>.from(response as List);
      } catch (e) {
        debugPrint('⚠️ PaidIntentsService: could not fetch payment_intents: $e');
        return 0;
      }

      for (final intent in intents) {
        try {
          final activated = await _processSingleIntent(intent);
          if (activated) activatedCount++;
        } catch (e) {
          debugPrint('⚠️ PaidIntentsService: error processing intent: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ PaidIntentsService.processPaidIntents error: $e');
    } finally {
      _isProcessing = false;
    }

    return activatedCount;
  }

  Future<bool> _processSingleIntent(Map<String, dynamic> intent) async {
    final intentId = intent['id'] as String?;
    if (intentId == null) return false;

    var status = intent['status'] as String?;
    final providerPaymentId = intent['provider_payment_id'] as String?;

    // For 'pending' intents that already have a provider_payment_id, ask
    // Satispay for the latest status.
    if (status == 'pending' &&
        providerPaymentId != null &&
        providerPaymentId.isNotEmpty) {
      try {
        final checkResponse = await _supabase.functions.invoke(
          'satispay/check',
          body: {'intent_id': intentId},
        );
        final data = checkResponse.data;
        if (data is Map && data['status'] is String) {
          status = data['status'] as String;
        }
      } catch (e) {
        debugPrint(
          '⚠️ PaidIntentsService: satispay/check failed for $intentId: $e',
        );
        return false; // try again next time
      }
    }

    if (status != 'matched') return false;

    // Only the first caller to successfully claim an intent gets non-null
    // data back — this guards against double-activation from overlapping
    // resume events or multiple devices.
    dynamic claimResult;
    try {
      claimResult = await _supabase.rpc(
        'claim_paid_intent',
        params: {'p_intent_id': intentId},
      );
    } catch (e) {
      debugPrint(
        '⚠️ PaidIntentsService: claim_paid_intent failed for $intentId: $e',
      );
      return false;
    }
    if (claimResult == null) return false;

    final claim = Map<String, dynamic>.from(claimResult as Map);
    final planName = claim['plan_name'] as String? ??
        intent['plan_name'] as String? ??
        'Abbonamento';
    final claimAmount = (claim['amount'] as num?)?.toDouble() ??
        (intent['amount'] as num?)?.toDouble() ??
        0.0;
    final beneficiaryProfileId = claim['beneficiary_profile_id'] as String? ??
        intent['beneficiary_profile_id'] as String?;
    final paidAtRaw = claim['paid_at'] as String?;
    final paidAt = paidAtRaw != null ? DateTime.tryParse(paidAtRaw) : null;

    var confirmationId = '';
    try {
      confirmationId = await SubscriptionService.createBatchPaymentAndReceipts(
        items: [
          {'name': planName, 'price': claimAmount},
        ],
        paymentMethod: 'satispay',
        amount: claimAmount,
        description: planName,
        discipline: null,
        discipline2: null,
        beneficiaryProfileIdOverride: beneficiaryProfileId,
        paidAt: paidAt,
      );
    } catch (e) {
      debugPrint(
        '⚠️ PaidIntentsService: createBatchPaymentAndReceipts failed for '
        '$intentId: $e',
      );
      confirmationId = '';
    }

    if (confirmationId.isEmpty) {
      // Activation failed — release the claim so a later run (or an admin)
      // can retry, instead of leaving the intent stuck as claimed-but-unused.
      try {
        await _supabase.rpc(
          'release_paid_intent',
          params: {'p_intent_id': intentId},
        );
      } catch (e) {
        debugPrint(
          '⚠️ PaidIntentsService: release_paid_intent failed for $intentId: $e',
        );
      }
      return false;
    }

    try {
      await _supabase.rpc(
        'attach_intent_confirmation',
        params: {
          'p_intent_id': intentId,
          'p_confirmation_id': confirmationId,
        },
      );
    } catch (e) {
      debugPrint(
        '⚠️ PaidIntentsService: attach_intent_confirmation failed for '
        '$intentId: $e',
      );
      // The subscription is already active at this point; failing to attach
      // the confirmation id is a bookkeeping issue only, not a user-facing one.
    }

    return true;
  }
}
