import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added missing import for rootBundle
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
      setState(() => _error = 'Errore nel caricamento delle ricevute: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createReceipt(Map<String, dynamic> receiptData) async {
    setState(() => _isLoading = true);
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw Exception('Utente non autenticato');

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

      // Get the created receipt
      final createdReceiptData =
          await _receiptService.getReceiptById(receiptId);
      if (createdReceiptData != null) {
        final receipt = ItalianReceiptModel.fromJson(createdReceiptData);
        setState(() {
          _selectedReceipt = receipt;
          _tabController.animateTo(1); // Switch to preview tab
        });
      }
      await _loadReceipts();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ricevuta creata con successo!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella creazione della ricevuta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdf(ItalianReceiptModel receipt) async {
    try {
      final pdf = await _createPdf(receipt);

      // Show print preview
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Ricevuta_${receipt.receiptNumber}',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella generazione del PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<pw.Document> _createPdf(ItalianReceiptModel receipt) async {
    final pdf = pw.Document();

    // Load logo image if available
    pw.ImageProvider? logoImage;
    try {
      final logoData =
          await rootBundle.load('assets/images/152933-1756821415426.jpg');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo not available, will use text placeholder
      logoImage = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Professional Header with logo and organization info
              _buildProfessionalPdfHeader(receipt, logoImage),
              pw.SizedBox(height: 24),

              // Receipt title and number
              _buildPdfTitle(receipt),
              pw.SizedBox(height: 20),

              // Customer information
              _buildPdfCustomerInfo(receipt),
              pw.SizedBox(height: 20),

              // Professional Receipt details table
              _buildProfessionalPdfReceiptTable(receipt),
              pw.SizedBox(height: 20),

              // Payment method and notes
              _buildPdfPaymentInfo(receipt),
              pw.SizedBox(height: 20),

              // Professional VAT summary
              _buildProfessionalPdfVatSummary(receipt),
              pw.SizedBox(height: 24),

              // Footer
              _buildPdfFooter(),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildProfessionalPdfHeader(
      ItalianReceiptModel receipt, pw.ImageProvider? logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.red600,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo
          pw.Container(
            width: 80,
            height: 80,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: logoImage != null
                ? pw.Container(
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                  )
                : pw.Center(
                    child: pw.Text(
                      'TEAM\nRAGNAROK\nASD',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red600,
                      ),
                    ),
                  ),
          ),
          pw.SizedBox(width: 20),

          // Organization info
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  receipt.organizationInfo?.name ?? 'Team Ragnarok ASD',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  receipt.organizationInfo?.address ??
                      'via giulio bezzi 25, 48026 Russi - RA',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'C.F.: ${receipt.organizationInfo?.taxCode ?? '92100170395'}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTitle(ItalianReceiptModel receipt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Ricevuta Fiscale - ${receipt.receiptNumber.split('-').last} del ${receipt.formattedIssueDate}',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red600,
            ),
          ),
          if (receipt.validityEndDate != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Scadenza iscrizione: ${receipt.validityEndDate!.day.toString().padLeft(2, '0')}-${receipt.validityEndDate!.month.toString().padLeft(2, '0')}-${receipt.validityEndDate!.year}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPdfCustomerInfo(ItalianReceiptModel receipt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Dati di fatturazione',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'DEST: ${receipt.customerName}',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
          if (receipt.customerTaxCode != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'C.F. ${receipt.customerTaxCode}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
            ),
          ],
          if (receipt.customerAddress != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Indirizzo: ${receipt.customerAddress}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildProfessionalPdfReceiptTable(ItalianReceiptModel receipt) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          // Header with gradient-like color
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.red600,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Table(
              border: null,
              children: [
                pw.TableRow(
                  children: [
                    _buildPdfTableCell('Nome', isHeader: true),
                    _buildPdfTableCell('Quantità', isHeader: true),
                    _buildPdfTableCell('Prezzo unitario', isHeader: true),
                    _buildPdfTableCell('Sconto', isHeader: true),
                    _buildPdfTableCell('Iva', isHeader: true),
                    _buildPdfTableCell('Importo', isHeader: true),
                  ],
                ),
              ],
            ),
          ),

          // Data row
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(6),
                bottomRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Table(
              border: null,
              children: [
                pw.TableRow(
                  children: [
                    _buildPdfTableCell(
                      '${receipt.description}${receipt.formattedValidityPeriod.isNotEmpty ? '\n${receipt.formattedValidityPeriod}' : ''}',
                    ),
                    _buildPdfTableCell(receipt.quantity.toString()),
                    _buildPdfTableCell(
                      '€${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                    _buildPdfTableCell(
                      receipt.discountPercentage > 0
                          ? '${receipt.discountPercentage.toStringAsFixed(0)}%'
                          : '-',
                    ),
                    _buildPdfTableCell(
                      '${receipt.vatRate}% ${receipt.fiscalNotes?.contains('N2.2') == true ? 'N2.2' : ''}',
                    ),
                    _buildPdfTableCell(
                      '€${receipt.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                      isTotal: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTableCell(String text,
      {bool isHeader = false, bool isTotal = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight:
              isHeader || isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : isTotal
                  ? PdfColors.red700
                  : PdfColors.grey800,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _buildPdfPaymentInfo(ItalianReceiptModel receipt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.green200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'METODO PAGAMENTO: ${receipt.paymentMethodText}',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green800,
            ),
          ),
          if (receipt.fiscalNotes != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'NOTE FISCALI',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              receipt.fiscalNotes!,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.green700),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildProfessionalPdfVatSummary(ItalianReceiptModel receipt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.orange200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RIEPILOGO IVA',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
          pw.SizedBox(height: 12),

          // IVA Table
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.orange200),
            ),
            child: pw.Table(
              border:
                  pw.TableBorder.all(color: PdfColors.orange200, width: 0.5),
              children: [
                // Header
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.orange100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'IMPONIBILE',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange800),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'IMPOSTE',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange800),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'IMPORTO',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange800),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),

                // Data
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '${receipt.vatRate}%',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey800),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '€${receipt.taxableAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey800),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '€${receipt.vatAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey800),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // Total section
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.red600,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Imponibile €${receipt.taxableAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white),
                    ),
                    pw.Text(
                      'Totale IVA €${receipt.vatAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'TOTALE: €${receipt.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red700,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Center(
        child: pw.Column(
          children: [
            pw.Text(
              'Ricevuta Fiscale generata da APP Palestre',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'powered by Shaggy Owl S.r.l.s',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestione Ricevute Fiscali',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18.sp,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Nuova Ricevuta', icon: Icon(Icons.add_box)),
            Tab(text: 'Anteprima', icon: Icon(Icons.preview)),
            Tab(text: 'Archivio', icon: Icon(Icons.archive)),
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
                        child: const Text('Riprova'),
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
                        : const Center(
                            child: Text(
                              'Seleziona o crea una ricevuta per visualizzare l\'anteprima',
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
                    ),
                  ],
                ),
    );
  }
}
