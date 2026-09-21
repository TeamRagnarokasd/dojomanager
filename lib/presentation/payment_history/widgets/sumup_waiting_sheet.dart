import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/paid_intents_service.dart';

enum _SumUpWaitStage { checking, notFound, needsReview, timedOut, reported }

/// Shown instead of PaymentConfirmationDialog when the user returns from a
/// SumUp or Satispay payment page and the click can be watched
/// automatically (see subscription_plan_selection.dart/payment_history.dart
/// for exactly when): watches the click's own `payment_intents` row and,
/// when it has a `provider_payment_id`, also asks the matching provider
/// directly (`sumup/check` or `satispay/check`) for the latest status.
///
/// - 'matched'/'confirmed': activates the subscription
///   (PaidIntentsService.processPaidIntents), shows the same success toast,
///   then closes.
/// - still pending after 5s: asks "hai pagato?" — "Sì" rechecks for 30
///   more seconds, then reports the click on its own (report_intent_paid)
///   if still nothing; "No" just closes.
/// - 'needs_review': tells the student the payment will be checked by an
///   admin; polling stops.
/// - nothing resolved within 2 minutes of opening: tells the student to
///   contact the office.
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
  // Payments that actually went through confirm almost instantly, so the
  // first window is short and fast; the question only appears once that
  // window has passed with nothing resolved.
  static const _initialCheckDuration = Duration(seconds: 5);
  static const _initialPollInterval = Duration(seconds: 3);
  static const _backgroundPollInterval = Duration(seconds: 6);
  static const _recheckDuration = Duration(seconds: 30);
  static const _absoluteTimeout = Duration(minutes: 2);
  static const _fallbackLookback = Duration(hours: 6);

  final SupabaseClient _client = Supabase.instance.client;

  Timer? _pollTimer;
  Timer? _absoluteTimer;
  Timer? _phaseTimer;
  String? _intentId;
  _SumUpWaitStage _stage = _SumUpWaitStage.checking;

  // True only while re-checking after the student tapped "Sì, ho pagato"
  // — same _stage.checking UI, different message.
  bool _isRechecking = false;
  bool _reportFailed = false;

  // Set as soon as activation or closing starts, so an in-flight sequence
  // (e.g. _onYesIPaid's own immediate _checkOnce resolving to a match)
  // never re-arms a timer on a sheet that's already on its way out —
  // _stage alone doesn't change during activation/closing.
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _absoluteTimer?.cancel();
    _phaseTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _absoluteTimer = Timer(_absoluteTimeout, _onAbsoluteTimeout);

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
      // Nothing to watch — go straight to the question. A "Sì" here has
      // nothing to recheck or report against, so it goes straight to
      // timedOut instead of the usual recheck window.
      setState(() => _stage = _SumUpWaitStage.notFound);
      return;
    }
    _intentId = intentId;

    // First check fires immediately; further checks follow every 3s until
    // the 5s window elapses, then the question shows if nothing resolved.
    unawaited(_checkOnce());
    _pollTimer = Timer.periodic(_initialPollInterval, (_) => _checkOnce());
    _phaseTimer = Timer(_initialCheckDuration, _onInitialCheckTimeout);
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
          .inFilter('provider', ['sumup', 'satispay'])
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

  void _onInitialCheckTimeout() {
    if (!mounted ||
        _isClosing ||
        _stage != _SumUpWaitStage.checking ||
        _isRechecking) {
      return;
    }
    _pollTimer?.cancel();
    setState(() => _stage = _SumUpWaitStage.notFound);
    _pollTimer = Timer.periodic(_backgroundPollInterval, (_) => _checkOnce());
  }

  void _onAbsoluteTimeout() {
    if (!mounted || _isClosing || _stage == _SumUpWaitStage.reported) return;
    _pollTimer?.cancel();
    _phaseTimer?.cancel();
    setState(() => _stage = _SumUpWaitStage.timedOut);
  }

  Future<void> _checkOnce() async {
    final intentId = _intentId;
    if (intentId == null || !mounted || _isClosing) return;

    try {
      final row = await _client
          .from('payment_intents')
          .select('status, provider, provider_payment_id')
          .eq('id', intentId)
          .maybeSingle();
      var status = row?['status'] as String?;
      final provider = row?['provider'] as String?;
      final providerPaymentId = row?['provider_payment_id'] as String?;

      if (providerPaymentId != null &&
          providerPaymentId.isNotEmpty &&
          (provider == 'sumup' || provider == 'satispay')) {
        // This click was created via '<provider>/create-payment', so its
        // provider_payment_id is already known — ask the provider directly
        // for the latest status instead of waiting for the server-side
        // matcher, same as PaidIntentsService does for the reconciliation
        // pass.
        try {
          final checkResponse = await _client.functions.invoke(
            '$provider/check',
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
        await _activate();
      } else if (status == 'needs_review') {
        _pollTimer?.cancel();
        _phaseTimer?.cancel();
        _absoluteTimer?.cancel();
        if (mounted) setState(() => _stage = _SumUpWaitStage.needsReview);
      }
      // 'pending' (or a transient read failure below): keep polling until
      // whichever timeout above takes over.
    } catch (_) {
      // Transient error — retried on the next tick.
    }
  }

  Future<void> _activate() async {
    _isClosing = true;
    _pollTimer?.cancel();
    _phaseTimer?.cancel();
    _absoluteTimer?.cancel();
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
    if (mounted) await _closeSheet();
  }

  /// "Sì, ho pagato": rechecks for 30 more seconds before falling back to
  /// reporting the click automatically — no manual button for that.
  Future<void> _onYesIPaid() async {
    final intentId = _intentId;
    if (intentId == null) {
      // Nothing to actually recheck or report against.
      _pollTimer?.cancel();
      _absoluteTimer?.cancel();
      if (mounted) setState(() => _stage = _SumUpWaitStage.timedOut);
      return;
    }

    _pollTimer?.cancel();
    setState(() {
      _stage = _SumUpWaitStage.checking;
      _isRechecking = true;
    });

    await _checkOnce();
    if (!mounted || _isClosing || _stage != _SumUpWaitStage.checking) return;
    _pollTimer = Timer.periodic(_backgroundPollInterval, (_) => _checkOnce());
    _phaseTimer = Timer(_recheckDuration, _onRecheckTimeout);
  }

  void _onRecheckTimeout() {
    if (!mounted ||
        _isClosing ||
        _stage != _SumUpWaitStage.checking ||
        !_isRechecking) {
      return;
    }
    _pollTimer?.cancel();
    unawaited(_reportNotActivated());
  }

  Future<void> _reportNotActivated() async {
    final intentId = _intentId;
    if (intentId == null) return;
    try {
      final result = await _client.rpc(
        'report_intent_paid',
        params: {'p_intent_id': intentId},
      );
      if (!mounted) return;
      setState(() {
        _stage = _SumUpWaitStage.reported;
        _reportFailed = result != true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _SumUpWaitStage.reported;
        _reportFailed = true;
      });
    } finally {
      _absoluteTimer?.cancel();
    }
  }

  /// Closes only this sheet and drops the pending-payment bookkeeping in
  /// SharedPreferences — every exit (a button, or a successful activation
  /// in _checkOnce) goes through here, so nothing is left that could make
  /// a later resume/route event reopen this same sheet, and no polling
  /// tick can fire once it's gone.
  Future<void> _closeSheet() async {
    _isClosing = true;
    _pollTimer?.cancel();
    _absoluteTimer?.cancel();
    _phaseTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isPaymentPending');
      await prefs.remove('pendingIntentId');
      await prefs.remove('pendingPlanTitle');
      await prefs.remove('pendingPlanId');
      await prefs.remove('pendingPlanAmount');
    } catch (_) {
      // Best-effort cleanup — nothing more to do if this fails.
    }
    if (mounted) Navigator.of(context).pop();
  }

  List<Widget> _buildStageContent(BuildContext context) {
    switch (_stage) {
      case _SumUpWaitStage.checking:
        return [
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(
            _isRechecking ? 'Controllo ancora…' : 'Sto verificando il pagamento…',
            textAlign: TextAlign.center,
          ),
          if (!_isRechecking) ...[
            const SizedBox(height: 8),
            Text(
              'Di solito bastano pochi secondi.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ];
      case _SumUpWaitStage.notFound:
        return [
          Text(
            'Non risulta ancora nessun pagamento',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hai completato il pagamento?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onYesIPaid,
              child: const Text('Sì, ho pagato'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _closeSheet,
              child: const Text('No, non ho pagato'),
            ),
          ),
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
              onPressed: _closeSheet,
              child: const Text('Chiudi'),
            ),
          ),
        ];
      case _SumUpWaitStage.timedOut:
        return [
          const Text(
            'Non vedo il pagamento. Contatta la segreteria.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _closeSheet,
              child: const Text('Chiudi'),
            ),
          ),
        ];
      case _SumUpWaitStage.reported:
        return [
          Text(
            _reportFailed
                ? 'Non sono riuscito a segnalare il pagamento: contatta la segreteria.'
                : 'Ho segnalato il tuo pagamento: lo controlleremo e l\'abbonamento si attiva appena verificato. Puoi chiudere l\'app.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _closeSheet,
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
            children: _buildStageContent(context),
          ),
        ),
      ),
    );
  }
}
