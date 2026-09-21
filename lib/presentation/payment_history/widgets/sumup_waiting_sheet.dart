import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/paid_intents_service.dart';

enum _SumUpWaitStage { checking, needsReview, timedOut, reported }

/// Shown instead of PaymentConfirmationDialog when the user returns from a
/// SumUp payment link and 'sumup_auto_confirm' is on: the backend matches
/// the payment on its own, so this only watches the click's own
/// `payment_intents` row (never calls SumUp itself) and reacts:
///
/// - 'matched'/'confirmed': activates the subscription the same way
///   Satispay already does (PaidIntentsService.processPaidIntents), shows
///   the same success toast, then closes.
/// - 'needs_review': tells the student the payment will be checked by an
///   admin; polling stops.
/// - still nothing after 150s: offers "Ho pagato ma non si attiva"
///   (report_intent_paid) alongside "Chiudi".
///
/// Not dismissible by tapping outside, dragging or the back button — see
/// the showModalBottomSheet call in payment_history.dart — only its own
/// buttons close it.
class SumUpWaitingSheet extends StatefulWidget {
  const SumUpWaitingSheet({Key? key, this.onConfirmed}) : super(key: key);

  /// Called right before closing after a successful activation, so the
  /// caller can refresh its own payment list — mirrors
  /// PaymentConfirmationDialog.onConfirmed.
  final VoidCallback? onConfirmed;

  @override
  State<SumUpWaitingSheet> createState() => _SumUpWaitingSheetState();
}

class _SumUpWaitingSheetState extends State<SumUpWaitingSheet> {
  static const _pollInterval = Duration(seconds: 6);
  static const _timeout = Duration(seconds: 150);
  static const _fallbackLookback = Duration(hours: 6);

  final SupabaseClient _client = Supabase.instance.client;

  Timer? _timer;
  DateTime? _startedAt;
  String? _intentId;
  _SumUpWaitStage _stage = _SumUpWaitStage.checking;
  bool _isReporting = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    String? intentId;
    try {
      final prefs = await SharedPreferences.getInstance();
      intentId = prefs.getString('pendingIntentId');
    } catch (_) {
      intentId = null;
    }
    if (intentId == null || intentId.isEmpty) {
      intentId = await _findFallbackIntentId();
    }
    if (!mounted) return;
    if (intentId == null) {
      // Nothing to watch — guide the user the same way a timeout would,
      // rather than leaving a spinner with nothing behind it.
      setState(() => _stage = _SumUpWaitStage.timedOut);
      return;
    }
    _intentId = intentId;
    await _checkOnce();
    if (!mounted) return;
    if (_stage == _SumUpWaitStage.checking) {
      _timer = Timer.periodic(_pollInterval, (_) => _checkOnce());
    }
  }

  Future<String?> _findFallbackIntentId() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final since = DateTime.now().subtract(_fallbackLookback);
      final rows = await _client
          .from('payment_intents')
          .select('id')
          .eq('user_id', userId)
          .eq('provider', 'sumup')
          .eq('status', 'pending')
          .gte('created_at', since.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1);
      final list = rows as List;
      if (list.isEmpty) return null;
      return (list.first as Map<String, dynamic>)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkOnce() async {
    final intentId = _intentId;
    final startedAt = _startedAt;
    if (intentId == null || startedAt == null || !mounted) return;

    if (DateTime.now().difference(startedAt) >= _timeout) {
      _timer?.cancel();
      if (mounted) setState(() => _stage = _SumUpWaitStage.timedOut);
      return;
    }

    try {
      final row = await _client
          .from('payment_intents')
          .select('status, provider_payment_id')
          .eq('id', intentId)
          .maybeSingle();
      var status = row?['status'] as String?;
      final providerPaymentId = row?['provider_payment_id'] as String?;

      if (providerPaymentId != null && providerPaymentId.isNotEmpty) {
        // This click was created via 'sumup/create-payment', so its
        // provider_payment_id is already known — ask SumUp directly for
        // the latest status instead of waiting for the server-side
        // matcher, same as PaidIntentsService does for the reconciliation
        // pass.
        try {
          final checkResponse = await _client.functions.invoke(
            'sumup/check',
            body: {'intent_id': intentId},
          );
          final data = checkResponse.data;
          if (data is Map && data['status'] is String) {
            status = data['status'] as String;
          }
        } catch (_) {
          // Keep the status just read above — retried on the next tick.
        }
      }

      if (status == 'matched' || status == 'confirmed') {
        _timer?.cancel();
        await PaidIntentsService.instance.processPaidIntents();
        if (!mounted) return;
        Fluttertoast.showToast(
          msg: 'Abbonamento attivato',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        widget.onConfirmed?.call();
        if (mounted) Navigator.pop(context);
      } else if (status == 'needs_review') {
        _timer?.cancel();
        if (mounted) setState(() => _stage = _SumUpWaitStage.needsReview);
      }
      // 'pending' (or a transient read failure below): keep polling until
      // the timeout above takes over.
    } catch (_) {
      // Transient error — retried on the next tick.
    }
  }

  Future<void> _reportNotActivated() async {
    final intentId = _intentId;
    if (intentId == null || _isReporting) return;
    setState(() => _isReporting = true);
    try {
      await _client.rpc('report_intent_paid', params: {'p_intent_id': intentId});
      if (!mounted) return;
      setState(() {
        _stage = _SumUpWaitStage.reported;
        _isReporting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la segnalazione: $e')),
      );
    }
  }

  List<Widget> _buildStageContent() {
    switch (_stage) {
      case _SumUpWaitStage.checking:
        return const [
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 16),
          Text('Sto controllando il pagamento…', textAlign: TextAlign.center),
        ];
      case _SumUpWaitStage.needsReview:
        return [
          const Text(
            'Il pagamento è in verifica. Ti attiviamo l\'abbonamento appena controllato.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ),
        ];
      case _SumUpWaitStage.timedOut:
        return [
          const Text(
            'Non vedo ancora il pagamento. Se hai pagato, l\'abbonamento si attiva '
            'da solo appena arriva: può volerci qualche minuto e puoi chiudere l\'app.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isReporting ? null : _reportNotActivated,
              child: _isReporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ho pagato ma non si attiva'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ),
        ];
      case _SumUpWaitStage.reported:
        return [
          const Text(
            'Segnalazione inviata: il pagamento sarà controllato',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Chiudi'),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._buildStageContent(),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Non ho pagato'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
