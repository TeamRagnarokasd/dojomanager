import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sizer/sizer.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/app_export.dart';
import '../../widgets/custom_icon_widget.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/empty_payment_state.dart';
import './widgets/monthly_group_header.dart';
import './widgets/payment_filter_chips.dart';
import './widgets/payment_search_bar.dart';
import './widgets/payment_transaction_card.dart';
import './widgets/subscription_status_card.dart';
import './widgets/sumup_payment_options_widget.dart';
import './widgets/subscription_plans_widget.dart';

class PaymentHistory extends StatefulWidget {
  const PaymentHistory({Key? key}) : super(key: key);

  @override
  State<PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<PaymentHistory>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _isLoading = false;
  bool _isOfflineMode = false;
  String _selectedFilter = 'Tutti';
  String _searchQuery = '';
  final Map<String, bool> _expandedMonths = {};
  Map<String, dynamic>? _selectedPlan; // Add this to store selected plan

  // Mock data
  final Map<String, dynamic> _subscriptionData = {
    "planName": "Piano Premium Mensile",
    "renewalDate": "15/09/2024",
    "autoPayment": true,
    "status": "active",
  };

  final List<Map<String, dynamic>> _paymentTransactions = [
    {
      "id": 1,
      "description": "Abbonamento Premium - Settembre 2024",
      "amount": "€89,00",
      "date": "01/09/2024",
      "status": "completato",
      "paymentMethod": "Carta di Credito",
      "type": "Abbonamento",
      "month": "Settembre 2024",
      "receiptId": "RCP-2024-09-001",
    },
    {
      "id": 2,
      "description": "Classe Singola - Karate Avanzato",
      "amount": "€25,00",
      "date": "28/08/2024",
      "status": "completato",
      "paymentMethod": "PayPal",
      "type": "Classe Singola",
      "month": "Agosto 2024",
      "receiptId": "RCP-2024-08-015",
    },
    {
      "id": 4,
      "description": "Abbonamento Premium - Agosto 2024",
      "amount": "€89,00",
      "date": "01/08/2024",
      "status": "completato",
      "paymentMethod": "Carta di Credito",
      "type": "Abbonamento",
      "month": "Agosto 2024",
      "receiptId": "RCP-2024-08-001",
    },
    {
      "id": 5,
      "description": "Classe Singola - Judo Principianti",
      "amount": "€20,00",
      "date": "15/07/2024",
      "status": "fallito",
      "paymentMethod": "Carta di Credito",
      "type": "Classe Singola",
      "month": "Luglio 2024",
      "receiptId": "RCP-2024-07-008",
    },
    {
      "id": 6,
      "description": "Abbonamento Premium - Luglio 2024",
      "amount": "€89,00",
      "date": "01/07/2024",
      "status": "completato",
      "paymentMethod": "PayPal",
      "type": "Abbonamento",
      "month": "Luglio 2024",
      "receiptId": "RCP-2024-07-001",
    },
  ];

  final List<String> _filterOptions = [
    'Tutti',
    'Abbonamento',
    'Classe Singola',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _initializeExpandedMonths();
    _loadPaymentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeExpandedMonths() {
    final months = _getUniqueMonths();
    for (String month in months) {
      _expandedMonths[month] = true;
    }
  }

  List<String> _getUniqueMonths() {
    final months = <String>{};
    for (var transaction in _getFilteredTransactions()) {
      months.add(transaction['month'] as String);
    }
    return months.toList()..sort((a, b) => _compareMonths(b, a));
  }

  int _compareMonths(String a, String b) {
    final monthsMap = {
      'Gennaio': 1,
      'Febbraio': 2,
      'Marzo': 3,
      'Aprile': 4,
      'Maggio': 5,
      'Giugno': 6,
      'Luglio': 7,
      'Agosto': 8,
      'Settembre': 9,
      'Ottobre': 10,
      'Novembre': 11,
      'Dicembre': 12,
    };

    final aParts = a.split(' ');
    final bParts = b.split(' ');

    final aYear = int.parse(aParts[1]);
    final bYear = int.parse(bParts[1]);

    if (aYear != bYear) return aYear.compareTo(bYear);

    final aMonth = monthsMap[aParts[0]] ?? 0;
    final bMonth = monthsMap[bParts[0]] ?? 0;

    return aMonth.compareTo(bMonth);
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    var filtered = _paymentTransactions.where((transaction) {
      final matchesFilter = _selectedFilter == 'Tutti' ||
          (transaction['type'] as String) == _selectedFilter;

      final matchesSearch = _searchQuery.isEmpty ||
          (transaction['description'] as String).toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
          (transaction['amount'] as String).toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );

      return matchesFilter && matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      final aDate = _parseDate(a['date'] as String);
      final bDate = _parseDate(b['date'] as String);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
  }

  List<Map<String, dynamic>> _getTransactionsForMonth(String month) {
    return _getFilteredTransactions()
        .where((transaction) => (transaction['month'] as String) == month)
        .toList();
  }

  String _calculateMonthTotal(String month) {
    final transactions = _getTransactionsForMonth(month);
    double total = 0;

    for (var transaction in transactions) {
      if ((transaction['status'] as String) == 'completato') {
        final amountStr = (transaction['amount'] as String)
            .replaceAll('€', '')
            .replaceAll(',', '.');
        total += double.tryParse(amountStr) ?? 0;
      }
    }

    return '€${total.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _loadPaymentData() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      _isLoading = false;
      _isOfflineMode = false;
    });
  }

  Future<void> _refreshPaymentData() async {
    HapticFeedback.lightImpact();
    await _loadPaymentData();

    Fluttertoast.showToast(
      msg: "Cronologia pagamenti aggiornata",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onSearchClear() {
    setState(() {
      _searchQuery = '';
    });
  }

  void _toggleMonthExpansion(String month) {
    setState(() {
      _expandedMonths[month] = !(_expandedMonths[month] ?? false);
    });
  }

  void _onTransactionTap(Map<String, dynamic> transaction) {
    _showTransactionDetails(transaction);
  }

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTransactionDetailsSheet(transaction),
    );
  }

  Widget _buildTransactionDetailsSheet(Map<String, dynamic> transaction) {
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor, // Use scaffold background for consistency
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 12.w,
            height: 0.5.h,
            margin: EdgeInsets.symmetric(vertical: 2.h),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor, // Ensure consistent background
              padding: EdgeInsets.all(6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dettagli Transazione',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: CustomIconWidget(
                          iconName: 'close',
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  _buildDetailRow(
                    'Descrizione',
                    transaction['description'] as String,
                  ),
                  _buildDetailRow('Importo', transaction['amount'] as String),
                  _buildDetailRow('Data', transaction['date'] as String),
                  _buildDetailRow('Stato', transaction['status'] as String),
                  _buildDetailRow(
                    'Metodo di Pagamento',
                    transaction['paymentMethod'] as String,
                  ),
                  _buildDetailRow(
                    'ID Ricevuta',
                    transaction['receiptId'] as String,
                  ),
                  SizedBox(height: 4.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadReceipt(transaction),
                      icon: CustomIconWidget(
                        iconName: 'download',
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 20,
                      ),
                      label: Text(
                        'Scarica Ricevuta PDF',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Ensure consistent background
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 35.w,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReceipt(Map<String, dynamic> transaction) async {
    try {
      final receiptContent = _generateReceiptContent(transaction);
      final filename = 'ricevuta_${transaction['receiptId']}.txt';

      if (kIsWeb) {
        final bytes = utf8.encode(receiptContent);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(receiptContent);
      }

      Fluttertoast.showToast(
        msg: "Ricevuta scaricata con successo",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Errore durante il download della ricevuta",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  String _generateReceiptContent(Map<String, dynamic> transaction) {
    return '''
DOJO MANAGER - RICEVUTA PAGAMENTO
================================

ID Ricevuta: ${transaction['receiptId']}
Data: ${transaction['date']}
Stato: ${transaction['status']}

DETTAGLI TRANSAZIONE
-------------------
Descrizione: ${transaction['description']}
Importo: ${transaction['amount']}
Metodo di Pagamento: ${transaction['paymentMethod']}

INFORMAZIONI SCUOLA
------------------
DojoManager Martial Arts School
Via Roma 123, Milano
P.IVA: 12345678901
Tel: +39 02 1234567
Email: info@dojomanager.it

Grazie per aver scelto DojoManager!
''';
  }

  Future<void> _shareReceipt(Map<String, dynamic> transaction) async {
    try {
      final receiptContent = _generateReceiptContent(transaction);

      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: receiptContent));
        Fluttertoast.showToast(
          msg: "Ricevuta copiata negli appunti",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        await Clipboard.setData(ClipboardData(text: receiptContent));
        Fluttertoast.showToast(
          msg: "Ricevuta copiata negli appunti",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Errore durante la condivisione",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _contactSupport(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Contatta Supporto',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Vuoi contattare il supporto per la transazione ${transaction['receiptId']}?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: "Richiesta di supporto inviata",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
              );
            },
            child: Text(
              'Contatta',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAutoPaymentToggle(bool enabled) {
    setState(() {
      _subscriptionData['autoPayment'] = enabled;
    });

    Fluttertoast.showToast(
      msg: enabled
          ? "Pagamento automatico attivato"
          : "Pagamento automatico disattivato",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _showManualPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Pagamento Manuale',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Vuoi procedere con un pagamento manuale per saldare eventuali importi in sospeso?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/dashboard-home');
            },
            child: Text(
              'Procedi',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPlanSelected(Map<String, dynamic> plan) {
    setState(() {
      _selectedPlan = plan;
    });
  }

  void _onTabChanged(int tabIndex) {
    setState(() {
      _tabController.animateTo(tabIndex);
    });
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Card(
        elevation: 2,
        color: Theme.of(context).cardColor, // Use theme card color
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          color: Theme.of(
            context,
          ).cardColor, // Ensure card has consistent theme color
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 2.h,
                          width: 60.w,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Container(
                          height: 1.5.h,
                          width: 30.w,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 3.h,
                    width: 20.w,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Container(
                height: 1.5.h,
                width: 40.w,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTab() {
    return Container(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Ensure consistent dark background
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Show selected plan information if available
                  if (_selectedPlan != null) ...[
                    Container(
                      margin: EdgeInsets.all(4.w),
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Color(_selectedPlan!['color'] as int)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(_selectedPlan!['color'] as int)
                              .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'check_circle',
                                color: Color(_selectedPlan!['color'] as int),
                                size: 24,
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Text(
                                  'Piano Selezionato',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Color(
                                            _selectedPlan!['color'] as int),
                                      ),
                                ),
                              ),
                              Text(
                                '€${_selectedPlan!['price']}/${_selectedPlan!['frequency']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Color(_selectedPlan!['color'] as int),
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            _selectedPlan!['title'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SumUpPaymentOptionsWidget(),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryTab() {
    final filteredTransactions = _getFilteredTransactions();

    if (_isLoading) {
      return Container(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor, // Ensure consistent dark background
        child: Column(
          children: [
            SubscriptionStatusCard(
              subscriptionData: _subscriptionData,
              onAutoPaymentToggle: _onAutoPaymentToggle,
            ),
            PaymentFilterChips(
              filterOptions: _filterOptions,
              selectedFilter: _selectedFilter,
              onFilterChanged: _onFilterChanged,
            ),
            PaymentSearchBar(
              onSearchChanged: _onSearchChanged,
              onClear: _onSearchClear,
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: ListView.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) => _buildSkeletonCard(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (filteredTransactions.isEmpty) {
      return Container(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor, // Ensure consistent dark background
        child: Column(
          children: [
            SubscriptionStatusCard(
              subscriptionData: _subscriptionData,
              onAutoPaymentToggle: _onAutoPaymentToggle,
            ),
            PaymentFilterChips(
              filterOptions: _filterOptions,
              selectedFilter: _selectedFilter,
              onFilterChanged: _onFilterChanged,
            ),
            PaymentSearchBar(
              onSearchChanged: _onSearchChanged,
              onClear: _onSearchClear,
            ),
            Expanded(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: EmptyPaymentState(
                  onButtonPressed: () =>
                      Navigator.pushNamed(context, '/class-schedule'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final months = _getUniqueMonths();

    return Container(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Ensure consistent dark background
      child: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshPaymentData,
        color: Theme.of(context).colorScheme.secondary,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  children: [
                    SubscriptionStatusCard(
                      subscriptionData: _subscriptionData,
                      onAutoPaymentToggle: _onAutoPaymentToggle,
                    ),
                    PaymentFilterChips(
                      filterOptions: _filterOptions,
                      selectedFilter: _selectedFilter,
                      onFilterChanged: _onFilterChanged,
                    ),
                    PaymentSearchBar(
                      onSearchChanged: _onSearchChanged,
                      onClear: _onSearchClear,
                    ),
                    if (_isOfflineMode)
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 1.h,
                        ),
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF39C12).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFF39C12,
                            ).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'wifi_off',
                              color: const Color(0xFFF39C12),
                              size: 20,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                'Modalità offline - Dati memorizzati localmente',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: const Color(0xFFF39C12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final month = months[index];
                final monthTransactions = _getTransactionsForMonth(month);
                final isExpanded = _expandedMonths[month] ?? false;

                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      MonthlyGroupHeader(
                        monthYear: month,
                        totalAmount: _calculateMonthTotal(month),
                        transactionCount: monthTransactions.length,
                        isExpanded: isExpanded,
                        onToggle: () => _toggleMonthExpansion(month),
                      ),
                      if (isExpanded)
                        ...monthTransactions.map(
                          (transaction) => PaymentTransactionCard(
                            transaction: transaction,
                            onTap: () => _onTransactionTap(transaction),
                            onDownloadReceipt: () =>
                                _downloadReceipt(transaction),
                            onShare: () => _shareReceipt(transaction),
                            onContactSupport: () =>
                                _contactSupport(transaction),
                          ),
                        ),
                    ],
                  ),
                );
              }, childCount: months.length),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                height: 10.h,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlansTab() {
    return Container(
      color: Theme.of(
        context,
      ).scaffoldBackgroundColor, // Ensure consistent dark background
      child: SubscriptionPlansWidget(
        onTabChanged: _onTabChanged,
        onPlanSelected: _onPlanSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 2,
      child: Scaffold(
        backgroundColor: Theme.of(
          context,
        ).scaffoldBackgroundColor, // Explicit dark background
        appBar: AppBar(
          backgroundColor: Theme.of(
            context,
          ).scaffoldBackgroundColor, // Match scaffold background
          title: Text(
            'Cronologia Pagamenti',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: () => _refreshPaymentData(),
              icon: CustomIconWidget(
                iconName: 'refresh',
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            tabs: const [
              Tab(text: 'Paga'),
              Tab(text: 'Cronologia'),
              Tab(text: 'Abbonamenti'),
            ],
          ),
        ),
        body: Container(
          color: Theme.of(
            context,
          ).scaffoldBackgroundColor, // Ensure body has consistent dark background
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPaymentTab(),
              _buildPaymentHistoryTab(),
              _buildSubscriptionPlansTab(),
            ],
          ),
        ),
      ),
    );
  }
}
