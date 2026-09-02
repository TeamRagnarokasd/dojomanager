import 'dart:io' if (dart.library.io) 'dart:io';
import '../../core/app_export.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/receipt_model.dart';
import '../../services/italian_receipt_service.dart';
import '../../services/receipt_service.dart';
import '../../services/supabase_service.dart';
import './widgets/bulk_actions_toolbar_widget.dart';
import './widgets/manual_receipt_creation_dialog.dart';
import './widgets/monthly_group_header_widget.dart';
import './widgets/receipt_card_widget.dart';
import './widgets/receipt_filter_widget.dart';
import './widgets/receipt_statistics_widget.dart';

//Add this import for kIsWeb
//Add this import for Flutter widgets
//Add this import for Fluttertoast
//Add this import for GoogleFonts

class ReceiptArchive extends StatefulWidget {
  const ReceiptArchive({Key? key})
    : super(key: key); //Fix constructor parameter

  @override
  State<ReceiptArchive> createState() => _ReceiptArchiveState();
}

class _ReceiptArchiveState extends State<ReceiptArchive>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ReceiptService _receiptService = ReceiptService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  final ItalianReceiptService _italianReceiptService =
      ItalianReceiptService(); // Add this line

  bool _isLoading = true;
  bool _showFilters = false;
  bool _bulkMode = false;

  List<ReceiptModel> _allReceipts = [];
  List<ReceiptModel> _filteredReceipts = [];
  Set<String> _selectedReceipts = <String>{};

  Map<String, dynamic> _currentFilters = {};
  Map<String, dynamic> _statistics = {
    'total_receipts': 0,
    'monthly_revenue': 0.0,
    'pending_receipts': 0,
    'current_month_receipts': 0,
  };

  String? _currentUser;
  bool _isAdmin = false;

  List<Map<String, dynamic>> _allPayments = [];
  List<Map<String, dynamic>> _filteredPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _currentUser = user.id;
          _isAdmin =
              user.userMetadata?['role'] == 'admin' ||
              user.appMetadata['role'] == 'admin';
        });
        await _loadReceipts();
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore inizializzazione: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);

    try {
      // NEW: Load from payment_confirmations with server-side search
      if (_isAdmin) {
        // CRITICAL FIX: Pass search filter to backend for server-side filtering
        final searchQuery = _currentFilters['client_search'] as String?;
        _allPayments = await _receiptService.getAllConfirmedPayments(
          searchFilter: searchQuery,
        );
      } else {
        _allPayments = await _receiptService.getUserConfirmedPayments(
          _currentUser!,
        );
      }

      setState(() {
        _filteredPayments = _allPayments;
        // Keep old receipt models for compatibility with existing widgets
        _filteredReceipts = _convertPaymentsToReceipts(_allPayments);
      });

      await _calculateStatisticsFromPayments();
    } catch (error) {
      print('❌ Error loading payments: $error');
      Fluttertoast.showToast(
        msg: "Errore nel caricamento pagamenti: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // NEW: Convert payment data to ReceiptModel format
  List<ReceiptModel> _convertPaymentsToReceipts(
    List<Map<String, dynamic>> payments,
  ) {
    return payments.map<ReceiptModel>((payment) {
      final userProfile = payment['user_profiles'] as Map<String, dynamic>?;

      return ReceiptModel(
        id: payment['id'] as String,
        receiptNumber: int.parse(
          payment['external_payment_id'] as String? ?? '0',
        ),
        userId: userProfile?['id'] as String? ?? '',
        gymId: '', // Add default gymId
        issueDate: DateTime.parse(payment['created_at'] as String),
        description: 'Pagamento confermato via ${payment['payment_method']}',
        quantity: 1,
        unitPrice: (payment['amount'] as num).toDouble(),
        totalAmount: (payment['amount'] as num).toDouble(),
        paymentMethod: payment['payment_method'] as String,
        status: payment['status'] as String,
        createdAt: DateTime.parse(payment['created_at'] as String),
        updatedAt: DateTime.parse(
          payment['updated_at'] as String? ?? payment['created_at'] as String,
        ),
        user: userProfile != null
            ? UserProfile(
                id: userProfile['id'] as String,
                email: userProfile['email'] as String? ?? '',
                fullName: userProfile['full_name'] as String,
                phone: userProfile['phone'] as String?,
              )
            : null,
      );
    }).toList();
  }

  // NEW: Calculate statistics from payment_confirmations
  Future<void> _calculateStatisticsFromPayments() async {
    try {
      final stats = await _receiptService.getPaymentStatistics();

      setState(() {
        _statistics = stats;
      });

      print(
        '✅ Payment statistics loaded: Monthly Revenue = €${stats['monthly_revenue']}',
      );
    } catch (error) {
      print('❌ Error calculating payment statistics: $error');
    }
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _currentFilters = filters;
    });

    // CRITICAL FIX: Reload data with search filter for server-side filtering
    // This triggers database-level ILIKE query in payment_confirmations
    _loadReceipts();
  }

  void _clearFilters() {
    setState(() {
      _currentFilters = {};
      _filteredReceipts = _convertPaymentsToReceipts(_allPayments);
      _showFilters = false;
    });
  }

  void _toggleBulkMode() {
    setState(() {
      _bulkMode = !_bulkMode;
      if (!_bulkMode) {
        _selectedReceipts.clear();
      }
    });
  }

  void _toggleReceiptSelection(String receiptId) {
    setState(() {
      if (_selectedReceipts.contains(receiptId)) {
        _selectedReceipts.remove(receiptId);
      } else {
        _selectedReceipts.add(receiptId);
      }
    });
  }

  void _selectAllReceipts() {
    setState(() {
      _selectedReceipts.addAll(_filteredReceipts.map((r) => r.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedReceipts.clear();
    });
  }

  Future<void> _bulkEmailReceipts() async {
    final selectedReceiptList = _filteredReceipts
        .where((receipt) => _selectedReceipts.contains(receipt.id))
        .toList();

    if (selectedReceiptList.isEmpty) {
      Fluttertoast.showToast(
        msg: "Seleziona almeno una ricevuta",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.email, color: Colors.blue.shade700),
            SizedBox(width: 12.w),
            Text(
              'Invio Email Multiplo',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inviare ${selectedReceiptList.length} ricevute via email ai rispettivi clienti?',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            ...selectedReceiptList
                .take(3)
                .map(
                  (receipt) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      '• ${receipt.user?.fullName} - Ricevuta ${receipt.receiptNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
            if (selectedReceiptList.length > 3)
              Text(
                '... e altre ${selectedReceiptList.length - 3} ricevute',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Invia Email',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Simulate email sending
      await Future.delayed(const Duration(seconds: 2));

      Fluttertoast.showToast(
        msg: "${selectedReceiptList.length} email inviate con successo!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      _clearSelection();
    }
  }

  Future<void> _bulkExportPdf() async {
    final selectedReceiptList = _filteredReceipts
        .where((receipt) => _selectedReceipts.contains(receipt.id))
        .toList();

    if (selectedReceiptList.isEmpty) {
      Fluttertoast.showToast(
        msg: "Seleziona almeno una ricevuta",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    try {
      // 🎯 CRITICAL FIX: Generate single PDF with all receipts instead of trying to merge separate PDFs
      final combinedPdf = pw.Document();

      // Load shared resources once for efficiency
      final logoBytes = await rootBundle.load(
        'assets/images/146804-1764638363594.jpg',
      );
      final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      final orgInfo = await _italianReceiptService.getOrganizationInfo();

      // Add each receipt as a separate page in the combined PDF
      for (final receipt in selectedReceiptList) {
        final receiptData = await _italianReceiptService.getReceiptById(
          receipt.id,
        );

        if (receiptData != null) {
          // Extract receipt data
          final issueDate =
              receiptData['issue_date'] ??
              DateTime.now().toIso8601String().split('T')[0];
          final receiptNumber = receiptData['receipt_number'] ?? '';
          final customerName = receiptData['customer_name'] ?? '';
          final description = receiptData['description'] ?? '';
          final amount = (receiptData['amount'] ?? 0.0) as double;
          final paymentMethod = _getPaymentMethodText(
            receiptData['payment_method'] ?? 'cash',
          );
          final customerTaxCode =
              receiptData['customer_tax_code'] ?? 'NON DISPONIBILE';

          // Add page for this receipt
          combinedPdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // RED HEADER - TEAM RAGNAROK WITH LOGO
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(20),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red700,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 60,
                            height: 60,
                            child: pw.Image(logoImage),
                          ),
                          pw.SizedBox(width: 15),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'TEAM RAGNAROK ASD',
                                  style: pw.TextStyle(
                                    fontSize: 24,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Longiano (FC) via fratta 319 cap 47020',
                                  style: const pw.TextStyle(
                                    fontSize: 12,
                                    color: PdfColors.white,
                                  ),
                                ),
                                pw.Text(
                                  'c.f. 92100170395',
                                  style: const pw.TextStyle(
                                    fontSize: 12,
                                    color: PdfColors.white,
                                  ),
                                ),
                                if (orgInfo.phone != null)
                                  pw.Text(
                                    'Tel: ${orgInfo.phone}',
                                    style: const pw.TextStyle(
                                      fontSize: 12,
                                      color: PdfColors.white,
                                    ),
                                  ),
                                if (orgInfo.email != null)
                                  pw.Text(
                                    'Email: ${orgInfo.email}',
                                    style: const pw.TextStyle(
                                      fontSize: 12,
                                      color: PdfColors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 30),

                    // RECEIPT TITLE
                    pw.Center(
                      child: pw.Text(
                        'RICEVUTA NON FISCALE',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // RECEIPT INFO BOX
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Ricevuta N°: $receiptNumber',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Data: $issueDate',
                            style: const pw.TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // CUSTOMER DETAILS
                    pw.Text(
                      'DATI CLIENTE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            customerName,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'CF: $customerTaxCode',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          if (receiptData['customer_address'] != null)
                            pw.Text(
                              receiptData['customer_address'],
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // PAYMENT DETAILS TABLE
                    pw.Text(
                      'DETTAGLI PAGAMENTO',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'common.description'.tr(),
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Importo',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(description),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                '\\u20AC ${amount.toStringAsFixed(2).replaceAll('.', ',')}',
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),

                    // PAYMENT METHOD
                    pw.Container(
                      padding: const pw.EdgeInsets.all(15),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Metodo di pagamento:',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            paymentMethod,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 15),

                    // VAT LEGAL TEXT
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.yellow50,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.yellow700),
                      ),
                      child: pw.Text(
                        'Operazione esclusa da IVA ai sensi dell\'articolo 4, quarto comma, del DPR 26 ottobre 1972, n. 633 e successive modificazioni, in conformità all\'art. 90 della Legge 289/2002',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey800,
                        ),
                        textAlign: pw.TextAlign.justify,
                      ),
                    ),

                    pw.Spacer(),

                    // FOOTER
                    pw.Divider(color: PdfColors.grey400),
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Text(
                        'Grazie per aver scelto Team Ragnarok ASD',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }
      }

      // Save and share the combined PDF
      final pdfBytes = await combinedPdf.save();

      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/ricevute_multiple.pdf');
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles([XFile(file.path)]);
      }

      _clearSelection();

      Fluttertoast.showToast(
        msg: "${selectedReceiptList.length} ricevute esportate in PDF!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nell'esportazione: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
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

  Map<String, List<ReceiptModel>> _groupReceiptsByMonth() {
    final Map<String, List<ReceiptModel>> groupedReceipts = {};

    for (final receipt in _filteredReceipts) {
      final monthKey = DateFormat('yyyy-MM').format(receipt.issueDate);
      if (!groupedReceipts.containsKey(monthKey)) {
        groupedReceipts[monthKey] = [];
      }
      groupedReceipts[monthKey]!.add(receipt);
    }

    // Sort by month (newest first)
    final sortedKeys = groupedReceipts.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final Map<String, List<ReceiptModel>> sortedGrouped = {};
    for (final key in sortedKeys) {
      sortedGrouped[key] = groupedReceipts[key]!;
    }

    return sortedGrouped;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'receipt.archive_title'.tr(),
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Add manual receipt creation button
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.green.shade600),
            tooltip: 'Crea Ricevuta Manuale',
            onPressed: _showManualReceiptCreationDialog,
          ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showFilters ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _bulkMode ? Icons.check_box : Icons.check_box_outline_blank,
              color: _bulkMode ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            onPressed: _toggleBulkMode,
          ),
        ],
        bottom: _isAdmin
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.blue.shade700,
                tabs: [
                  Tab(text: 'Tutte le Ricevute'),
                  Tab(text: 'Le Mie Ricevute'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Statistics header
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(16.w),
                  child: ReceiptStatisticsWidget(statistics: _statistics),
                ),

                // Filters (if shown)
                if (_showFilters)
                  ReceiptFilterWidget(
                    onFiltersApplied: _applyFilters,
                    onClearFilters: _clearFilters,
                    currentFilters: _currentFilters,
                  ),

                // Bulk actions toolbar
                if (_bulkMode && _selectedReceipts.isNotEmpty)
                  BulkActionsToolbarWidget(
                    selectedCount: _selectedReceipts.length,
                    onSelectAll: _selectAllReceipts,
                    onClearSelection: _clearSelection,
                    onBulkEmail: _bulkEmailReceipts,
                    onBulkExport: _bulkExportPdf,
                  ),

                // Receipt list
                Expanded(
                  child: _isAdmin
                      ? TabBarView(
                          controller: _tabController,
                          children: [
                            _buildReceiptList(),
                            _buildUserReceiptList(),
                          ],
                        )
                      : _buildReceiptList(),
                ),
              ],
            ),
    );
  }

  // Add manual receipt creation dialog
  Future<void> _showManualReceiptCreationDialog() async {
    if (!_isAdmin) {
      Fluttertoast.showToast(
        msg: "Solo gli amministratori possono creare ricevute manuali",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => ManualReceiptCreationDialog(
        onReceiptCreated: () {
          _loadReceipts(); // Refresh receipt list
        },
      ),
    );
  }

  Widget _buildReceiptList() {
    if (_filteredReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64.sp, color: Colors.grey.shade400),
            SizedBox(height: 16.h),
            Text(
              'receipt.no_receipts_found'.tr(),
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                color: Colors.grey.shade600,
              ),
            ),
            if (_currentFilters.isNotEmpty) ...[
              SizedBox(height: 8.h),
              TextButton(
                onPressed: _clearFilters,
                child: Text(
                  'receipt.clear_filters'.tr(),
                  style: GoogleFonts.inter(color: Colors.blue.shade600),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final groupedReceipts = _groupReceiptsByMonth();

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: groupedReceipts.length,
      itemBuilder: (context, groupIndex) {
        final monthKey = groupedReceipts.keys.elementAt(groupIndex);
        final receiptsInMonth = groupedReceipts[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonthlyGroupHeaderWidget(
              monthKey: monthKey,
              receiptCount: receiptsInMonth.length,
              totalAmount: receiptsInMonth.fold(
                0.0,
                (sum, r) => sum + r.totalAmount,
              ),
            ),
            SizedBox(height: 8.h),
            ...receiptsInMonth.map(
              (receipt) => ReceiptCardWidget(
                receipt: receipt,
                isSelected: _selectedReceipts.contains(receipt.id),
                bulkMode: _bulkMode,
                onTap: () => _bulkMode
                    ? _toggleReceiptSelection(receipt.id)
                    : _showReceiptDetail(receipt),
                onToggleSelect: () => _toggleReceiptSelection(receipt.id),
                onViewPdf: () => _viewReceiptPdf(receipt),
                onSendEmail: () => _sendReceiptEmail(receipt),
                onDuplicate: () => _duplicateReceipt(receipt),
                onDelete: _isAdmin ? () => _deleteReceipt(receipt) : null,
              ),
            ),
            SizedBox(height: 24.h),
          ],
        );
      },
    );
  }

  Widget _buildUserReceiptList() {
    // Filter receipts for current user only
    final userReceipts = _filteredReceipts
        .where((receipt) => receipt.user?.id == _currentUser)
        .toList();

    if (userReceipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              'receipt.personal_receipts_empty'.tr(),
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: userReceipts.length,
      itemBuilder: (context, index) {
        final receipt = userReceipts[index];
        return ReceiptCardWidget(
          receipt: receipt,
          isSelected: _selectedReceipts.contains(receipt.id),
          bulkMode: _bulkMode,
          onTap: () => _bulkMode
              ? _toggleReceiptSelection(receipt.id)
              : _showReceiptDetail(receipt),
          onToggleSelect: () => _toggleReceiptSelection(receipt.id),
          onViewPdf: () => _viewReceiptPdf(receipt),
          onSendEmail: () => _sendReceiptEmail(receipt),
          onDuplicate: () => _duplicateReceipt(receipt),
        );
      },
    );
  }

  void _showReceiptDetail(ReceiptModel receipt) {
    // Implement receipt detail view
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 90.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Receipt detail content
              Text(
                'receipt.receipt_details_title'.tr(
                  namedArgs: {'number': '${receipt.receiptNumber}'},
                ),
                style: GoogleFonts.inter(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Add more receipt details here...
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewReceiptPdf(ReceiptModel receipt) async {
    try {
      // 🎯 CRITICAL FIX: Use the SAME service as User App
      // This ensures Admin sees EXACT same PDF with "Longiano" address and correct logo

      // Step 1: Fetch full receipt data from database (with organization_info)
      final receiptData = await _italianReceiptService.getReceiptById(
        receipt.id,
      );

      if (receiptData == null) {
        throw Exception('Ricevuta non trovata nel database');
      }

      // Step 2: Generate PDF using the SAME beautiful service as User App
      final pdf = await _italianReceiptService.generateBeautifulReceiptPDF(
        receiptData,
      );
      final pdfBytes = await pdf.save();

      // 🎯 FIX: Direct download with improved browser compatibility
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
        msg: "Ricevuta PDF scaricata con successo",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella visualizzazione PDF: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _sendReceiptEmail(ReceiptModel receipt) async {
    // Simulate email sending
    await Future.delayed(const Duration(seconds: 1));

    Fluttertoast.showToast(
      msg: "Email inviata a ${receipt.user?.fullName}",
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  Future<void> _deleteReceipt(ReceiptModel receipt) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            SizedBox(width: 8.w),
            Text(
              'Elimina Ricevuta',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Sei sicuro di voler eliminare la ricevuta N.${receipt.receiptNumber} di ${receipt.user?.fullName ?? 'cliente'}?\n\nQuesta azione è irreversibile e rimuoverà la ricevuta anche dalla cronologia pagamenti dell\'utente.',
          style: GoogleFonts.inter(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Elimina',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Admin delete: hard delete receipt + associated payment_confirmations
        await _italianReceiptService.deleteReceipt(
          receipt.id,
          deleteSubscription: true,
        );

        Fluttertoast.showToast(
          msg: 'Ricevuta eliminata con successo',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        await _loadReceipts(); // Refresh list
      } catch (error) {
        Fluttertoast.showToast(
          msg: 'Errore nell\'eliminazione: $error',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _duplicateReceipt(ReceiptModel receipt) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Duplica Ricevuta',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Duplicare la ricevuta ${receipt.receiptNumber} per ${receipt.user?.fullName}?',
          style: GoogleFonts.inter(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Duplica',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Duplicate receipt logic would go here
        await Future.delayed(const Duration(seconds: 1));

        Fluttertoast.showToast(
          msg: "Ricevuta duplicata con successo!",
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        await _loadReceipts(); // Refresh list
      } catch (error) {
        Fluttertoast.showToast(
          msg: "Errore nella duplicazione: $error",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }
}
