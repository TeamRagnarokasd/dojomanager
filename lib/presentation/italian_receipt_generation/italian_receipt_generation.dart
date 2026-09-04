import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/app_export.dart';
// Added missing import for rootBundle
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';

import '../../models/receipt_model.dart';
import '../../services/auth_service.dart';
import '../../services/italian_receipt_service.dart';
import './widgets/receipt_form_widget.dart';
import './widgets/receipt_list_widget.dart';
import './widgets/receipt_preview_widget.dart';

class ItalianReceiptGenerationScreen extends StatefulWidget {
  const ItalianReceiptGenerationScreen({Key? key}) : super(key: key);

  @override
  State<ItalianReceiptGenerationScreen> createState() =>
      _ItalianReceiptGenerationScreenState();
}

class _ItalianReceiptGenerationScreenState
    extends State<ItalianReceiptGenerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _receiptService = ItalianReceiptService();
  final _authService = AuthService.instance;

  List<ItalianReceiptModel> _receipts = [];
  ItalianReceiptModel? _selectedReceipt;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReceipts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    try {
      final receipts = await _receiptService.getAllReceipts();
      setState(() {
        _receipts =
            receipts.map((data) => ItalianReceiptModel.fromJson(data)).toList();
        _error = null;
      });
    } catch (e) {
      setState(
        () => _error = 'italian_receipt.load_receipts_error'.tr(
          namedArgs: {'error': '$e'},
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createReceipt(Map<String, dynamic> receiptData) async {
    setState(() => _isLoading = true);
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw Exception('Utente non autenticato');

      // Step 1: Create receipt in database
      final receiptId = await _receiptService.createManualReceipt(
        createdBy: currentUser.id,
        customerName: receiptData['customerName'],
        customerTaxCode: receiptData['customerTaxCode'],
        customerAddress: receiptData['customerAddress'],
        description: receiptData['description'],
        quantity: receiptData['quantity'] ?? 1,
        unitPrice: receiptData['unitPrice'],
        discountPercentage: receiptData['discountPercentage'] ?? 0,
        vatRate: receiptData['vatRate'] ?? '0',
        paymentMethod: receiptData['paymentMethod'] ?? 'cash',
        validityStartDate: receiptData['validityStartDate'],
        validityEndDate: receiptData['validityEndDate'],
        notes: receiptData['notes'],
        fiscalNotes: receiptData['fiscalNotes'],
      );

      // Step 2: Activate subscription with discipline permissions
      await _receiptService.activateSubscriptionForUser(
        userId: receiptData['userId'],
        subscriptionPlanId: receiptData['subscriptionPlanId'],
        amount: receiptData['unitPrice'],
        paymentMethod: receiptData['paymentMethod'],
        targetDiscipline: receiptData['targetDiscipline'],
        targetDiscipline2: receiptData['targetDiscipline2'],
        includesPreparazione: receiptData['includesPreparazione'] ?? false,
        receiptId: receiptId,
        isCustomPlan: receiptData['isCustomPlan'] == true,
      );

      // Get the created receipt
      final createdReceiptData = await _receiptService.getReceiptById(
        receiptId,
      );
      if (createdReceiptData != null) {
        final receipt = ItalianReceiptModel.fromJson(createdReceiptData);
        setState(() {
          _selectedReceipt = receipt;
          _tabController.animateTo(1); // Switch to preview tab
        });
      }
      await _loadReceipts();

      final d1 = receiptData['targetDiscipline'];
      final d2 = receiptData['targetDiscipline2'];
      final prep = receiptData['includesPreparazione'] == true;
      String successMsg =
          'Ricevuta creata e abbonamento attivato con successo!';
      if (d1 != null && d2 != null) {
        successMsg += '\nPermessi per $d1 e $d2 abilitati.';
      } else if (d1 != null) {
        successMsg += '\nPermessi per $d1 abilitati.';
      }
      if (prep) {
        successMsg += '\nPreparazione Atletica inclusa automaticamente.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'italian_receipt.create_error'.tr(namedArgs: {'error': '$e'}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdf(ItalianReceiptModel receipt) async {
    try {
      // 🎯 FIX: Use SAME PDF generator as payment_history page
      // This ensures consistent template without yellow VAT box
      final receiptData = await _receiptService.getReceiptById(receipt.id);

      if (receiptData == null) {
        throw Exception('Receipt not found in database');
      }

      // 🔥 Generate PDF using ItalianReceiptService (same as payment_history)
      final pdfDocument = await _receiptService.generateBeautifulReceiptPDF(
        receiptData,
      );

      // Show print preview on web; share/save on mobile
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfDocument.save(),
          name: 'Ricevuta_${receipt.receiptNumber}',
          format: PdfPageFormat.a4,
        );
      } else {
        final pdfBytes = await pdfDocument.save();
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Ricevuta_${receipt.receiptNumber}.pdf',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'italian_receipt.pdf_error'.tr(namedArgs: {'error': '$e'}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteReceipts(
    List<String> receiptIds,
    bool deleteSubscription,
  ) async {
    for (final id in receiptIds) {
      await _receiptService.deleteReceipt(
        id,
        deleteSubscription: deleteSubscription,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'receipt.title'.tr(),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
        ),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: 'receipt.new_receipt'.tr(), icon: Icon(Icons.add_box)),
            Tab(text: 'receipt.preview'.tr(), icon: Icon(Icons.preview)),
            Tab(text: 'receipt.archive'.tr(), icon: Icon(Icons.archive)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReceipts,
                        child: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // New Receipt Form
                    ReceiptFormWidget(
                      onSubmit: _createReceipt,
                      isLoading: _isLoading,
                    ),

                    // Receipt Preview
                    _selectedReceipt != null
                        ? ReceiptPreviewWidget(
                            receipt: _selectedReceipt!,
                            onGeneratePdf: () =>
                                _generatePdf(_selectedReceipt!),
                          )
                        : Center(
                            child: Text(
                              'italian_receipt.preview_empty_hint'.tr(),
                              textAlign: TextAlign.center,
                            ),
                          ),

                    // Receipt Archive
                    ReceiptListWidget(
                      receipts: _receipts,
                      onReceiptTap: (receipt) {
                        setState(() => _selectedReceipt = receipt);
                        _tabController.animateTo(1);
                      },
                      onGeneratePdf: _generatePdf,
                      onRefresh: _loadReceipts,
                      onDeleteReceipts: _deleteReceipts,
                    ),
                  ],
                ),
    );
  }
}
