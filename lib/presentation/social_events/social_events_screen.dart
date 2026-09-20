import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/auth_service.dart';
import '../../services/social_events_service.dart';
import 'widgets/social_event_detail_screen.dart';

String _formatEuro(num value) => '€ ${NumberFormat('#,##0.00', 'it_IT').format(value)}';

/// "Eventi sociali": list of `asd_social_events`, most recent first, each
/// with its expense total and verbale/ratifica status. Additive and
/// isolated: touches only asd_social_events/asd_social_event_expenses
/// (via SocialEventsService) and, for the verbale/ratifica generation and
/// expense receipts, the existing Archivio documenti screens/services —
/// nothing here changes payments, bookings, subscriptions, receipts, the
/// Registro di Cassa, the Scadenzario or Presenze e compensi.
class SocialEventsScreen extends StatefulWidget {
  const SocialEventsScreen({Key? key}) : super(key: key);

  @override
  State<SocialEventsScreen> createState() => _SocialEventsScreenState();
}

class _SocialEventsScreenState extends State<SocialEventsScreen> {
  final _service = SocialEventsService.instance;

  bool _isCheckingAccess = true;
  bool _canAccess = false;
  bool _isPrincipalAdmin = false;

  bool _isLoading = true;
  String? _loadError;
  List<SocialEvent> _events = [];
  Map<String, double> _expenseTotals = {};

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    bool canAccess;
    bool isPrincipal;
    try {
      canAccess = await AdminSectionVisibilityService.instance.canAccess('social_events');
    } catch (_) {
      canAccess = false;
    }
    try {
      isPrincipal = await AuthService.instance.isPrincipalAdmin();
    } catch (_) {
      isPrincipal = false;
    }
    if (!mounted) return;
    setState(() {
      _canAccess = canAccess;
      _isPrincipalAdmin = isPrincipal;
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
      final events = await _service.getEvents();
      final totals = await _service.getExpenseTotalsByEvent();
      if (!mounted) return;
      setState(() {
        _events = events;
        _expenseTotals = totals;
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

  Future<void> _openAddEventDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: 'Cena sociale');
    final placeController = TextEditingController();
    final participantsController = TextEditingController();
    final notesController = TextEditingController();
    var eventDate = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuovo evento sociale'),
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
      await _service.addEvent(
        title: titleController.text.trim(),
        eventDate: eventDate,
        place: placeController.text,
        participants: int.tryParse(participantsController.text.trim()),
        notes: notesController.text,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  Future<void> _openDetail(SocialEvent event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SocialEventDetailScreen(event: event, isPrincipalAdmin: _isPrincipalAdmin),
      ),
    );
    await _load();
  }

  String _statusLabel(SocialEvent event) {
    if (event.hasRatifica) return 'Ratifica fatta';
    if (event.hasVerbale) return 'Verbale fatto';
    return 'Verbale da fare';
  }

  Color _statusColor(SocialEvent event) {
    if (event.hasRatifica) return Colors.green;
    if (event.hasVerbale) return Colors.blue;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Eventi sociali')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Non hai accesso a questa sezione.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Eventi sociali')),
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
                  child: _events.isEmpty
                      ? ListView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewPadding.bottom + 88,
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(child: Text('Nessun evento sociale registrato.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            MediaQuery.of(context).viewPadding.bottom + 88,
                          ),
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            final total = _expenseTotals[event.id] ?? 0;
                            final statusColor = _statusColor(event);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                onTap: () => _openDetail(event),
                                title: Text(event.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        DateFormat('dd/MM/yyyy', 'it_IT').format(event.eventDate),
                                        if (event.place != null && event.place!.isNotEmpty)
                                          event.place!,
                                        if (event.participants != null)
                                          '${event.participants} partecipanti',
                                      ].join(' · '),
                                    ),
                                    Text('Spese: ${_formatEuro(total)}'),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _statusLabel(event),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: _isPrincipalAdmin
          ? FloatingActionButton(
              onPressed: _openAddEventDialog,
              tooltip: 'Nuovo evento sociale',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
