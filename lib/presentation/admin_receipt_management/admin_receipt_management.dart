import 'dart:io' if (dart.library.io) 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sizer/sizer.dart';
import 'package:universal_html/html.dart' as html;

import '../../core/app_export.dart';
import '../../models/receipt_model.dart';
import '../../services/italian_receipt_service.dart';
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
  final ItalianReceiptService _italianReceiptService = ItalianReceiptService();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _isLoading = false;
  bool _isDownloadingPDF = false;
  List<ReceiptModel> _receipts = [];
  List<ReceiptModel> _filteredReceipts = [];
  String _customerFilter = '';
  String _selectedPeriodKey = 'this_month';

  static const List<String> _periodKeys = [
    'this_month',
    'last_3_months',
    'last_6_months',
    'this_year',
    'all',
  ];

  String _periodLabel(String key) {
    switch (key) {
      case 'this_month':
        return 'receipt.period_this_month'.tr();
      case 'last_3_months':
        return 'receipt.period_last_3_months'.tr();
      case 'last_6_months':
        return 'receipt.period_last_6_months'.tr();
      case 'this_year':
        return 'receipt.period_this_year'.tr();
      case 'all':
        return 'receipt.period_all'.tr();
      default:
        return key;
    }
  }

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
      _receipts = await _receiptService.getAllReceipts();
      _applyFilters();
      _calculateStats();
    } catch (error) {
      _showErrorToast(
        'receipt.load_receipts_error'.tr(namedArgs: {'detail': '$error'}),
      );
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
      switch (_selectedPeriodKey) {
        case 'this_month':
          matchesPeriod = receipt.issueDate.year == now.year &&
              receipt.issueDate.month == now.month;
          break;
        case 'last_3_months':
          final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
          matchesPeriod = receipt.issueDate.isAfter(threeMonthsAgo);
          break;
        case 'last_6_months':
          final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
          matchesPeriod = receipt.issueDate.isAfter(sixMonthsAgo);
          break;
        case 'this_year':
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
        .where(
          (receipt) =>
              receipt.issueDate.year == now.year &&
              receipt.issueDate.month == now.month,
        )
        .toList();

    _stats = {
      'total_receipts': _filteredReceipts.length,
      'total_amount': _filteredReceipts.fold(
        0.0,
        (sum, receipt) => sum + receipt.totalAmount,
      ),
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
      'this_month_amount': currentMonth.fold(
        0.0,
        (sum, receipt) => sum + receipt.totalAmount,
      ),
    };
  }

  void _onPeriodChanged(String periodKey) {
    setState(() {
      _selectedPeriodKey = periodKey;
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
                      'receipt.receipt_number_title'.tr(
                        namedArgs: {'number': '${receipt.receiptNumber}'},
                      ),
                      style: AppTheme.lightTheme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        receipt.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(
                          receipt.status,
                        ).withValues(alpha: 0.3),
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
                      _buildSectionTitle('receipt.customer_info'.tr()),
                      if (receipt.user != null) ...[
                        _buildDetailRow(
                          'profile.first_name'.tr(),
                          receipt.user!.fullName,
                        ),
                        _buildDetailRow(
                          'common.email'.tr(),
                          receipt.user!.email,
                        ),
                        if (receipt.user!.phone != null)
                          _buildDetailRow(
                            'profile.phone'.tr(),
                            receipt.user!.phone!,
                          ),
                      ],

                      SizedBox(height: 3.h),

                      // Receipt Details
                      _buildSectionTitle('receipt.receipt_details'.tr()),
                      _buildDetailRow(
                        'receipt.number'.tr(),
                        '#${receipt.receiptNumber}',
                      ),
                      _buildDetailRow(
                        'receipt.issue_date'.tr(),
                        DateFormat('dd/MM/yyyy').format(receipt.issueDate),
                      ),
                      _buildDetailRow(
                        'common.description'.tr(),
                        receipt.description,
                      ),
                      _buildDetailRow(
                        'receipt.quantity'.tr(),
                        receipt.quantity.toString(),
                      ),
                      _buildDetailRow(
                        'receipt.unit_price'.tr(),
                        '€${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                      ),
                      _buildDetailRow(
                        'receipt.total_amount_label'.tr(),
                        '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                      ),
                      _buildDetailRow(
                        'receipt.vat_label'.tr(),
                        '${receipt.vatRate.toStringAsFixed(2)}% (N2.2)',
                      ),
                      _buildDetailRow(
                        'common.payment_method'.tr(),
                        _getPaymentMethodText(receipt.paymentMethod),
                      ),

                      if (receipt.validityStart != null &&
                          receipt.validityEnd != null) ...[
                        SizedBox(height: 1.h),
                        _buildDetailRow(
                          'receipt.validity_period'.tr(),
                          'receipt.validity_range'.tr(
                            namedArgs: {
                              'start': DateFormat(
                                'dd/MM/yyyy',
                              ).format(receipt.validityStart!),
                              'end': DateFormat(
                                'dd/MM/yyyy',
                              ).format(receipt.validityEnd!),
                            },
                          ),
                        ),
                      ],

                      SizedBox(height: 3.h),

                      // Subscription Details
                      if (receipt.subscription != null) ...[
                        _buildSectionTitle('profile.subscription_details'.tr()),
                        _buildDetailRow(
                          'receipt.type_label'.tr(),
                          receipt.subscription!.type == 'monthly'
                              ? 'payment.monthly_plan'.tr()
                              : 'payment.annual_plan'.tr(),
                        ),
                        _buildDetailRow(
                          'receipt.subscription_amount'.tr(),
                          '€${receipt.subscription!.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                        ),
                        _buildDetailRow(
                          'common.status'.tr(),
                          receipt.subscription!.isActive
                              ? 'common.active_status'.tr()
                              : 'common.inactive'.tr(),
                        ),
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
                      onPressed: _isDownloadingPDF
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _downloadReceiptPdf(receipt);
                            },
                      icon: _isDownloadingPDF
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.lightTheme.colorScheme.primary,
                              ),
                            )
                          : CustomIconWidget(
                              iconName: 'download',
                              color: AppTheme.lightTheme.colorScheme.primary,
                              size: 20,
                            ),
                      label: Text(
                        _isDownloadingPDF
                            ? 'receipt.downloading_pdf'.tr()
                            : 'receipt.download_pdf'.tr(),
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
                        'class_schedule.close_modal'.tr(),
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
        return 'payment.cash'.tr();
      case 'bank_transfer':
        return 'payment.bank_transfer_full'.tr();
      default:
        return method;
    }
  }

  Future<void> _downloadReceiptPdf(ReceiptModel receipt) async {
    setState(() {
      _isDownloadingPDF = true;
    });

    try {
      // Step 1: Fetch full receipt data from database (with organization_info)
      final receiptData = await _italianReceiptService.getReceiptById(
        receipt.id,
      );

      if (receiptData == null) {
        throw Exception('payment.receipt_not_found_db'.tr());
      }

      // Step 2: Generate PDF using the SAME beautiful service as User App
      final pdf = await _italianReceiptService.generateBeautifulReceiptPDF(
        receiptData,
      );
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
        // Mobile: Save to device documents directory
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(pdfBytes);
      }

      Fluttertoast.showToast(
        msg: 'payment.pdf_downloaded'.tr(),
        backgroundColor: Colors.green,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'receipt.download_receipt_error'.tr(
          namedArgs: {'detail': e.toString()},
        ),
        backgroundColor: Colors.red,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    } finally {
      setState(() {
        _isDownloadingPDF = false;
      });
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
          'receipt.admin_title'.tr(),
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
          tabs: [
            Tab(text: 'reminders.tab_statistics'.tr()),
            Tab(text: 'receipt.receipt_list_tab'.tr()),
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
                  selectedPeriodKey: _selectedPeriodKey,
                  periodKeys: _periodKeys,
                  onCustomerFilterChanged: _onCustomerFilterChanged,
                  onPeriodChanged: _onPeriodChanged,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : AdminReceiptStatsWidget(
                          stats: _stats,
                          selectedPeriod: _periodLabel(_selectedPeriodKey),
                        ),
                ),
              ],
            ),

            // Receipt List Tab
            Column(
              children: [
                CustomerFilterWidget(
                  customerFilter: _customerFilter,
                  selectedPeriodKey: _selectedPeriodKey,
                  periodKeys: _periodKeys,
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
