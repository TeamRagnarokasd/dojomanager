import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/shop_service.dart';

/// "Carrello Sponsor": l'allievo carica lo screenshot del carrello fatto sul
/// sito di uno sponsor convenzionato, vede il recap con lo sconto già
/// applicato, conferma (da solo o unendosi a un gruppo per dividere la
/// spedizione) e poi paga. Mostra anche i propri ordini per questo sponsor.
class ShopCartScreen extends StatefulWidget {
  const ShopCartScreen({
    super.key,
    required this.sponsorId,
    required this.sponsorName,
  });

  final String sponsorId;
  final String sponsorName;

  @override
  State<ShopCartScreen> createState() => _ShopCartScreenState();
}

class _ShopCartScreenState extends State<ShopCartScreen> {
  final _service = ShopService.instance;

  bool _isLoading = true;
  bool _isUploading = false;
  bool _sharedSwitch = false;

  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _draftOrder;
  List<Map<String, dynamic>> _orders = [];
  final Map<String, Map<String, dynamic>> _windowInfoByOrderId = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    final settings = await _service.getShopSettings(widget.sponsorId);
    final allOrders = await _service.getMyOrders();
    final sponsorOrders = allOrders
        .where((order) => order['sponsor_id'] == widget.sponsorId)
        .toList();

    final draftCandidates =
        sponsorOrders.where((order) => order['status'] == 'da_confermare').toList();
    final draft = draftCandidates.isEmpty ? null : draftCandidates.first;
    final otherOrders =
        sponsorOrders.where((order) => order['status'] != 'da_confermare').toList();

    for (final order in otherOrders) {
      if (order['shared'] == true) {
        final info = await _service.getWindowInfo(order['id'] as String);
        if (info != null) {
          _windowInfoByOrderId[order['id'] as String] = info;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _draftOrder = draft;
      _orders = otherOrders;
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _pickAndReadCart() async {
    setState(() => _isUploading = true);
    try {
      final screenshotPath = await _service.pickAndUploadCartScreenshot();
      if (screenshotPath == null) {
        setState(() => _isUploading = false);
        return;
      }

      final order = await _service.readCart(
        sponsorId: widget.sponsorId,
        screenshotPath: screenshotPath,
      );
      if (!mounted) return;
      setState(() {
        _draftOrder = order;
        _isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _confirmDraft() async {
    final draft = _draftOrder;
    if (draft == null) return;
    try {
      await _service.confirmOrder(
        orderId: draft['id'] as String,
        shared: _sharedSwitch,
      );
      _sharedSwitch = false;
      await _loadAll();
      if (!mounted) return;
      _showMessage('Ordine confermato.');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _declarePayment(Map<String, dynamic> order, String method) async {
    try {
      await _service.declarePayment(orderId: order['id'] as String, method: method);
      await _loadAll();
      if (!mounted) return;
      _showMessage('Pagamento dichiarato.');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  /// Tenta di aprire l'app Satispay con il suo URL scheme; se il lancio
  /// fallisce o ritorna false (app non installata), apre in fallback la
  /// pagina di ricerca "Satispay" dello store giusto per la piattaforma.
  /// Non blocca comunque il passo successivo (dichiarare il pagamento).
  Future<void> _openSatispayApp() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('satispay://'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened) return;

    final storeUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/search?term=Satispay'
        : 'https://play.google.com/store/search?q=Satispay&c=apps';
    try {
      await launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Non blocchiamo il flusso di pagamento se anche lo store non si apre.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Carrello — ${widget.sponsorName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCartSection(),
                  const SizedBox(height: 24),
                  Text(
                    'I miei ordini shop',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_orders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nessun ordine per questo sponsor.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final order in _orders) _buildOrderCard(order),
                ],
              ),
            ),
    );
  }

  Widget _buildCartSection() {
    final draft = _draftOrder;
    if (draft == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuovo carrello',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fai il carrello sul sito, fai uno screenshot con tutti i '
              'prodotti e il totale, poi caricalo qui.',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndReadCart,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isUploading
                  ? 'Lettura in corso...'
                  : 'Carica screenshot del carrello'),
            ),
          ],
        ),
      );
    }

    final items = ((draft['items'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
    final memberTotal = (draft['member_total'] as num?)?.toDouble() ?? 0;
    final shippingTotal =
        (_settings?['shipping_total'] as num?)?.toDouble() ?? 20;
    final windowDays = (_settings?['window_days'] as num?)?.toInt() ?? 3;
    final closeHour = (_settings?['close_hour'] as num?)?.toInt() ?? 12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Il tuo carrello',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final item in items) _buildCartItemRow(item),
          const Divider(height: 24),
          _buildTotalRow('Totale prodotti', memberTotal),
          _buildTotalRow('Spedizione', shippingTotal),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _sharedSwitch,
            onChanged: (value) => setState(() => _sharedSwitch = value),
            title: const Text('Ordine condiviso'),
          ),
          if (_sharedSwitch)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                "L'ordine si chiuderà tra $windowDays giorni (alle "
                '$closeHour:00). Le spese di spedizione verranno divise tra '
                'gli utenti che si uniranno in questi giorni.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmDraft,
              child: const Text('Confermo, sono questi i prodotti'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(Map<String, dynamic> item) {
    final descrizione = (item['descrizione'] ?? '').toString();
    final taglia = item['taglia']?.toString();
    final quantita = (item['quantita'] as num?)?.toInt() ?? 1;
    final prezzoUfficiale = (item['prezzo_ufficiale'] as num?)?.toDouble() ?? 0;
    final prezzoAllievo = (item['prezzo_allievo'] as num?)?.toDouble() ?? 0;
    final inListino = item['in_listino'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taglia != null && taglia.isNotEmpty
                      ? '$descrizione · $taglia · x$quantita'
                      : '$descrizione · x$quantita',
                ),
                if (!inListino)
                  Text(
                    'non in convenzione, prezzo pieno',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (inListino && prezzoUfficiale != prezzoAllievo)
                Text(
                  '€${prezzoUfficiale.toStringAsFixed(2)}',
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
              Text(
                '€${prezzoAllievo.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '€${value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? '';
    final orderId = order['id'] as String;
    final windowInfo = _windowInfoByOrderId[orderId];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabel(status),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('Totale prodotti: €${((order['member_total'] as num?) ?? 0).toStringAsFixed(2)}'),
          if (status == 'in_attesa_gruppo') ...[
            const SizedBox(height: 8),
            if (windowInfo != null) ...[
              Text(
                'Quota spedizione attuale: €${((windowInfo['shipping_share'] as num?) ?? 0).toStringAsFixed(2)} '
                '(${windowInfo['other_participants'] ?? 0} altri utenti uniti)',
              ),
              if (windowInfo['closes_at'] != null)
                Text('Chiude il ${_formatDateTime(windowInfo['closes_at'].toString())}'),
            ] else
              const Text('In attesa di gruppo...'),
          ],
          if (status == 'da_pagare') ...[
            const SizedBox(height: 12),
            _buildPaymentChoices(order, windowInfo),
          ],
          if (status == 'pagamento_dichiarato')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pagamento dichiarato (${order['payment_method'] ?? '-'}): '
                '€${((order['final_total'] as num?) ?? 0).toStringAsFixed(2)}. '
                'In attesa di conferma.',
              ),
            ),
          if (status == 'pagato')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Pagamento confermato ✓'),
            ),
          if (status == 'ordinato')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Ordinato dal team ✓'),
            ),
          if (status == 'annullato')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Ordine annullato'),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentChoices(
    Map<String, dynamic> order,
    Map<String, dynamic>? windowInfo,
  ) {
    final memberTotal = (order['member_total'] as num?)?.toDouble() ?? 0;
    final shippingShare = windowInfo != null
        ? (windowInfo['shipping_share'] as num?)?.toDouble() ?? 0
        : (order['shipping_share'] as num?)?.toDouble() ?? 0;
    final satispayTotal = memberTotal + shippingShare;
    final cashSurcharge = (_settings?['cash_surcharge'] as num?)?.toDouble() ?? 5;
    final cashTotal = satispayTotal + cashSurcharge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Come vuoi pagare?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '€${satispayTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Completa il pagamento su Satispay come da accordi in palestra.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openSatispayApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Apri Satispay'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _declarePayment(order, 'satispay'),
                child: const Text('Ho pagato con Satispay'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contanti in palestra (+€${cashSurcharge.toStringAsFixed(2)} '
                'rispetto a Satispay) — totale €${cashTotal.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _declarePayment(order, 'contanti'),
                child: const Text('Pago in contanti in palestra'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_attesa_gruppo':
        return 'In attesa di gruppo';
      case 'da_pagare':
        return 'Da pagare';
      case 'pagamento_dichiarato':
        return 'Pagamento dichiarato';
      case 'pagato':
        return 'Pagato';
      case 'ordinato':
        return 'Ordinato';
      case 'annullato':
        return 'Annullato';
      default:
        return status;
    }
  }

  String _formatDateTime(String isoString) {
    final date = DateTime.tryParse(isoString);
    if (date == null) return isoString;
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }
}
