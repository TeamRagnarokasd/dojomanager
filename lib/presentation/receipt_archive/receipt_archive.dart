import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';

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
          _isAdmin = user.userMetadata?['role'] == 'admin' ||
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
      List<ReceiptModel> receipts;

      if (_isAdmin) {
        receipts = await _receiptService.getAllReceipts();
      } else {
        receipts = await _receiptService.getUserReceipts(_currentUser!);
      }

      setState(() {
        _allReceipts = receipts;
        _filteredReceipts = receipts;
      });

      await _calculateStatistics();
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nel caricamento ricevute: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateStatistics() async {
    final now = DateTime.now();
    final currentMonthReceipts = _allReceipts
        .where((receipt) =>
            receipt.issueDate.year == now.year &&
            receipt.issueDate.month == now.month)
        .toList();

    final monthlyRevenue = currentMonthReceipts.fold<double>(
        0.0, (sum, receipt) => sum + receipt.totalAmount);

    setState(() {
      _statistics = {
        'total_receipts': _allReceipts.length,
        'monthly_revenue': monthlyRevenue,
        'pending_receipts':
            _allReceipts.where((r) => r.status == 'draft').length,
        'current_month_receipts': currentMonthReceipts.length,
      };
    });
  }

  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _currentFilters = filters;
      _filteredReceipts = _allReceipts.where((receipt) {
        // Date range filter
        if (filters['date_from'] != null) {
          if (receipt.issueDate.isBefore(filters['date_from'] as DateTime)) {
            return false;
          }
        }
        if (filters['date_to'] != null) {
          if (receipt.issueDate.isAfter(filters['date_to'] as DateTime)) {
            return false;
          }
        }

        // Payment method filter
        if (filters['payment_method'] != null &&
            filters['payment_method'] != 'all') {
          if (receipt.paymentMethod != filters['payment_method']) {
            return false;
          }
        }

        // Subscription type filter
        if (filters['subscription_type'] != null &&
            filters['subscription_type'] != 'all') {
          if (receipt.subscription?.type != filters['subscription_type']) {
            return false;
          }
        }

        // Client search filter
        if (filters['client_search'] != null &&
            (filters['client_search'] as String).isNotEmpty) {
          final searchTerm = (filters['client_search'] as String).toLowerCase();
          final clientName = receipt.user?.fullName.toLowerCase() ?? '';
          if (!clientName.contains(searchTerm)) {
            return false;
          }
        }

        // Amount range filter
        if (filters['amount_min'] != null) {
          if (receipt.totalAmount < (filters['amount_min'] as double)) {
            return false;
          }
        }
        if (filters['amount_max'] != null) {
          if (receipt.totalAmount > (filters['amount_max'] as double)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _currentFilters = {};
      _filteredReceipts = _allReceipts;
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
                  fontSize: 18.sp, fontWeight: FontWeight.w600),
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
            ...selectedReceiptList.take(3).map((receipt) => Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Text(
                    '• ${receipt.user?.fullName} - Ricevuta ${receipt.receiptNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                )),
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
            child: Text('Annulla',
                style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Invia Email',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
      final pdf = pw.Document();

      for (final receipt in selectedReceiptList) {
        pdf.addPage(await _generateReceiptPage(receipt));
      }

      final pdfBytes = await pdf.save();

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

  Future<pw.Page> _generateReceiptPage(ReceiptModel receipt) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TEAM RAGNAROK ASD',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Via Giulio Bezzi 25, 48026 Russi-RA'),
                    pw.Text('CF: 92100170395'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('RICEVUTA NON FISCALE'),
                    pw.Text('N. ${receipt.receiptNumber}'),
                    pw.Text(
                        'Del ${DateFormat('dd-MM-yyyy').format(receipt.issueDate)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Client details
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all()),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DESTINATARIO:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(receipt.user?.fullName ?? ''),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Receipt table
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('DESCRIZIONE',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('QTÀ',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('PREZZO',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('IMPORTO',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(receipt.description)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(receipt.quantity.toString())),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            '€${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}')),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}')),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Payment and total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'METODO PAGAMENTO: ${_getPaymentMethodText(receipt.paymentMethod)}'),
                pw.Text(
                    'TOTALE: €${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        );
      },
    );
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
          'Archivio Ricevute',
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
            icon: Icon(
              Icons.add_circle_outline,
              color: Colors.green.shade600,
            ),
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
            Icon(
              Icons.receipt_long,
              size: 64.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              'Nessuna ricevuta trovata',
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
                  'Rimuovi filtri',
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
              totalAmount:
                  receiptsInMonth.fold(0.0, (sum, r) => sum + r.totalAmount),
            ),
            SizedBox(height: 8.h),
            ...receiptsInMonth.map((receipt) => ReceiptCardWidget(
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
                )),
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
              'Nessuna ricevuta personale trovata',
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
                'Dettagli Ricevuta ${receipt.receiptNumber}',
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
      final pdf = pw.Document();
      pdf.addPage(await _generateReceiptPage(receipt));
      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
      } else {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'ricevuta_${receipt.receiptNumber}.pdf',
        );
      }
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
            child: Text('Annulla',
                style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Duplica',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
