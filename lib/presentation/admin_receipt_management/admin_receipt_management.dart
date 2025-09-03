import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/receipt_model.dart';
import '../../services/receipt_service.dart';
import './widgets/admin_receipt_list_widget.dart';
import './widgets/admin_receipt_stats_widget.dart';
import './widgets/customer_filter_widget.dart';

class AdminReceiptManagement extends StatefulWidget {
  const AdminReceiptManagement({Key? key}) : super(key: key);

  @override
  State<AdminReceiptManagement> createState() => _AdminReceiptManagementState();
}

class _AdminReceiptManagementState extends State<AdminReceiptManagement>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ReceiptService _receiptService = ReceiptService();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _isLoading = false;
  List<ReceiptModel> _receipts = [];
  List<ReceiptModel> _filteredReceipts = [];
  String _customerFilter = '';
  String _selectedPeriod = 'Questo Mese';

  final List<String> _periodOptions = [
    'Questo Mese',
    'Ultimi 3 Mesi',
    'Ultimi 6 Mesi',
    'Quest\'Anno',
    'Tutto'
  ];

  Map<String, dynamic> _stats = {
    'total_receipts': 0,
    'total_amount': 0.0,
    'monthly_receipts': 0,
    'annual_receipts': 0,
    'sumup_payments': 0,
    'satispay_payments': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReceipts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _receipts = await _receiptService.getAllReceipts(
        userFilter: _customerFilter.isNotEmpty ? _customerFilter : null,
      );
      _applyFilters();
      _calculateStats();
    } catch (error) {
      _showErrorToast('Errore nel caricamento delle ricevute: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filteredReceipts = _receipts.where((receipt) {
      bool matchesPeriod = true;

      final now = DateTime.now();
      switch (_selectedPeriod) {
        case 'Questo Mese':
          matchesPeriod = receipt.issueDate.year == now.year &&
              receipt.issueDate.month == now.month;
          break;
        case 'Ultimi 3 Mesi':
          final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
          matchesPeriod = receipt.issueDate.isAfter(threeMonthsAgo);
          break;
        case 'Ultimi 6 Mesi':
          final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
          matchesPeriod = receipt.issueDate.isAfter(sixMonthsAgo);
          break;
        case 'Quest\'Anno':
          matchesPeriod = receipt.issueDate.year == now.year;
          break;
        default:
          matchesPeriod = true;
      }

      return matchesPeriod;
    }).toList();

    setState(() {});
  }

  void _calculateStats() {
    final now = DateTime.now();
    final currentMonth = _filteredReceipts
        .where((receipt) =>
            receipt.issueDate.year == now.year &&
            receipt.issueDate.month == now.month)
        .toList();

    _stats = {
      'total_receipts': _filteredReceipts.length,
      'total_amount': _filteredReceipts.fold(
          0.0, (sum, receipt) => sum + receipt.totalAmount),
      'monthly_receipts': _filteredReceipts
          .where((r) => r.subscription?.type == 'monthly')
          .length,
      'annual_receipts': _filteredReceipts
          .where((r) => r.subscription?.type == 'annual')
          .length,
      'sumup_payments':
          _filteredReceipts.where((r) => r.paymentMethod == 'sumup').length,
      'satispay_payments':
          _filteredReceipts.where((r) => r.paymentMethod == 'satispay').length,
      'this_month_count': currentMonth.length,
      'this_month_amount':
          currentMonth.fold(0.0, (sum, receipt) => sum + receipt.totalAmount),
    };
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _applyFilters();
    _calculateStats();
  }

  void _onCustomerFilterChanged(String filter) {
    setState(() {
      _customerFilter = filter;
    });
    _loadReceipts();
  }

  void _showReceiptDetails(ReceiptModel receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 85.h,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12.w,
                height: 0.5.h,
                margin: EdgeInsets.only(bottom: 4.h),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ricevuta #${receipt.receiptNumber}',
                      style:
                          AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: _getStatusColor(receipt.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(receipt.status)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      receipt.status.toUpperCase(),
                      style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                        color: _getStatusColor(receipt.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info
                      _buildSectionTitle('Informazioni Cliente'),
                      if (receipt.user != null) ...[
                        _buildDetailRow('Nome', receipt.user!.fullName),
                        _buildDetailRow('Email', receipt.user!.email),
                        if (receipt.user!.phone != null)
                          _buildDetailRow('Telefono', receipt.user!.phone!),
                      ],

                      SizedBox(height: 3.h),

                      // Receipt Details
                      _buildSectionTitle('Dettagli Ricevuta'),
                      _buildDetailRow('Numero', '#${receipt.receiptNumber}'),
                      _buildDetailRow('Data Emissione',
                          DateFormat('dd/MM/yyyy').format(receipt.issueDate)),
                      _buildDetailRow('Descrizione', receipt.description),
                      _buildDetailRow('Quantità', receipt.quantity.toString()),
                      _buildDetailRow('Prezzo Unitario',
                          '€${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}'),
                      _buildDetailRow('Importo Totale',
                          '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}'),
                      _buildDetailRow('IVA',
                          '${receipt.vatRate.toStringAsFixed(2)}% (N2.2)'),
                      _buildDetailRow('Metodo Pagamento',
                          _getPaymentMethodText(receipt.paymentMethod)),

                      if (receipt.validityStart != null &&
                          receipt.validityEnd != null) ...[
                        SizedBox(height: 1.h),
                        _buildDetailRow(
                          'Periodo di Validità',
                          'dal ${DateFormat('dd/MM/yyyy').format(receipt.validityStart!)} al ${DateFormat('dd/MM/yyyy').format(receipt.validityEnd!)}',
                        ),
                      ],

                      SizedBox(height: 3.h),

                      // Subscription Details
                      if (receipt.subscription != null) ...[
                        _buildSectionTitle('Dettagli Abbonamento'),
                        _buildDetailRow(
                            'Tipo',
                            receipt.subscription!.type == 'monthly'
                                ? 'Mensile'
                                : 'Annuale'),
                        _buildDetailRow('Importo Abbonamento',
                            '€${receipt.subscription!.amount.toStringAsFixed(2).replaceAll('.', ',')}'),
                        _buildDetailRow(
                            'Stato',
                            receipt.subscription!.isActive
                                ? 'Attivo'
                                : 'Inattivo'),
                      ],

                      SizedBox(height: 4.h),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Implement receipt download
                      },
                      icon: CustomIconWidget(
                        iconName: 'download',
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 20,
                      ),
                      label: Text(
                        'Scarica',
                        style:
                            AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: CustomIconWidget(
                        iconName: 'close',
                        color: AppTheme.lightTheme.colorScheme.onPrimary,
                        size: 20,
                      ),
                      label: Text(
                        'Chiudi',
                        style:
                            AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Text(
        title,
        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.lightTheme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 35.w,
            child: Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'issued':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'sumup':
        return 'SumUp';
      case 'satispay':
        return 'Satispay';
      case 'cash':
        return 'Contanti';
      case 'bank_transfer':
        return 'Bonifico Bancario';
      default:
        return method;
    }
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Gestione Ricevute Admin',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pushNamed(context, '/dashboard-home'),
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadReceipts,
            icon: CustomIconWidget(
              iconName: 'refresh',
              color: AppTheme.lightTheme.colorScheme.onSurface,
              size: 24,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Statistiche'),
            Tab(text: 'Elenco Ricevute'),
          ],
        ),
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _loadReceipts,
        color: AppTheme.lightTheme.colorScheme.primary,
        child: TabBarView(
          controller: _tabController,
          children: [
            // Statistics Tab
            Column(
              children: [
                CustomerFilterWidget(
                  customerFilter: _customerFilter,
                  selectedPeriod: _selectedPeriod,
                  periodOptions: _periodOptions,
                  onCustomerFilterChanged: _onCustomerFilterChanged,
                  onPeriodChanged: _onPeriodChanged,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : AdminReceiptStatsWidget(
                          stats: _stats,
                          selectedPeriod: _selectedPeriod,
                        ),
                ),
              ],
            ),

            // Receipt List Tab
            Column(
              children: [
                CustomerFilterWidget(
                  customerFilter: _customerFilter,
                  selectedPeriod: _selectedPeriod,
                  periodOptions: _periodOptions,
                  onCustomerFilterChanged: _onCustomerFilterChanged,
                  onPeriodChanged: _onPeriodChanged,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : AdminReceiptListWidget(
                          receipts: _filteredReceipts,
                          onReceiptTap: _showReceiptDetails,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}