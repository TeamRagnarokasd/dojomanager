import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_flags_service.dart';
import 'subscription_service.dart';

/// Result of one subscription activation performed by [PaidIntentsService].
///
/// [stillValid] tells the caller whether the plan just activated is still
/// within its validity window as of now (see [PaidIntentsService]'s expiry
/// check), so it can choose the right confirmation message.
class PaidIntentActivationResult {
  const PaidIntentActivationResult({
    required this.planName,
    required this.stillValid,
  });

  final String planName;
  final bool stillValid;
}

/// Reconciles Satispay `payment_intents` and activates the corresponding
/// subscription automatically, without requiring the user to answer "did you
/// pay?" — the backend is the single source of truth, so this works even
/// hours later and with no local data at all (safe to call on web too).
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

  // When the last subscription activation actually created a
  // payment_confirmations receipt. A database trigger discards a receipt
  // that arrives within 60s of another one with the same customer name and
  // amount, so consecutive activations wait at least 65s apart
  // (see _waitForActivationSlot).
  DateTime? _lastActivationAt;

  /// Looks at the current user's own pending/matched Satispay
  /// `payment_intents` rows, checks pending ones with Satispay, and
  /// activates the subscription for any that have been matched/paid.
  ///
  /// Returns one [PaidIntentActivationResult] per subscription actually
  /// activated in this call — callers can use this to decide which
  /// confirmation toast(s) to show.
  Future<List<PaidIntentActivationResult>> processPaidIntents() async {
    if (_isProcessing) return [];
    _isProcessing = true;
    final results = <PaidIntentActivationResult>[];

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // SumUp intents only join in when 'sumup_auto_confirm' is on — off,
      // this query is identical to before (satispay only).
      final sumupEnabled =
          await FeatureFlagsService.instance.isEnabled('sumup_auto_confirm');
      final providers = sumupEnabled ? ['satispay', 'sumup'] : ['satispay'];

      List<Map<String, dynamic>> intents;
      try {
        final response = await _supabase
            .from('payment_intents')
            .select(
              'id, status, provider, provider_payment_id, custom_plan_id, '
              'plan_name, amount, beneficiary_profile_id, created_at',
            )
            .eq('user_id', userId)
            .inFilter('provider', providers)
            .inFilter('status', ['pending', 'matched']);
        intents = List<Map<String, dynamic>>.from(response as List);
      } catch (e) {
        debugPrint('⚠️ PaidIntentsService: could not fetch payment_intents: $e');
        return [];
      }

      for (final intent in intents) {
        try {
          final result = await _processSingleIntent(intent);
          if (result != null) results.add(result);
        } catch (e) {
          debugPrint('⚠️ PaidIntentsService: error processing intent: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ PaidIntentsService.processPaidIntents error: $e');
    } finally {
      _isProcessing = false;
    }

    return results;
  }

  /// Waits, if needed, so at least 65s have passed since the last receipt
  /// this service created — see [_lastActivationAt].
  Future<void> _waitForActivationSlot() async {
    final last = _lastActivationAt;
    if (last == null) return;
    const minGap = Duration(seconds: 65);
    final elapsed = DateTime.now().difference(last);
    if (elapsed < minGap) {
      await Future.delayed(minGap - elapsed);
    }
  }

  Future<PaidIntentActivationResult?> _processSingleIntent(
    Map<String, dynamic> intent,
  ) async {
    final intentId = intent['id'] as String?;
    if (intentId == null) return null;

    final provider = intent['provider'] as String? ?? 'satispay';
    var status = intent['status'] as String?;
    final providerPaymentId = intent['provider_payment_id'] as String?;

    if (status == 'pending') {
      if (provider == 'satispay' &&
          providerPaymentId != null &&
          providerPaymentId.isNotEmpty) {
        // Ask Satispay for the latest status.
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
          return null; // try again next time
        }
      } else {
        // A pending SumUp (or other non-Satispay) intent is reconciled by
        // the server-side matcher, not from here — nothing to do yet.
        return null;
      }
    }

    if (status != 'matched') return null;

    // Space consecutive activations at least 65s apart (see
    // _waitForActivationSlot) BEFORE claiming the intent: if the app is
    // closed while waiting here, the intent is still untouched ('matched')
    // and will be retried on the next call. Claiming it first and waiting
    // afterwards would risk leaving it stuck as claimed-but-unactivated.
    await _waitForActivationSlot();

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
      return null;
    }
    if (claimResult == null) return null;

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
    final customPlanId = claim['custom_plan_id'] as String? ??
        intent['custom_plan_id'] as String?;

    // No wait here: claim_paid_intent has already claimed this intent, so
    // createBatchPaymentAndReceipts must run immediately (see above).
    var confirmationId = '';
    try {
      confirmationId = await SubscriptionService.createBatchPaymentAndReceipts(
        items: [
          {'name': planName, 'price': claimAmount},
        ],
        paymentMethod: intent['provider'] as String? ?? provider,
        amount: claimAmount,
        description: planName,
        discipline: null,
        discipline2: null,
        beneficiaryProfileIdOverride: beneficiaryProfileId,
        paidAt: paidAt,
      );
      if (confirmationId.isNotEmpty) {
        _lastActivationAt = DateTime.now();
      }
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
      return null;
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

    final stillValid = await _isPlanStillValid(
      planName: planName,
      customPlanId: customPlanId,
      paidAt: paidAt,
    );

    return PaidIntentActivationResult(planName: planName, stillValid: stillValid);
  }

  /// Whether the just-activated plan is still within its validity window.
  ///
  /// Entry-based plans (duration_months = 0) and plans whose name contains
  /// "iscrizione" or "annuale" are never considered expired here — their
  /// validity is already handled by the existing logic in
  /// payment_service.dart. A time-based plan is expired when
  /// paid_at + duration_months months <= now.
  Future<bool> _isPlanStillValid({
    required String planName,
    required String? customPlanId,
    required DateTime? paidAt,
  }) async {
    final lowerName = planName.toLowerCase();
    if (lowerName.contains('iscrizione') || lowerName.contains('annuale')) {
      return true;
    }

    if (customPlanId == null || paidAt == null) return true;

    int? durationMonths;
    try {
      final planRow = await _supabase
          .from('custom_subscription_plans')
          .select('duration_months')
          .eq('id', customPlanId)
          .maybeSingle();
      durationMonths = (planRow?['duration_months'] as num?)?.toInt();
    } catch (e) {
      debugPrint(
        '⚠️ PaidIntentsService: could not fetch duration_months for '
        '$customPlanId: $e',
      );
    }

    if (durationMonths == null || durationMonths == 0) return true;

    final expiresAt = DateTime(
      paidAt.year,
      paidAt.month + durationMonths,
      paidAt.day,
      paidAt.hour,
      paidAt.minute,
      paidAt.second,
    );
    return expiresAt.isAfter(DateTime.now());
  }
}
