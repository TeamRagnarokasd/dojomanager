import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_flags_service.dart';
import 'payment_block_error.dart' show PaymentBlockError, isDuplicateSumupConfirmationError;
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

  /// Set when the last activation attempt was blocked by one of the two
  /// server-side payment checks (see payment_block_error.dart), so the UI
  /// that called processPaidIntents() can show a clear dialog instead of a
  /// false "Abbonamento attivato" toast. Reset at the start of every call.
  PaymentBlockError? lastBlockingError;

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
    lastBlockingError = null;
    final results = <PaidIntentActivationResult>[];

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // SumUp intents only join in when 'sumup_auto_confirm' is on — off,
      // this query is identical to before (satispay only). Read reliably
      // (one retry on failure, see isEnabledReliable): with no manual
      // fallback left for SumUp, a transient read failure here must never
      // silently drop an already-matched intent from this query and leave
      // it stuck forever.
      final sumupEnabled = await FeatureFlagsService.instance
          .isEnabledReliable('sumup_auto_confirm');
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
      } else if (provider == 'sumup' &&
          providerPaymentId != null &&
          providerPaymentId.isNotEmpty) {
        // This click was created via 'sumup/create-payment' (the new
        // single-page flow), so its own provider_payment_id is known —
        // ask SumUp for the latest status the same way as Satispay above.
        try {
          final checkResponse = await _supabase.functions.invoke(
            'sumup/check',
            body: {'intent_id': intentId},
          );
          final data = checkResponse.data;
          if (data is Map && data['status'] is String) {
            status = data['status'] as String;
          }
        } catch (e) {
          debugPrint(
            '⚠️ PaidIntentsService: sumup/check failed for $intentId: $e',
          );
          return null; // try again next time
        }
      } else {
        // A pending intent with no provider_payment_id yet (fixed-link
        // SumUp) is reconciled by the server-side matcher, not from here —
        // nothing to do yet.
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
    final effectivePaymentMethod = intent['provider'] as String? ?? provider;
    final effectiveBeneficiaryId =
        beneficiaryProfileId ?? _supabase.auth.currentUser?.id;

    // 🔒 Controllo anti-doppione PRIMA di creare una nuova conferma: se un
    // tentativo precedente per questo stesso intento è già andato a buon
    // fine lato database ma questo dispositivo non l'ha mai saputo (es. la
    // risposta di rete si è persa dopo un insert già riuscito, o un passo
    // successivo — come la ricevuta — è fallito facendo rilasciare
    // l'intento per un retry), non ricreare da zero un'altra riga
    // payment_confirmations: basta agganciare quella già esistente.
    final existingConfirmation = await _findRecentConfirmedDuplicate(
      paymentMethod: effectivePaymentMethod,
      amount: claimAmount,
      beneficiaryId: effectiveBeneficiaryId,
      customPlanId: customPlanId,
    );
    if (existingConfirmation != null) {
      debugPrint(
        '⚠️ PaidIntentsService: intent $intentId ha già una conferma recente '
        '(${existingConfirmation['id']}) — aggancio quella invece di crearne '
        'una nuova.',
      );
      return _attachExistingConfirmation(
        intentId: intentId,
        confirmationRow: existingConfirmation,
        planName: planName,
        customPlanId: customPlanId,
        paidAt: paidAt,
      );
    }

    // No wait here: claim_paid_intent has already claimed this intent, so
    // createBatchPaymentAndReceipts must run immediately (see above).
    var confirmationId = '';
    try {
      confirmationId = await SubscriptionService.createBatchPaymentAndReceipts(
        items: [
          {'name': planName, 'price': claimAmount},
        ],
        paymentMethod: effectivePaymentMethod,
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
      // La rete di sicurezza del database (vedi migrazione
      // fix_doppio_pagamento_sumup_studente) ha bloccato questo tentativo
      // perché una conferma per lo stesso acquisto esiste già: non è un
      // fallimento da segnalare come errore, è un doppio tentativo che va
      // semplicemente agganciato alla conferma vera già creata.
      if (isDuplicateSumupConfirmationError(e)) {
        final duplicate = await _findRecentConfirmedDuplicate(
          paymentMethod: effectivePaymentMethod,
          amount: claimAmount,
          beneficiaryId: effectiveBeneficiaryId,
          customPlanId: customPlanId,
        );
        if (duplicate != null) {
          return _attachExistingConfirmation(
            intentId: intentId,
            confirmationRow: duplicate,
            planName: planName,
            customPlanId: customPlanId,
            paidAt: paidAt,
          );
        }
      }
      debugPrint(
        '⚠️ PaidIntentsService: createBatchPaymentAndReceipts failed for '
        '$intentId: $e',
      );
      lastBlockingError ??= PaymentBlockError.fromError(e);
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

  /// Cerca una riga payment_confirmations già 'confirmed' per lo stesso
  /// beneficiario, importo e piano, creata negli ultimi 5 minuti — usata sia
  /// come controllo preventivo prima di creare una nuova conferma, sia per
  /// recuperare senza errori quando la rete di sicurezza del database (vedi
  /// migrazione fix_doppio_pagamento_sumup_studente) blocca un tentativo
  /// perché ne esiste già una. La finestra (5 minuti) è volutamente più
  /// larga dei 3 minuti del trigger, per coprire anche il caso in cui questo
  /// controllo lato app sia l'unico a intercettare il doppione (retry più
  /// lento, es. al resume dell'app). Fallisce aperto: un errore qui non deve
  /// bloccare un pagamento genuino, semplicemente si procede come prima.
  Future<Map<String, dynamic>?> _findRecentConfirmedDuplicate({
    required String paymentMethod,
    required double amount,
    required String? beneficiaryId,
    required String? customPlanId,
  }) async {
    if (beneficiaryId == null) return null;
    try {
      final sinceIso = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 5))
          .toIso8601String();
      final beneficiaryFilter = 'beneficiary_profile_id.eq.$beneficiaryId,'
          'and(beneficiary_profile_id.is.null,user_id.eq.$beneficiaryId)';
      final baseQuery = _supabase
          .from('payment_confirmations')
          .select('id, batch_transaction_id')
          .eq('payment_method', paymentMethod)
          .eq('status', 'confirmed')
          .eq('amount', amount)
          .gte('created_at', sinceIso)
          .or(beneficiaryFilter);
      final rows = await (customPlanId != null
              ? baseQuery.eq('custom_plan_id', customPlanId)
              : baseQuery)
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return null;
      return Map<String, dynamic>.from(list.first as Map);
    } catch (e) {
      debugPrint('⚠️ PaidIntentsService: duplicate check failed: $e');
      return null;
    }
  }

  /// Aggancia l'intento a una conferma già esistente invece di crearne una
  /// nuova (vedi _findRecentConfirmedDuplicate) e ritorna lo stesso tipo di
  /// risultato di un'attivazione normale, così il chiamante mostra il
  /// consueto messaggio di successo invece di un errore.
  Future<PaidIntentActivationResult?> _attachExistingConfirmation({
    required String intentId,
    required Map<String, dynamic> confirmationRow,
    required String planName,
    required String? customPlanId,
    required DateTime? paidAt,
  }) async {
    try {
      await _supabase.rpc(
        'attach_intent_confirmation',
        params: {
          'p_intent_id': intentId,
          'p_confirmation_id': confirmationRow['id'] as String? ??
              confirmationRow['batch_transaction_id'] as String? ??
              '',
        },
      );
    } catch (e) {
      debugPrint(
        '⚠️ PaidIntentsService: attach_intent_confirmation (doppione) '
        'failed for $intentId: $e',
      );
      // La conferma esiste già ed è quella corretta: non agganciarla al
      // record dell'intento è solo un problema di bookkeeping, non deve
      // impedire di mostrare il successo all'allievo.
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
