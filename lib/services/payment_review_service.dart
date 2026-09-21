import 'package:supabase_flutter/supabase_flutter.dart';

/// One SumUp payment already recorded (`provider_transactions`) that could
/// be the one behind a click still `needs_review` — same amount, occurred
/// close enough to the click, and not already claimed by another intent.
class PaymentReviewCandidate {
  const PaymentReviewCandidate({
    required this.code,
    required this.occurredAt,
    this.description,
  });

  final String code;
  final DateTime occurredAt;
  final String? description;

  factory PaymentReviewCandidate.fromMap(Map<String, dynamic> map) =>
      PaymentReviewCandidate(
        code: map['code'] as String,
        occurredAt: DateTime.parse(map['occurred_at'] as String),
        description: map['description'] as String?,
      );
}

/// One SumUp `payment_intents` click stuck in `needs_review` — reported by
/// the student ("ho pagato ma non si attiva") or left unmatched by the
/// server past its own reconciliation window.
class PaymentReviewIntent {
  const PaymentReviewIntent({
    required this.id,
    required this.status,
    this.planName,
    required this.amount,
    required this.clickedAt,
    this.notes,
    required this.userId,
    this.beneficiaryProfileId,
    this.userName,
    required this.candidates,
  });

  final String id;
  final String status;
  final String? planName;
  final double amount;
  final DateTime clickedAt;
  final String? notes;
  final String userId;
  final String? beneficiaryProfileId;
  final String? userName;
  final List<PaymentReviewCandidate> candidates;

  factory PaymentReviewIntent.fromMap(Map<String, dynamic> map) =>
      PaymentReviewIntent(
        id: map['id'] as String,
        status: map['status'] as String,
        planName: map['plan_name'] as String?,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        clickedAt: DateTime.parse(map['clicked_at'] as String),
        notes: map['notes'] as String?,
        userId: map['user_id'] as String,
        beneficiaryProfileId: map['beneficiary_profile_id'] as String?,
        userName: map['user_name'] as String?,
        candidates: ((map['candidates'] as List?) ?? const [])
            .map((e) => PaymentReviewCandidate.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Client for the "Pagamenti da verificare" admin queue: three RPCs
/// (admin_review_intents / admin_confirm_intent / admin_reject_intent),
/// all already scoped server-side to admins only. Additive and isolated —
/// confirming or rejecting here only changes the click's own
/// payment_intents row; the actual subscription activation still happens
/// the normal way (PaidIntentsService, the next time the student's app
/// runs), so nothing here touches payments, subscriptions, receipts or the
/// Registro di Cassa directly.
class PaymentReviewService {
  PaymentReviewService._();
  static final PaymentReviewService instance = PaymentReviewService._();

  static final SupabaseClient _client = Supabase.instance.client;

  Future<List<PaymentReviewIntent>> getIntents() async {
    final result = await _client.rpc('admin_review_intents');
    final list = (result as List?) ?? const [];
    return list
        .map((e) => PaymentReviewIntent.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> confirmIntent(String intentId, {String? transactionCode}) async {
    final result = await _client.rpc('admin_confirm_intent', params: {
      'p_intent_id': intentId,
      'p_transaction_code': transactionCode,
    });
    return result as bool? ?? false;
  }

  Future<bool> rejectIntent(String intentId) async {
    final result = await _client
        .rpc('admin_reject_intent', params: {'p_intent_id': intentId});
    return result as bool? ?? false;
  }
}
