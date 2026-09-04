import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/app_export.dart';
import '../../models/receipt_model.dart';
import '../../services/italian_receipt_service.dart';
import '../../services/receipt_service.dart';
import './widgets/manual_amount_dialog.dart';
import './widgets/payment_confirmation_dialog.dart';
import './widgets/receipt_card_widget.dart';
import './widgets/receipt_filter_widget.dart';

class ReceiptManagement extends StatefulWidget {
  const ReceiptManagement({Key? key}) : super(key: key);

  @override
  State<ReceiptManagement> createState() => _ReceiptManagementState();
}

class _ReceiptManagementState extends State<ReceiptManagement> {
  final ReceiptService _receiptService = ReceiptService();
  final ItalianReceiptService _italianReceiptService = ItalianReceiptService();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _isLoading = false;
  String _selectedFilterKey = 'all';
  String _searchQuery = '';
  List<ReceiptModel> _receipts = [];
  List<ReceiptModel> _filteredReceipts = [];

  static const List<String> _filterKeys = [
    'all',
    'monthly',
    'annual',
    'sumup',
    'satispay',
    'this_month',
  ];

  String _filterLabel(String key) {
    switch (key) {
      case 'all':
        return 'receipt.filter_all_receipts'.tr();
      case 'monthly':
        return 'receipt.monthly_subscription_label'.tr();
      case 'annual':
        return 'receipt.annual_subscription_label'.tr();
      case 'sumup':
        return 'payment.sumup'.tr();
      case 'satispay':
        return 'payment.satispay'.tr();
      case 'this_month':
        return 'receipt.period_this_month'.tr();
      default:
        return key;
    }
  }

  List<String> get _filterOptions =>
      _filterKeys.map((key) => _filterLabel(key)).toList();

  @override
  void initState() {
    super.initState();
    _loadReceipts();
    _checkPaymentReminder();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user ID (you should implement proper user session management)
      final currentUserId = 'current-user-id'; // Replace with actual user ID
      _receipts = await _receiptService.getUserReceipts(currentUserId);
      _applyFilters();
    } catch (error) {
      _showErrorToast(
          'receipt.load_receipts_error'.tr(namedArgs: {'detail': '$error'}));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filteredReceipts = _receipts.where((receipt) {
      bool matchesFilter = true;
      bool matchesSearch = true;

      // Apply filter
      switch (_selectedFilterKey) {
        case 'monthly':
          matchesFilter = receipt.subscription?.type == 'monthly';
          break;
        case 'annual':
          matchesFilter = receipt.subscription?.type == 'annual';
          break;
        case 'sumup':
          matchesFilter = receipt.paymentMethod == 'sumup';
          break;
        case 'satispay':
          matchesFilter = receipt.paymentMethod == 'satispay';
          break;
        case 'this_month':
          final now = DateTime.now();
          matchesFilter = receipt.issueDate.year == now.year &&
              receipt.issueDate.month == now.month;
          break;
        default:
          matchesFilter = true;
      }

      // Apply search
      if (_searchQuery.isNotEmpty) {
        matchesSearch = receipt.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            receipt.receiptNumber.toString().contains(_searchQuery) ||
            receipt.totalAmount.toString().contains(_searchQuery);
      }

      return matchesFilter && matchesSearch;
    }).toList();

    setState(() {});
  }

  Future<void> _checkPaymentReminder() async {
    try {
      final now = DateTime.now();
      if (now.day == 7) {
        // Show reminder on 7th of each month
        _showPaymentReminderDialog();
      }
    } catch (error) {
      print('Error checking payment reminder: $error');
    }
  }

  void _showPaymentReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'schedule',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text(
              'Promemoria Pagamento',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Ricorda di pagare il tuo abbonamento mensile entro il giorno 10. Non risultano pagamenti per questo mese.',
          style: AppTheme.lightTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Ricorda Dopo',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPaymentOptions();
            },
            child: Text(
              'Paga Ora',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            children: [
              Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Seleziona Metodo di Pagamento',
                style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              _buildPaymentOption(
                icon: 'credit_card',
                title: 'SumUp',
                subtitle: 'Pagamento con carta di credito/debito',
                onTap: () => _handleSumUpPayment(),
              ),
              SizedBox(height: 2.h),
              _buildPaymentOption(
                icon: 'phone_android',
                title: 'Satispay',
                subtitle: 'Pagamento con app Satispay',
                onTap: () => _handleSatispayPayment(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomIconWidget(
                iconName: icon,
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'arrow_forward_ios',
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSumUpPayment() {
    Navigator.pop(context);

    // Simulate redirect to SumUp payment
    _showPaymentDialog(
      title: 'Pagamento SumUp',
      content:
          'Reindirizzamento a SumUp per il pagamento dell\'abbonamento mensile (€30,00)...',
      onConfirm: () => _showPaymentConfirmation('sumup', 30.00, 'monthly'),
    );
  }

  void _handleSatispayPayment() {
    Navigator.pop(context);

    // Simulate redirect to Satispay payment
    _showPaymentDialog(
      title: 'Pagamento Satispay',
      content: 'Reindirizzamento a Satispay per il pagamento...',
      onConfirm: () => _showManualAmountEntry('satispay'),
    );
  }

  void _showPaymentDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: 2.h),
            Text(
              content,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Simulate delay for external payment
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
      onConfirm();
    });
  }

  void _showPaymentConfirmation(
      String paymentMethod, double amount, String subscriptionType) {
    showDialog(
      context: context,
      builder: (context) => PaymentConfirmationDialog(
        paymentMethod: paymentMethod,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _showManualAmountEntry(String paymentMethod) {
    showDialog(
      context: context,
      builder: (context) => ManualAmountDialog(
        paymentMethod: paymentMethod,
        onConfirm: (amount, subscriptionType) =>
            _createReceipt(paymentMethod, amount, subscriptionType),
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _createReceipt(
      String paymentMethod, double amount, String subscriptionType) async {
    Navigator.pop(context);

    try {
      final currentUserId = 'current-user-id'; // Replace with actual user ID

      // Use the available createReceipt method instead of undefined methods
      final receipt = await _receiptService.createReceipt(
        description:
            'Abbonamento $subscriptionType - ${paymentMethod.toUpperCase()}',
        amount: amount,
        createdBy: currentUserId,
        paymentMethod: paymentMethod,
        notes: 'Abbonamento $subscriptionType generato automaticamente',
      );

      _showSuccessToast('Ricevuta generata con successo!');
      _loadReceipts(); // Refresh the list
      _showReceiptPreview(receipt);
    } catch (error) {
      _showErrorToast(
          'receipt.generate_receipt_error'.tr(namedArgs: {'detail': '$error'}));
    }
  }

  void _showReceiptPreview(ReceiptModel receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(6.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ricevuta Generata',
                            style: AppTheme.lightTheme.textTheme.headlineSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.lightTheme.colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: CustomIconWidget(
                            iconName: 'close',
                            color: AppTheme
                                .lightTheme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.lightTheme.colorScheme.outline
                                  .withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _generateReceiptContent(receipt),
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadReceiptPdf(receipt),
                        icon: CustomIconWidget(
                          iconName: 'download',
                          color: AppTheme.lightTheme.colorScheme.onPrimary,
                          size: 20,
                        ),
                        label: Text(
                          'payment.download_receipt_pdf'.tr(),
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReceiptPdf(ReceiptModel receipt) async {
    try {
      // Step 1: Fetch full receipt data from database (with organization_info)
      final receiptData =
          await _italianReceiptService.getReceiptById(receipt.id);

      if (receiptData == null) {
        throw Exception('Ricevuta non trovata nel database');
      }

      // Step 2: Generate PDF using the beautiful service (same as other screens)
      final pdf =
          await _italianReceiptService.generateBeautifulReceiptPDF(receiptData);
      final pdfBytes = await pdf.save();

      // Step 3: Download the PDF
      final filename = 'ricevuta_${receiptData['receipt_number']}.pdf';

      if (kIsWeb) {
        // Web: Enhanced download trigger with better browser support
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = filename;

        // Append to body, click, and remove (ensures click event fires correctly)
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();

        // Clean up blob URL after a short delay to ensure download completes
        Future.delayed(const Duration(milliseconds: 100), () {
          html.Url.revokeObjectUrl(url);
        });
      } else {
        // Mobile: use native share sheet so user can save/open/view the PDF
        await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      }

      _showSuccessToast('Ricevuta PDF scaricata con successo!');
      Navigator.pop(context);
    } catch (error) {
      _showErrorToast('receipt.download_receipt_error'
          .tr(namedArgs: {'detail': error.toString()}));
    }
  }

  // Helper method to generate receipt content for text preview (not for PDF)
  String _generateReceiptContent(ReceiptModel receipt) {
    return '''
RICEVUTA NON FISCALE

Numero: #${receipt.receiptNumber}
Data: ${DateFormat('dd/MM/yyyy').format(receipt.issueDate)}

Descrizione: ${receipt.description}
Importo: €${receipt.totalAmount.toStringAsFixed(2)}
Metodo di Pagamento: ${_getPaymentMethodText(receipt.paymentMethod)}

${receipt.validityStart != null && receipt.validityEnd != null ? 'Validità: dal ${DateFormat('dd/MM/yyyy').format(receipt.validityStart!)} al ${DateFormat('dd/MM/yyyy').format(receipt.validityEnd!)}\n' : ''}
Stato: ${receipt.status.toUpperCase()}

Generato il: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}
''';
  }

  void _onFilterChanged(String filterLabel) {
    final index = _filterOptions.indexOf(filterLabel);
    if (index < 0) return;
    setState(() {
      _selectedFilterKey = _filterKeys[index];
    });
    _applyFilters();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
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
          'receipt.management_title'.tr(),
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
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _loadReceipts,
        color: AppTheme.lightTheme.colorScheme.primary,
        child: Column(
          children: [
            ReceiptFilterWidget(
              filterOptions: _filterOptions,
              selectedFilter: _filterLabel(_selectedFilterKey),
              searchQuery: _searchQuery,
              onFilterChanged: _onFilterChanged,
              onSearchChanged: _onSearchChanged,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredReceipts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          itemCount: _filteredReceipts.length,
                          itemBuilder: (context, index) {
                            final receipt = _filteredReceipts[index];
                            return ReceiptCardWidget(
                              receipt: receipt,
                              onTap: () => _showReceiptDetails(receipt),
                              onDownload: () => _downloadReceiptPdf(receipt),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPaymentOptions,
        icon: CustomIconWidget(
          iconName: 'add',
          color: AppTheme.lightTheme.colorScheme.onPrimary,
          size: 20,
        ),
        label: Text(
          'receipt.new_payment'.tr(),
          style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: 'receipt_long',
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.5),
            size: 64,
          ),
          SizedBox(height: 2.h),
          Text(
            'receipt.no_receipts_found'.tr(),
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'receipt.empty_hint_after_payment'.tr(),
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showReceiptDetails(ReceiptModel receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 70.h,
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
                      'receipt.receipt_details_title'.tr(
                          namedArgs: {'number': '${receipt.receiptNumber}'}),
                      style:
                          AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: CustomIconWidget(
                      iconName: 'close',
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 24,
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
                      _buildDetailRow(
                          'receipt.number'.tr(), '#${receipt.receiptNumber}'),
                      _buildDetailRow('class_schedule.date'.tr(),
                          DateFormat('dd/MM/yyyy').format(receipt.issueDate)),
                      _buildDetailRow(
                          'common.description'.tr(), receipt.description),
                      _buildDetailRow('payment.amount'.tr(),
                          '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}'),
                      _buildDetailRow('common.payment_method'.tr(),
                          _getPaymentMethodText(receipt.paymentMethod)),
                      if (receipt.validityStart != null &&
                          receipt.validityEnd != null)
                        _buildDetailRow(
                          'receipt.validity_label'.tr(),
                          'receipt.validity_range'.tr(namedArgs: {
                            'start': DateFormat('dd/MM/yyyy')
                                .format(receipt.validityStart!),
                            'end': DateFormat('dd/MM/yyyy')
                                .format(receipt.validityEnd!),
                          }),
                        ),
                      _buildDetailRow(
                          'common.status'.tr(), receipt.status.toUpperCase()),
                      SizedBox(height: 4.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadReceiptPdf(receipt),
                          icon: CustomIconWidget(
                            iconName: 'download',
                            color: AppTheme.lightTheme.colorScheme.onPrimary,
                            size: 20,
                          ),
                          label: Text(
                            'receipt.download_pdf'.tr(),
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              color: AppTheme.lightTheme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30.w,
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

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'sumup':
        return 'SumUp';
      case 'satispay':
        return 'payment.satispay'.tr();
      case 'cash':
        return 'payment.cash'.tr();
      case 'bank_transfer':
        return 'payment.bank_transfer'.tr();
      default:
        return method;
    }
  }
}
