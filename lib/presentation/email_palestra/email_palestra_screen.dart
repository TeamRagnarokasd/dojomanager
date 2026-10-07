import 'package:flutter/gestures.dart';
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

  Future<void> _openMessageDetail(Map<String, dynamic> message) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => _EmailDetailScreen(message: message),
      ),
    );
    if (deleted == true) _loadMessages();
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
            onTap: () => _openMessageDetail(message),
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
                      label: const Text('Apri in email'),
                      // Tono su tono altrimenti: il colore ereditato dal
                      // tema (pensato per uno sfondo normale) può risultare
                      // quasi invisibile sopra lo sfondo colorato della
                      // card non letta — foreground e bordo espliciti ad
                      // alto contrasto in entrambi i casi, verificato sia
                      // in tema chiaro che scuro.
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isUnread ? unreadTextColor : colorScheme.primary,
                        side: BorderSide(
                          color: isUnread ? unreadTextColor : colorScheme.primary,
                        ),
                      ),
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

/// Dettaglio di un'email: mittente, oggetto, data e corpo completo (letto al
/// volo via IMAP dalla edge function — non salvato localmente, solo lo
/// snippet lo è). "Elimina" sposta l'email nel Cestino sulla casella Aruba
/// e la nasconde dall'app, senza mai cancellare la riga dal database (ci
/// sono fatture collegate).
class _EmailDetailScreen extends StatefulWidget {
  const _EmailDetailScreen({required this.message});

  final Map<String, dynamic> message;

  @override
  State<_EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<_EmailDetailScreen> {
  // Riga che e' SOLO un URL tra parentesi (es. tracking link nei footer
  // delle email) — va rimossa del tutto, non solo accorciata.
  static final RegExp _soleParenUrlLine =
      RegExp(r'^\(\s*https?://\S+?\s*\)$', caseSensitive: false);

  // Cattura "etichetta (https://...)" (gruppi 1+2) oppure un URL nudo
  // (gruppo 3). L'etichetta e' tutto il testo della riga fino alla
  // parentesi aperta più vicina che racchiude un URL.
  static final RegExp _linkPattern = RegExp(
    r'([^\n(]*?)\((https?://[^\s)]+)\)|(https?://[^\s)]+)',
    caseSensitive: false,
  );

  static const _linkStyle = TextStyle(
    color: Color(0xFF1A73E8),
    decoration: TextDecoration.underline,
  );

  final _service = MailboxService.instance;
  bool _isLoadingBody = true;
  bool _isDeleting = false;
  List<InlineSpan> _bodySpans = const [];
  String? _bodyError;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _loadBody();
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBody() async {
    try {
      final body = await _service.getMessageBody(
        widget.message['id'] as String,
      );
      if (!mounted) return;
      setState(() {
        _bodySpans = _buildBodySpans(body);
        _isLoadingBody = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bodyError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingBody = false;
      });
    }
  }

  /// Trasforma il corpo testuale in una serie di span: testo normale e
  /// link cliccabili al posto degli URL grezzi. Le righe che sono solo un
  /// URL tra parentesi vengono scartate.
  List<InlineSpan> _buildBodySpans(String text) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_soleParenUrlLine.hasMatch(line.trim())) {
        continue;
      }

      var last = 0;
      for (final match in _linkPattern.allMatches(line)) {
        if (match.start > last) {
          spans.add(TextSpan(text: line.substring(last, match.start)));
        }
        final parenUrl = match.group(2);
        final bareUrl = match.group(3);
        if (parenUrl != null) {
          final label = (match.group(1) ?? '').trim();
          final displayText =
              label.isNotEmpty ? label : _domainEllipsis(parenUrl);
          spans.add(_linkSpan(displayText, parenUrl));
        } else if (bareUrl != null) {
          final split = _splitTrailingPunctuation(bareUrl);
          spans.add(_linkSpan(_domainEllipsis(split.url), split.url));
          if (split.trailing.isNotEmpty) {
            spans.add(TextSpan(text: split.trailing));
          }
        }
        last = match.end;
      }
      if (last < line.length) {
        spans.add(TextSpan(text: line.substring(last)));
      }
      if (i != lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  /// Punteggiatura finale di frase (es. "https://...sito.com.") non fa
  /// parte dell'URL — va mostrata come testo normale dopo il link.
  ({String url, String trailing}) _splitTrailingPunctuation(String url) {
    const punctuation = '.,;:!?)]}>"\'';
    var end = url.length;
    while (end > 0 && punctuation.contains(url[end - 1])) {
      end--;
    }
    return (url: url.substring(0, end), trailing: url.substring(end));
  }

  /// Solo il dominio, es. "hubspotlinks.com..." — l'URL completo resta il
  /// target del tocco, solo la scritta e' accorciata.
  String _domainEllipsis(String url) {
    var host = Uri.tryParse(url)?.host ?? '';
    if (host.startsWith('www.')) host = host.substring(4);
    if (host.isEmpty) {
      return url.length > 30 ? '${url.substring(0, 30)}...' : url;
    }
    return '$host...';
  }

  InlineSpan _linkSpan(String text, String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => _launchUrl(url);
    _recognizers.add(recognizer);
    return TextSpan(text: text, style: _linkStyle, recognizer: recognizer);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il link.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il link.')),
      );
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa email?'),
        content: const Text(
          'Verrà spostata nel Cestino della casella email. Eventuali fatture '
          'già lette da questa email restano comunque nell\'app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await _service.deleteMessage(widget.message['id'] as String);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  String _formatFullDate(String? isoString) {
    if (isoString == null) return '-';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '-';
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final from = (message['from_address'] ?? 'Mittente sconosciuto').toString();
    final subject = (message['subject'] ?? '(nessun oggetto)').toString();
    final receivedAt = _formatFullDate(message['received_at']?.toString());

    return Scaffold(
      appBar: AppBar(
        // Esplicito: su web (Safari iPhone) il leading automatico non
        // compare sempre, lasciando la schermata senza modo di tornare
        // indietro.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Indietro',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Email'),
        actions: [
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            tooltip: 'Elimina',
            onPressed: _isDeleting ? null : _confirmAndDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              from,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(receivedAt, style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: 32),
            if (_isLoadingBody)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_bodyError != null)
              Text(
                'Impossibile caricare il corpo dell\'email: $_bodyError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: _bodySpans.isNotEmpty
                      ? _bodySpans
                      : const [TextSpan(text: '(Messaggio vuoto)')],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
