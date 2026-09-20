import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/asd_documents_service.dart' show AsdDocument;
import '../../../services/asd_governance_service.dart';
import '../../../services/social_events_service.dart';
import '../../asd_deadlines/document_generation/asd_document_generation_screen.dart';
import '../../asd_documents_archive/widgets/asd_document_actions.dart';
import 'add_expense_screen.dart';

String _formatEuro(num value) => '€ ${NumberFormat('#,##0.00', 'it_IT').format(value)}';

String _formatAmountPlain(num value) => NumberFormat('#,##0.00', 'it_IT').format(value);

String _paymentMethodLowerLabel(String key) {
  switch (key) {
    case 'carta_asd':
      return 'carta ASD';
    case 'contanti':
      return 'contanti';
    case 'bonifico':
      return 'bonifico';
    default:
      return 'altro';
  }
}

/// One `asd_social_events` row: its data (editable/deletable, principal
/// admin only), its expenses (with receipts filed in the Archivio
/// documenti), and the two verbale/ratifica generation buttons that reuse
/// AsdDocumentGenerationScreen with pre-filled placeholders. Additive and
/// isolated — see social_events_screen.dart's doc comment.
class SocialEventDetailScreen extends StatefulWidget {
  const SocialEventDetailScreen({
    Key? key,
    required this.event,
    required this.isPrincipalAdmin,
  }) : super(key: key);

  final SocialEvent event;
  final bool isPrincipalAdmin;

  @override
  State<SocialEventDetailScreen> createState() => _SocialEventDetailScreenState();
}

class _SocialEventDetailScreenState extends State<SocialEventDetailScreen> {
  final _service = SocialEventsService.instance;
  final _governanceService = AsdGovernanceService.instance;

  late SocialEvent _event;
  bool _isLoadingExpenses = true;
  String? _loadError;
  List<SocialEventExpense> _expenses = [];
  bool _isGeneratingDocument = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadExpenses();
  }

  double get _totalExpenses => _expenses.fold<double>(0, (sum, e) => sum + e.amount);

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoadingExpenses = true;
      _loadError = null;
    });
    try {
      final expenses = await _service.getExpenses(_event.id);
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _isLoadingExpenses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento delle spese: $e';
        _isLoadingExpenses = false;
      });
    }
  }

  Future<void> _reloadEvent() async {
    try {
      final event = await _service.getEvent(_event.id);
      if (!mounted) return;
      setState(() => _event = event);
    } catch (_) {
      // Not critical — the screen keeps showing the last known state.
    }
  }

  Future<void> _editEvent() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: _event.title);
    final placeController = TextEditingController(text: _event.place ?? '');
    final participantsController =
        TextEditingController(text: _event.participants?.toString() ?? '');
    final notesController = TextEditingController(text: _event.notes ?? '');
    var eventDate = _event.eventDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifica evento'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titolo'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
                    subtitle: Text(DateFormat('dd/MM/yyyy', 'it_IT').format(eventDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: eventDate,
                        firstDate: DateTime(DateTime.now().year - 5),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked != null) setDialogState(() => eventDate = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: placeController,
                    decoration: const InputDecoration(labelText: 'Luogo (facoltativo)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: participantsController,
                    decoration: const InputDecoration(labelText: 'Partecipanti (facoltativo)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Note (facoltative)'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await _service.updateEvent(
        _event.id,
        title: titleController.text,
        eventDate: eventDate,
        place: placeController.text,
        participants: int.tryParse(participantsController.text.trim()),
        notes: notesController.text,
      );
      await _reloadEvent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  Future<void> _confirmDeleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questo evento?'),
        content: Text(
          'Eliminare "${_event.title}"? Anche le spese collegate verranno eliminate. '
          'Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteEvent(_event.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
      );
    }
  }

  Future<void> _openAddExpense() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddExpenseScreen(eventId: _event.id, eventTitle: _event.title),
      ),
    );
    if (saved == true) await _loadExpenses();
  }

  Future<void> _confirmDeleteExpense(SocialEventExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa spesa?'),
        content: Text(
          'Eliminare la spesa di ${_formatEuro(expense.amount)} presso ${expense.vendor}? '
          'Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteExpense(expense.id);
      await _loadExpenses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _openDocument(String documentId) async {
    try {
      final document = await _service.getDocumentById(documentId);
      if (document == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento non trovato.')),
        );
        return;
      }
      if (!mounted) return;
      await openAsdDocument(context, document);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il documento: $e')),
      );
    }
  }

  Map<String, String> _buildInitialValues({required bool isRatifica}) {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    final total = _totalExpenses;
    final notes = _event.notes;
    final descrizioneEvento =
        (notes != null && notes.trim().isNotEmpty) ? '${_event.title} - ${notes.trim()}' : _event.title;

    final values = <String, String>{
      'data_evento': dayFormat.format(_event.eventDate),
      'luogo_evento': _event.place ?? '',
      'descrizione_evento': descrizioneEvento,
      'partecipanti': _event.participants?.toString() ?? '',
    };
    if (isRatifica) {
      final chronological = [..._expenses]
        ..sort((a, b) => a.expenseDate.compareTo(b.expenseDate));
      values['spesa_totale'] = _formatAmountPlain(total);
      values['elenco_spese'] = chronological
          .map((e) => '- ${dayFormat.format(e.expenseDate)} - ${e.vendor} - '
              '€ ${_formatAmountPlain(e.amount)} (${_paymentMethodLowerLabel(e.paymentMethod)})')
          .join('\n');
    } else {
      values['spesa_massima'] = total > 0 ? _formatAmountPlain(total) : '';
      values['incaricato'] = '';
    }
    return values;
  }

  Future<void> _generateDocument({required bool isRatifica}) async {
    if (_isGeneratingDocument) return;
    setState(() => _isGeneratingDocument = true);
    try {
      final templateKey =
          isRatifica ? 'verbale_cd_ratifica_evento_sociale' : 'verbale_cd_evento_sociale';
      final templates = await _governanceService.getTemplatesByKeys([templateKey]);
      if (templates.isEmpty) {
        throw Exception('Modello "$templateKey" non trovato.');
      }
      final initialValues = _buildInitialValues(isRatifica: isRatifica);
      if (!mounted) return;
      final result = await Navigator.push<AsdDocument>(
        context,
        MaterialPageRoute(
          builder: (context) => AsdDocumentGenerationScreen(
            template: templates.first,
            initialValues: initialValues,
          ),
        ),
      );
      if (result != null) {
        if (isRatifica) {
          await _service.setRatificaDocument(_event.id, result.id);
        } else {
          await _service.setVerbaleDocument(_event.id, result.id);
        }
        await _reloadEvent();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingDocument = false);
    }
  }

  Widget _buildEventInfoCard() {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _event.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Data: ${dayFormat.format(_event.eventDate)}'),
            if (_event.place != null && _event.place!.isNotEmpty)
              Text('Luogo: ${_event.place}'),
            if (_event.participants != null)
              Text('Partecipanti: ${_event.participants}'),
            if (_event.notes != null && _event.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_event.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Spese',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.isPrincipalAdmin)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Aggiungi spesa',
                    onPressed: _openAddExpense,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_isLoadingExpenses)
              const Center(child: CircularProgressIndicator())
            else if (_loadError != null)
              Text(_loadError!)
            else if (_expenses.isEmpty)
              const Text('Nessuna spesa registrata.')
            else ...[
              for (final expense in _expenses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: expense.documentId != null
                      ? IconButton(
                          icon: const Icon(Icons.receipt_long_outlined),
                          tooltip: 'Apri il giustificativo',
                          onPressed: () => _openDocument(expense.documentId!),
                        )
                      : null,
                  title: Text(
                    '${DateFormat('dd/MM/yyyy', 'it_IT').format(expense.expenseDate)} · '
                    '${expense.vendor} · ${_formatEuro(expense.amount)}',
                  ),
                  subtitle: Text(
                    [
                      socialEventPaymentMethodLabel(expense.paymentMethod),
                      if (expense.note != null && expense.note!.isNotEmpty) expense.note!,
                    ].join(' · '),
                  ),
                  trailing: widget.isPrincipalAdmin
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _confirmDeleteExpense(expense),
                        )
                      : null,
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Totale', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    _formatEuro(_totalExpenses),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verbali', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_event.verbaleDocumentId != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Verbale (prima dell\'evento)'),
                subtitle: const Text('Tocca per aprirlo'),
                onTap: () => _openDocument(_event.verbaleDocumentId!),
              ),
            if (_event.ratificaDocumentId != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Verbale di ratifica'),
                subtitle: const Text('Tocca per aprirlo'),
                onTap: () => _openDocument(_event.ratificaDocumentId!),
              ),
            if (!widget.isPrincipalAdmin &&
                _event.verbaleDocumentId == null &&
                _event.ratificaDocumentId == null)
              const Text('Nessun verbale ancora generato.'),
            if (widget.isPrincipalAdmin) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingDocument ? null : () => _generateDocument(isRatifica: false),
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Genera verbale (prima dell\'evento)'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingDocument ? null : () => _generateDocument(isRatifica: true),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Genera verbale di ratifica (evento già svolto)'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Il verbale va datato il giorno in cui il Consiglio si riunisce davvero. '
                'Per un evento già svolto usa la ratifica, non retrodatare.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_event.title),
        actions: widget.isPrincipalAdmin
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editEvent();
                    if (value == 'delete') _confirmDeleteEvent();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifica evento')),
                    PopupMenuItem(value: 'delete', child: Text('Elimina evento')),
                  ],
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _reloadEvent();
          await _loadExpenses();
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          children: [
            _buildEventInfoCard(),
            const SizedBox(height: 16),
            _buildExpensesCard(),
            const SizedBox(height: 16),
            _buildDocumentsCard(),
          ],
        ),
      ),
    );
  }
}
