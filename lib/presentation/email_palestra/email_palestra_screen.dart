import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/mailbox_service.dart';

/// "Email Palestra": riepilogo della casella email condivisa (sincronizzata
/// via IMAP da una edge function) e le fatture lette automaticamente dai
/// PDF allegati, da confermare e segnare pagate.
class EmailPalestraScreen extends StatefulWidget {
  const EmailPalestraScreen({super.key});

  @override
  State<EmailPalestraScreen> createState() => _EmailPalestraScreenState();
}

class _EmailPalestraScreenState extends State<EmailPalestraScreen>
    with SingleTickerProviderStateMixin {
  final _service = MailboxService.instance;
  late final TabController _tabController;

  bool _isLoadingMessages = true;
  bool _isLoadingInvoices = true;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMessages();
    _loadInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoadingMessages = true);
    try {
      final messages = await _service.getMessages();
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoadingInvoices = true);
    try {
      final invoices = await _service.getInvoicesToPay();
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _isLoadingInvoices = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingInvoices = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Il tocco su un'email (riga o bottone "Apri la posta") apre la webmail
  // vera: non esiste più uno stato "letta" locale da aggiornare qui — lo
  // stato letto/non letto arriva solo dalla vera casella (flag IMAP
  // \Seen), sincronizzato dalla edge function.
  Future<void> _openWebmail() async {
    try {
      await launchUrl(
        Uri.parse('https://webmail.aruba.it'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Impossibile aprire la webmail.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Palestra'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Posta', icon: Icon(Icons.email_outlined)),
            Tab(text: 'Fatture da pagare', icon: Icon(Icons.receipt_long)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMessagesTab(),
          _buildInvoicesTab(),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMessages,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Nessuna email sincronizzata finora.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length,
        itemBuilder: (context, index) => _buildMessageCard(_messages[index]),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    // Stato letto/non letto reale della casella (flag IMAP \Seen,
    // sincronizzato dalla edge function) — non più una lettura "personale".
    final isUnread = message['is_unread'] != false;
    final from = (message['from_address'] ?? 'Mittente sconosciuto').toString();
    final subject = (message['subject'] ?? '(nessun oggetto)').toString();
    final snippet = (message['snippet'] ?? '').toString();
    final receivedAt = _formatDate(message['received_at']?.toString());
    final hasAttachment = message['has_attachment'] == true;
    final colorScheme = Theme.of(context).colorScheme;
    final unreadColor = colorScheme.primary;
    // Testo esplicito ad alto contrasto sopra lo sfondo colorato: il colore
    // di default (ereditato) è pensato per lo sfondo normale della card, non
    // per primaryContainer, e in questo tema può risultare illeggibile
    // (es. testo scuro su primaryContainer scuro in tema chiaro).
    final unreadTextColor = colorScheme.onPrimaryContainer;
    const cardRadius = 8.0;

    // Le email non lette hanno un trattamento grafico ben visibile (sfondo
    // tenue, bordo sinistro, etichetta "Da leggere", grassetto); quelle già
    // lette restano una riga normale, senza alcun indicatore.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isUnread ? colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          decoration: !isUnread
              ? null
              : BoxDecoration(
                  border: Border(
                    left: BorderSide(color: unreadColor, width: 4),
                  ),
                ),
          child: InkWell(
            onTap: _openWebmail,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          from,
                          style: TextStyle(
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.normal,
                            color: isUnread ? unreadTextColor : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasAttachment)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.attach_file,
                            size: 16,
                            color: isUnread ? unreadTextColor : null,
                          ),
                        ),
                      if (isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: unreadColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Da leggere',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        receivedAt,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isUnread ? unreadTextColor : null,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject,
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      color: isUnread ? unreadTextColor : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      snippet,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isUnread
                                ? unreadTextColor
                                : colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _openWebmail,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Apri la posta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    if (_isLoadingInvoices) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_invoices.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInvoices,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Nessuna fattura da pagare.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _invoices.length,
        itemBuilder: (context, index) {
          final invoice = _invoices[index];
          return _InvoiceCard(
            key: ValueKey(invoice['id']),
            invoice: invoice,
            onChanged: _loadInvoices,
            onError: (message) => _showMessage(message, isError: true),
          );
        },
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '-';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '-';
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

/// Una fattura nella sezione "Fatture da pagare": modulo modificabile finché
/// è 'da_confermare', sola lettura + "Segna pagata" quando è 'confermata'.
class _InvoiceCard extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onChanged;
  final void Function(String message) onError;

  const _InvoiceCard({
    super.key,
    required this.invoice,
    required this.onChanged,
    required this.onError,
  });

  @override
  State<_InvoiceCard> createState() => _InvoiceCardState();
}

class _InvoiceCardState extends State<_InvoiceCard> {
  final _service = MailboxService.instance;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final amount = widget.invoice['amount'];
    _amountController = TextEditingController(
      text: amount == null ? '' : (amount as num).toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: (widget.invoice['description'] ?? '').toString(),
    );
    final dueDateStr = widget.invoice['due_date']?.toString();
    _dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _confirm() async {
    if (_isSubmitting) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null) {
      widget.onError('Inserisci un importo valido.');
      return;
    }
    if (_dueDate == null) {
      widget.onError('Seleziona la data di scadenza.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _service.confirmInvoice(
        invoiceId: widget.invoice['id'] as String,
        amount: amount,
        dueDate: _dueDate!,
        description: _descriptionController.text.trim(),
      );
      widget.onChanged();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _ignore() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _service.ignoreInvoice(widget.invoice['id'] as String);
      widget.onChanged();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markPaid() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final path = await _service.pickAndUploadPaymentProof(
        widget.invoice['id'] as String,
      );
      if (path == null) {
        setState(() => _isSubmitting = false);
        return;
      }
      await _service.markInvoicePaid(
        invoiceId: widget.invoice['id'] as String,
        attachmentPath: path,
      );
      widget.onChanged();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.invoice['status'] ?? 'da_confermare').toString();
    final isConfirmed = status == 'confermata';
    final sender = (widget.invoice['sender'] ?? 'Mittente sconosciuto').toString();
    final subject = (widget.invoice['subject'] ?? '(nessun oggetto)').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              subject,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (isConfirmed) ...[
              Text('Importo: €${_amountController.text}'),
              Text(
                'Scadenza: ${_dueDate != null ? _formatDateOnly(_dueDate!) : '-'}',
              ),
              if (_descriptionController.text.isNotEmpty)
                Text(_descriptionController.text),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _markPaid,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('Segna pagata'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importo (€)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Scadenza',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(
                    _dueDate != null ? _formatDateOnly(_dueDate!) : 'Seleziona data',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _ignore,
                      child: const Text('Ignora'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _confirm,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Conferma'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateOnly(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
