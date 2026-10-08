import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Shown right before falling back to a fixed payment link, whichever
/// provider or screen offers it — kept in one place so the wording never
/// drifts between the SumUp and Satispay fallback flows.
const String kManualPaymentModeMessage =
    'Pagamento in modalità manuale: dopo il pagamento torna nell\'app e '
    'conferma.';

/// One purchase the student tapped but hasn't confirmed or cancelled yet.
/// Multiple can coexist — e.g. tapping "Iscrizione" (€35) and then "Doppio
/// corso" (€105) one after another — each tap adds its own entry instead of
/// overwriting a single set of SharedPreferences values, which used to lose
/// every purchase but the last one tapped.
class PendingPurchase {
  final String id;
  final String? planId;
  final String planTitle;
  final double amount;
  final String method; // 'sumup' | 'satispay'
  final String? intentId;
  final String? beneficiaryId;
  final DateTime startedAt;

  const PendingPurchase({
    required this.id,
    this.planId,
    required this.planTitle,
    required this.amount,
    required this.method,
    this.intentId,
    this.beneficiaryId,
    required this.startedAt,
  });

  PendingPurchase copyWith({String? intentId}) => PendingPurchase(
        id: id,
        planId: planId,
        planTitle: planTitle,
        amount: amount,
        method: method,
        intentId: intentId ?? this.intentId,
        beneficiaryId: beneficiaryId,
        startedAt: startedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'planTitle': planTitle,
        'amount': amount,
        'method': method,
        'intentId': intentId,
        'beneficiaryId': beneficiaryId,
        'startedAt': startedAt.toIso8601String(),
      };

  factory PendingPurchase.fromJson(Map<String, dynamic> json) =>
      PendingPurchase(
        id: json['id'] as String,
        planId: json['planId'] as String?,
        planTitle: json['planTitle'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        method: json['method'] as String? ?? 'sumup',
        intentId: json['intentId'] as String?,
        beneficiaryId: json['beneficiaryId'] as String?,
        startedAt:
            DateTime.tryParse(json['startedAt'] as String? ?? '') ??
                DateTime.now(),
      );
}

/// Persists the list of pending purchases as a JSON array in
/// SharedPreferences, replacing the old single-purchase flat keys
/// (isPaymentPending/pendingPlanId/pendingPlanTitle/pendingPlanAmount/
/// pendingPaymentMethod/pendingIntentId) that could only remember one
/// purchase at a time.
class PendingPurchasesService {
  PendingPurchasesService._();

  static const _key = 'pendingPurchasesV2';

  // Serializes every read-modify-write below (add/setIntentId/remove/
  // takeNext) within this isolate, so two calls landing close together
  // (e.g. a plan tap adding a new entry while a resume handler is mid-way
  // through takeNext for a different one) never interleave their
  // getAll()/_saveAll() pair and silently drop or resurrect an entry.
  static Future<void> _lock = Future.value();

  static Future<T> _runExclusive<T>(Future<T> Function() action) {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  static Future<List<PendingPurchase>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (e) => PendingPurchase.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<PendingPurchase> purchases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(purchases.map((p) => p.toJson()).toList()),
    );
  }

  /// Adds a new pending purchase (never overwrites existing ones) and
  /// returns it, so the caller can later call [setIntentId] once an intent
  /// id becomes known asynchronously (the old fixed-link flow creates the
  /// payment_intents row only after launchUrl already succeeded).
  static Future<PendingPurchase> add({
    String? planId,
    required String planTitle,
    required double amount,
    required String method,
    String? intentId,
    String? beneficiaryId,
  }) {
    final purchase = PendingPurchase(
      id: const Uuid().v4(),
      planId: planId,
      planTitle: planTitle,
      amount: amount,
      method: method,
      intentId: intentId,
      beneficiaryId: beneficiaryId,
      startedAt: DateTime.now(),
    );
    return _runExclusive(() async {
      final all = await getAll();
      all.add(purchase);
      await _saveAll(all);
      return purchase;
    });
  }

  /// Fills in the intent id once it becomes known after [add] already ran.
  static Future<void> setIntentId(String purchaseId, String intentId) {
    return _runExclusive(() async {
      final all = await getAll();
      final index = all.indexWhere((p) => p.id == purchaseId);
      if (index == -1) return;
      all[index] = all[index].copyWith(intentId: intentId);
      await _saveAll(all);
    });
  }

  /// Re-queues a purchase that was claimed via [takeNext] but couldn't be
  /// shown after all (e.g. the context went away right after claiming it)
  /// — preserves its original id and startedAt so it keeps its place in
  /// line instead of looking like a brand new purchase.
  static Future<void> requeue(PendingPurchase purchase) {
    return _runExclusive(() async {
      final all = await getAll();
      all.add(purchase);
      await _saveAll(all);
    });
  }

  /// Removes one purchase outright (e.g. the create-payment call itself
  /// failed before any redirect ever happened) — never wipes the whole
  /// list, so other pending purchases survive.
  static Future<void> remove(String purchaseId) {
    return _runExclusive(() async {
      final all = await getAll();
      all.removeWhere((p) => p.id == purchaseId);
      await _saveAll(all);
    });
  }

  /// Atomically removes and returns the oldest pending purchase, or null if
  /// none remain. This is how a purchase gets "claimed" for display: once
  /// taken, it is gone from the persisted list even before the student
  /// confirms or cancels it, so a second concurrent check (another screen,
  /// or the app resuming again before this one is dismissed) never shows
  /// the same purchase twice.
  static Future<PendingPurchase?> takeNext() {
    return _runExclusive(() async {
      final all = await getAll();
      if (all.isEmpty) return null;
      all.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      final next = all.removeAt(0);
      await _saveAll(all);
      return next;
    });
  }

  static Future<bool> hasAny() async => (await getAll()).isNotEmpty;
}
