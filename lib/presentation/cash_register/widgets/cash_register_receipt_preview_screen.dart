import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../models/receipt_model.dart';
import '../../../services/italian_receipt_service.dart';
import '../../italian_receipt_generation/widgets/receipt_preview_widget.dart';

/// Generates and shares/downloads a receipt's PDF exactly like the PDF icon
/// in "Gestione Ricevute" → Archivio (ReceiptListWidget.onGeneratePdf) and
/// the "Genera PDF" button in its preview tab — both wired in
/// ItalianReceiptGenerationScreen to the same private _generatePdf method.
/// Replicated here (same service calls, same web/mobile branching, same
/// file name pattern e.g. Ricevuta_033_2026.pdf) because that method can't
/// be called directly from outside its State class.
Future<void> downloadReceiptPdf(
  BuildContext context,
  ItalianReceiptModel receipt,
) async {
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

/// Opens the exact same receipt preview shown in "Gestione Ricevute"
/// (ItalianReceiptGenerationScreen's preview tab, reached there via
/// onReceiptTap) for a receipt tapped from the Registro di Cassa.
///
/// Reuses ReceiptPreviewWidget as-is, unmodified — only the surrounding
/// Scaffold/AppBar are new here, since that widget is normally hosted
/// inside a TabBarView tab rather than its own screen.
class CashRegisterReceiptPreviewScreen extends StatelessWidget {
  const CashRegisterReceiptPreviewScreen({Key? key, required this.receipt})
      : super(key: key);

  final ItalianReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ricevuta')),
      body: ReceiptPreviewWidget(
        receipt: receipt,
        onGeneratePdf: () => downloadReceiptPdf(context, receipt),
      ),
    );
  }
}
