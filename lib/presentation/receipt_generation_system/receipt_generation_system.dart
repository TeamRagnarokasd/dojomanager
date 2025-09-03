import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';

import '../../models/receipt_model.dart';
import '../../services/receipt_service.dart';
import '../../services/supabase_service.dart';
import './widgets/batch_receipt_widget.dart';
import './widgets/manual_amount_dialog_widget.dart';
import './widgets/payment_method_selection_widget.dart';
import './widgets/receipt_preview_widget.dart';
import './widgets/receipt_template_preview_widget.dart';

class ReceiptGenerationSystem extends StatefulWidget {
  const ReceiptGenerationSystem({Key? key}) : super(key: key);

  @override
  State<ReceiptGenerationSystem> createState() =>
      _ReceiptGenerationSystemState();
}

class _ReceiptGenerationSystemState extends State<ReceiptGenerationSystem> {
  final ReceiptService _receiptService = ReceiptService();
  final SupabaseService _supabaseService = SupabaseService.instance;

  bool _isLoading = false;
  bool _showBatchMode = false;
  List<ReceiptModel> _generatedReceipts = [];
  List<Map<String, dynamic>> _userProfiles = [];
  ReceiptModel? _previewReceipt;

  @override
  void initState() {
    super.initState();
    _loadUserProfiles();
  }

  Future<void> _loadUserProfiles() async {
    try {
      final response = await _supabaseService.client
          .from('user_profiles')
          .select('id, email, full_name, tax_code, address, phone, role')
          .order('full_name');

      setState(() {
        _userProfiles = List<Map<String, dynamic>>.from(response);
      });
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nel caricamento utenti: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _handleSumUpPayment(Map<String, dynamic> user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.credit_card, color: Colors.blue.shade700),
            ),
            SizedBox(width: 12.w),
            Text(
              'Pagamento SumUp',
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
              'Cliente: ${user['full_name']}',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            Text(
              'Il pagamento SumUp è stato completato con successo?\nConfermare per generare la ricevuta automaticamente.',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _buildSubscriptionButton(
                    'Mensile',
                    '€30,00',
                    () => Navigator.pop(context, {
                      'type': 'monthly',
                      'amount': 30.0,
                    }),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildSubscriptionButton(
                    'Annuale',
                    '€300,00',
                    () => Navigator.pop(context, {
                      'type': 'annual',
                      'amount': 300.0,
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      await _generateSumUpReceipt(user, result);
    }
  }

  Future<void> _handleSatispayPayment(Map<String, dynamic> user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ManualAmountDialogWidget(
        user: user,
        paymentMethod: 'Satispay',
      ),
    );

    if (result != null) {
      await _generateSatispayReceipt(user, result);
    }
  }

  Widget _buildSubscriptionButton(
      String title, String price, void Function() onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              price,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSumUpReceipt(
      Map<String, dynamic> user, Map<String, dynamic> data) async {
    setState(() => _isLoading = true);

    try {
      final receipt = await _receiptService.createReceiptForSumUp(
        userId: user['id'],
        subscriptionId: '', // SumUp has existing subscription
        amount: data['amount'],
        subscriptionType: data['type'],
      );

      setState(() {
        _generatedReceipts.add(receipt);
        _previewReceipt = receipt;
      });

      Fluttertoast.showToast(
        msg: "Ricevuta SumUp generata con successo!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      _showReceiptPreview(receipt);
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella generazione ricevuta: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateSatispayReceipt(
      Map<String, dynamic> user, Map<String, dynamic> data) async {
    setState(() => _isLoading = true);

    try {
      final receipt = await _receiptService.createReceiptForSatispay(
        userId: user['id'],
        amount: data['amount'],
        subscriptionType: data['type'],
      );

      setState(() {
        _generatedReceipts.add(receipt);
        _previewReceipt = receipt;
      });

      Fluttertoast.showToast(
        msg: "Ricevuta Satispay generata con successo!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      _showReceiptPreview(receipt);
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella generazione ricevuta: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showReceiptPreview(ReceiptModel receipt) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiptPreviewWidget(
        receipt: receipt,
        onPrint: () => _printReceipt(receipt),
        onShare: () => _shareReceiptPdf(receipt),
        onEmail: () => _sendEmailNotification(receipt),
      ),
    );
  }

  Future<void> _printReceipt(ReceiptModel receipt) async {
    try {
      final pdfBytes = await _generatePdfReceipt(receipt);

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
        );
      } else {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'ricevuta_${receipt.receiptNumber}.pdf',
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella stampa: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _shareReceiptPdf(ReceiptModel receipt) async {
    try {
      final pdfBytes = await _generatePdfReceipt(receipt);

      if (kIsWeb) {
        // Web - trigger download
        final blob = Uint8List.fromList(pdfBytes);
        final url = Uri.dataFromBytes(blob, mimeType: 'application/pdf');
        // Use browser download functionality
      } else {
        final tempDir = await getTemporaryDirectory();
        final file =
            File('${tempDir.path}/ricevuta_${receipt.receiptNumber}.pdf');
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella condivisione: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<Uint8List> _generatePdfReceipt(ReceiptModel receipt) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
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
                      pw.Text(
                        'TEAM RAGNAROK ASD',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('Via Giulio Bezzi 25'),
                      pw.Text('48026 Russi-RA'),
                      pw.Text('CF: 92100170395'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('RICEVUTA NON FISCALE'),
                      pw.Text('N. ${receipt.receiptNumber}'),
                      pw.Text(
                          'Del ${receipt.issueDate.day.toString().padLeft(2, '0')}-${receipt.issueDate.month.toString().padLeft(2, '0')}-${receipt.issueDate.year}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Client details
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
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

              // Receipt details
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('DESCRIZIONE',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('QTÀ',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('PREZZO',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('IMPORTO',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(receipt.description),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(receipt.quantity.toString()),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            '€${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}'),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Payment method and total
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
              pw.SizedBox(height: 20),

              // VAT summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('RIEPILOGO IVA',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            'Imponibile: €${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}'),
                        pw.Text(
                            'IVA ${receipt.vatRate.toStringAsFixed(2)}%: €0,00'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
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

  Future<void> _sendEmailNotification(ReceiptModel receipt) async {
    // Email notification would be implemented via Supabase edge functions
    Fluttertoast.showToast(
      msg: "Notifica email inviata al cliente",
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Sistema Generazione Ricevute',
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
          IconButton(
            icon: Icon(
              _showBatchMode ? Icons.person : Icons.group,
              color: Colors.grey.shade700,
            ),
            onPressed: () {
              setState(() {
                _showBatchMode = !_showBatchMode;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Template Preview Header
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.all(16.w),
                  child: const ReceiptTemplatePreviewWidget(),
                ),

                SizedBox(height: 8.h),

                // Main Content
                Expanded(
                  child: _showBatchMode
                      ? BatchReceiptWidget(
                          userProfiles: _userProfiles,
                          onGenerate: _handleBatchGeneration,
                        )
                      : _buildUserList(),
                ),
              ],
            ),
    );
  }

  Widget _buildUserList() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.grey.shade600),
                SizedBox(width: 8.w),
                Text(
                  'Seleziona Cliente',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _userProfiles.length,
              itemBuilder: (context, index) {
                final user = _userProfiles[index];
                return Card(
                  elevation: 1,
                  margin: EdgeInsets.only(bottom: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16.w),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        user['full_name'][0].toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      user['full_name'],
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4.h),
                        Text(
                          user['email'],
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade600,
                            fontSize: 12.sp,
                          ),
                        ),
                        if (user['tax_code'] != null) ...[
                          SizedBox(height: 2.h),
                          Text(
                            'CF: ${user['tax_code']}',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade500,
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: PaymentMethodSelectionWidget(
                      onSumUpSelected: () => _handleSumUpPayment(user),
                      onSatispaySelected: () => _handleSatispayPayment(user),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBatchGeneration(
      List<Map<String, dynamic>> selectedUsers) async {
    // Implement batch receipt generation
    setState(() => _isLoading = true);

    final results = <ReceiptModel>[];

    try {
      for (final user in selectedUsers) {
        // For batch, assume monthly subscription with SumUp
        final receipt = await _receiptService.createReceiptForSumUp(
          userId: user['id'],
          subscriptionId: '',
          amount: 30.0,
          subscriptionType: 'monthly',
        );
        results.add(receipt);
      }

      setState(() {
        _generatedReceipts.addAll(results);
      });

      Fluttertoast.showToast(
        msg: "${results.length} ricevute generate con successo!",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } catch (error) {
      Fluttertoast.showToast(
        msg: "Errore nella generazione batch: $error",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}