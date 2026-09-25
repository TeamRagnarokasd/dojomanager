import 'package:flutter/material.dart';

import '../../services/shop_service.dart';

/// Admin: finestre di ordine condiviso (aperte e chiuse) con l'elenco unito
/// dei prodotti da ordinare in una volta, più i singoli ordini con costo,
/// margine, metodo di pagamento e le azioni per confermare il pagamento e
/// segnare l'ordine come ordinato al fornitore.
class ShopAdminOrdersScreen extends StatefulWidget {
  const ShopAdminOrdersScreen({super.key});

  @override
  State<ShopAdminOrdersScreen> createState() => _ShopAdminOrdersScreenState();
}

class _ShopAdminOrdersScreenState extends State<ShopAdminOrdersScreen> {
  final _service = ShopService.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _openWindows = [];
  List<Map<String, dynamic>> _closedWindows = [];
  List<Map<String, dynamic>> _standaloneOrders = [];
  final Map<String, List<Map<String, dynamic>>> _ordersByWindow = {};
  Map<String, Map<String, dynamic>> _costsByOrderId = {};
  Map<String, String> _userNamesById = {};
  Map<String, String> _sponsorNamesById = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    final openWindows = await _service.getOpenWindows();
    final closedWindows = await _service.getClosedWindows();
    final standaloneOrders = await _service.getOrdersWithoutWindow();

    _ordersByWindow.clear();
    for (final window in [...openWindows, ...closedWindows]) {
      final windowId = window['id'] as String;
      _ordersByWindow[windowId] = await _service.getOrdersForWindow(windowId);
    }

    final allOrders = [
      ...standaloneOrders,
      for (final orders in _ordersByWindow.values) ...orders,
    ];
    final orderIds = allOrders.map((order) => order['id'] as String).toList();
    final userIds = allOrders.map((order) => order['user_id'] as String).toSet().toList();
    final sponsorIds = {
      ...standaloneOrders.map((order) => order['sponsor_id'] as String),
      ...openWindows.map((window) => window['sponsor_id'] as String),
      ...closedWindows.map((window) => window['sponsor_id'] as String),
    }.toList();

    final costs = await _service.getCostsForOrders(orderIds);
    final userNames = await _service.getFullNamesForUsers(userIds);
    final sponsorNames = await _service.getSponsorNames(sponsorIds);

    if (!mounted) return;
    setState(() {
      _openWindows = openWindows;
      _closedWindows = closedWindows;
      _standaloneOrders = standaloneOrders;
      _costsByOrderId = costs;
      _userNamesById = userNames;
      _sponsorNamesById = sponsorNames;
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

  Future<void> _closeWindowNow(String windowId) async {
    try {
      await _service.closeWindowNow(windowId);
      await _loadAll();
      _showMessage('Finestra chiusa.');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _markPaid(String orderId) async {
    try {
      await _service.markPaid(orderId);
      await _loadAll();
      _showMessage('Pagamento confermato.');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _markOrdered(String orderId) async {
    try {
      await _service.markOrdered(orderId);
      await _loadAll();
      _showMessage('Ordine segnato come ordinato.');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _showScreenshot(String screenshotPath) async {
    final url = await _service.getScreenshotSignedUrl(screenshotPath);
    if (!mounted) return;
    if (url == null) {
      _showMessage('Impossibile aprire lo screenshot.', isError: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ordini Shop'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Finestre aperte'),
              Tab(text: 'Finestre chiuse'),
              Tab(text: 'Ordini singoli'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: TabBarView(
                  children: [
                    _buildWindowsList(_openWindows, isOpen: true),
                    _buildWindowsList(_closedWindows, isOpen: false),
                    _buildStandaloneOrdersList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildWindowsList(List<Map<String, dynamic>> windows, {required bool isOpen}) {
    if (windows.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(isOpen ? 'Nessuna finestra aperta.' : 'Nessuna finestra chiusa.'),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: windows.length,
      itemBuilder: (context, index) => _buildWindowCard(windows[index], isOpen: isOpen),
    );
  }

  Widget _buildWindowCard(Map<String, dynamic> window, {required bool isOpen}) {
    final windowId = window['id'] as String;
    final sponsorName = _sponsorNamesById[window['sponsor_id']] ?? 'Sponsor';
    final orders = _ordersByWindow[windowId] ?? [];
    final aggregatedItems = _aggregateItems(orders);
    final closesAt = window['closes_at']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(sponsorName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          closesAt != null
              ? '${orders.length} ordini · chiude/chiusa il ${_formatDateTime(closesAt)}'
              : '${orders.length} ordini',
        ),
        trailing: isOpen
            ? TextButton(
                onPressed: () => _closeWindowNow(windowId),
                child: const Text('Chiudi ora'),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prodotti da ordinare in una volta',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                if (aggregatedItems.isEmpty)
                  const Text('Nessun prodotto in listino in questa finestra.')
                else
                  for (final item in aggregatedItems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${item['model_code']} — ${item['descrizione']}'
                        '${item['taglia'] != null ? ' (${item['taglia']})' : ''} '
                        'x${item['quantita']}',
                      ),
                    ),
                const Divider(height: 24),
                Text(
                  'Ordini',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (final order in orders) _buildOrderDetailCard(order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandaloneOrdersList() {
    if (_standaloneOrders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [Text('Nessun ordine singolo.')],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _standaloneOrders.length,
      itemBuilder: (context, index) {
        final order = _standaloneOrders[index];
        final sponsorName = _sponsorNamesById[order['sponsor_id']] ?? 'Sponsor';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(sponsorName, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            _buildOrderDetailCard(order),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _aggregateItems(List<Map<String, dynamic>> orders) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final order in orders) {
      final items = ((order['items'] as List?) ?? []).cast<Map<String, dynamic>>();
      for (final item in items) {
        if (item['in_listino'] != true) continue;
        final modelCode = item['model_code']?.toString() ?? '-';
        final taglia = item['taglia']?.toString();
        final key = '$modelCode|${taglia ?? ''}';
        final quantita = (item['quantita'] as num?)?.toInt() ?? 1;
        if (byKey.containsKey(key)) {
          byKey[key]!['quantita'] = (byKey[key]!['quantita'] as int) + quantita;
        } else {
          byKey[key] = {
            'model_code': modelCode,
            'descrizione': item['descrizione'],
            'taglia': taglia,
            'quantita': quantita,
          };
        }
      }
    }
    final list = byKey.values.toList();
    list.sort((a, b) => (a['model_code'] as String).compareTo(b['model_code'] as String));
    return list;
  }

  Widget _buildOrderDetailCard(Map<String, dynamic> order) {
    final orderId = order['id'] as String;
    final userName = _userNamesById[order['user_id']] ?? 'Allievo';
    final status = order['status'] as String? ?? '';
    final costs = _costsByOrderId[orderId];
    final items = ((order['items'] as List?) ?? []).cast<Map<String, dynamic>>();
    final screenshotPath = order['screenshot_path']?.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(userName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(_statusLabel(status)),
            ],
          ),
          const SizedBox(height: 4),
          for (final item in items)
            Text(
              '${item['descrizione']}'
              '${item['taglia'] != null ? ' (${item['taglia']})' : ''} '
              'x${item['quantita']} — €${((item['prezzo_allievo'] as num?) ?? 0).toStringAsFixed(2)}',
            ),
          const SizedBox(height: 4),
          Text('Totale allievo: €${((order['member_total'] as num?) ?? 0).toStringAsFixed(2)}'),
          if (order['final_total'] != null)
            Text('Totale finale: €${((order['final_total'] as num?) ?? 0).toStringAsFixed(2)}'),
          if (order['payment_method'] != null)
            Text('Metodo di pagamento: ${order['payment_method']}'),
          if (costs != null)
            Text(
              'Costo: €${((costs['cost_total'] as num?) ?? 0).toStringAsFixed(2)} · '
              'Margine: €${((costs['margin'] as num?) ?? 0).toStringAsFixed(2)}',
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (screenshotPath != null)
                OutlinedButton(
                  onPressed: () => _showScreenshot(screenshotPath),
                  child: const Text('Vedi screenshot'),
                ),
              if (status == 'pagamento_dichiarato')
                ElevatedButton(
                  onPressed: () => _markPaid(orderId),
                  child: const Text('Conferma pagamento'),
                ),
              if (status == 'pagato')
                ElevatedButton(
                  onPressed: () => _markOrdered(orderId),
                  child: const Text('Segna come ordinato'),
                ),
            ],
          ),
        ],
      ),
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
