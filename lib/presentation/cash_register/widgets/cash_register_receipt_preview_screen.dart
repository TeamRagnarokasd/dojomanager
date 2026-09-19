import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../models/receipt_model.dart';
import '../../../services/italian_receipt_service.dart';
import '../../italian_receipt_generation/widgets/receipt_preview_widget.dart';

/// Opens the exact same receipt preview shown in "Gestione Ricevute"
/// (ItalianReceiptGenerationScreen's preview tab, reached there via
/// onReceiptTap) for a receipt tapped from the Registro di Cassa.
///
/// Reuses ReceiptPreviewWidget as-is, unmodified — only the surrounding
/// Scaffold/AppBar are new here, since that widget is normally hosted
/// inside a TabBarView tab rather than its own screen. _generatePdf below
/// mirrors ItalianReceiptGenerationScreen._generatePdf exactly (same
/// service calls, same web/mobile branching); it can't call that method
/// directly since it's private to that screen's State class.
class CashRegisterReceiptPreviewScreen extends StatelessWidget {
  const CashRegisterReceiptPreviewScreen({Key? key, required this.receipt})
      : super(key: key);

  final ItalianReceiptModel receipt;

  Future<void> _generatePdf(BuildContext context) async {
    final receiptService = ItalianReceiptService();
    try {
      final receiptData = await receiptService.getReceiptById(receipt.id);
      if (receiptData == null) {
        throw Exception('Ricevuta non trovata');
      }
      final pdfDocument = await receiptService.generateBeautifulReceiptPDF(
        receiptData,
      );

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfDocument.save(),
          name: 'Ricevuta_${receipt.receiptNumber}',
          format: PdfPageFormat.a4,
        );
      } else {
        final pdfBytes = await pdfDocument.save();
        final sanitizedReceiptNumber = receipt.receiptNumber
            .toString()
            .replaceAll('/', '_')
            .replaceAll('\\', '_');
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Ricevuta_$sanitizedReceiptNumber.pdf',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nella generazione del PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ricevuta')),
      body: ReceiptPreviewWidget(
        receipt: receipt,
        onGeneratePdf: () => _generatePdf(context),
      ),
    );
  }
}
