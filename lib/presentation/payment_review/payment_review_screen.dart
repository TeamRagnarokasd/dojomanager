import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/payment_review_service.dart';

String _formatEuro(num value) => '€ ${NumberFormat('#,##0.00', 'it_IT').format(value)}';

/// "Pagamenti da verificare": SumUp clicks the server couldn't match on its
/// own (`needs_review`), read from `admin_review_intents`. Confirming or
/// rejecting here only updates the click itself — the subscription is
/// still activated the normal way (PaidIntentsService, next time the
/// student's app runs), not from here. Additive and isolated: touches only
/// the three admin RPCs (see PaymentReviewService) — nothing here changes
/// payments, subscriptions, receipts or the Registro di Cassa directly.
class PaymentReviewScreen extends StatefulWidget {
  const PaymentReviewScreen({Key? key}) : super(key: key);

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  final _service = PaymentReviewService.instance;

  bool _isCheckingAccess = true;
  bool _canAccess = false;

  bool _isLoading = true;
  String? _loadError;
  List<PaymentReviewIntent> _intents = [];
  final Map<String, String?> _selectedCandidateByIntent = {};

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    bool canAccess;
    try {
      canAccess =
          await AdminSectionVisibilityService.instance.canAccess('payment_review');
    } catch (_) {
      canAccess = false;
    }
    if (!mounted) return;
    setState(() {
      _canAccess = canAccess;
      _isCheckingAccess = false;
    });
    if (canAccess) await _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final intents = await _service.getIntents();
      if (!mounted) return;
      setState(() {
        _intents = intents;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _afterAction() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fatto: l\'abbonamento si attiva quando l\'allievo apre l\'app.'),
      ),
    );
    await _load();
  }

  Future<void> _confirmWithCandidate(PaymentReviewIntent intent) async {
    final code = _selectedCandidateByIntent[intent.id];
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona prima un pagamento.')),
      );
      return;
    }
    try {
      await _service.confirmIntent(intent.id, transactionCode: code);
      await _afterAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _confirmOtherMethod(PaymentReviewIntent intent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confermare il pagamento?'),
        content: Text(
          'Confermare che ${intent.userName ?? 'questo utente'} ha pagato in altro modo? '
          'L\'abbonamento verrà attivato senza un pagamento SumUp abbinato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.confirmIntent(intent.id);
      await _afterAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Future<void> _reject(PaymentReviewIntent intent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rifiutare questo pagamento?'),
        content: Text(
          'Rifiutare il click di ${intent.userName ?? 'questo utente'}? Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.rejectIntent(intent.id);
      await _afterAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    }
  }

  Widget _buildIntentCard(PaymentReviewIntent intent) {
    final selectedCode = _selectedCandidateByIntent[intent.id];
    final dayFormat = DateFormat('dd/MM', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final candidateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intent.userName ?? 'Utente',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(intent.planName ?? 'Abbonamento'),
            Text(_formatEuro(intent.amount)),
            Text(
              'Cliccato il ${dayFormat.format(intent.clickedAt)} alle '
              '${timeFormat.format(intent.clickedAt)}',
            ),
            if (intent.notes != null && intent.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(intent.notes!),
            ],
            if (intent.candidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Pagamenti possibili', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final candidate in intent.candidates)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: candidate.code,
                  groupValue: selectedCode,
                  onChanged: (value) {
                    setState(() => _selectedCandidateByIntent[intent.id] = value);
                  },
                  title: Text(candidateFormat.format(candidate.occurredAt)),
                  subtitle: Text(
                    (candidate.description != null && candidate.description!.trim().isNotEmpty)
                        ? '${candidate.code} · ${candidate.description}'
                        : candidate.code,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: (intent.candidates.isEmpty || selectedCode == null)
                      ? null
                      : () => _confirmWithCandidate(intent),
                  child: const Text('Conferma con questo pagamento'),
                ),
                OutlinedButton(
                  onPressed: () => _confirmOtherMethod(intent),
                  child: const Text('Conferma: ha pagato in altro modo'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _reject(intent),
                  child: const Text('Rifiuta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagamenti da verificare')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Non hai accesso a questa sezione.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pagamenti da verificare')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Riprova')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _intents.isEmpty
                      ? ListView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewPadding.bottom + 24,
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(child: Text('Nessun pagamento da verificare.')),
                            ),
                          ],
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            MediaQuery.of(context).viewPadding.bottom + 24,
                          ),
                          children: _intents.map(_buildIntentCard).toList(),
                        ),
                ),
    );
  }
}
