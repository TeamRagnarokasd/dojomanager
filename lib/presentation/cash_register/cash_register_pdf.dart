import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/cash_register_service.dart';

/// € formatted the Italian way (comma decimal, sign in front), e.g.
/// "€ 1.234,56" or "-€ 12,00". Used on screen (cash_register_screen.dart),
/// where Flutter's own text rendering shows € correctly.
String formatEuro(double value) {
  final sign = value < 0 ? '-' : '';
  final formatted = value.abs().toStringAsFixed(2).replaceAll('.', ',');
  return '$sign€ $formatted';
}

/// Amount formatted the Italian way (thousands separator, comma decimal,
/// sign in front) but WITHOUT the € symbol, e.g. "1.234,56" or "-12,00".
/// PDF-only: the standard Helvetica font used in this PDF does not support
/// the € glyph, so the € symbol must never appear here — column headers and
/// totals spell out "euro" in full instead (see buildCashRegisterMonthPdf).
String _formatAmountForPdf(double value) {
  final sign = value < 0 ? '-' : '';
  final formatted = NumberFormat('#,##0.00', 'it_IT').format(value.abs());
  return '$sign$formatted';
}

/// Builds the "Prima Nota" PDF for one month of the Registro di Cassa:
/// header, one row per ledger entry (giorno/operazione/entrata/uscita/saldo
/// progressivo) and a totals row. Uses only the `pdf` package already in
/// pubspec.yaml, with the base14 Helvetica font (bundled in the package
/// itself, no extra asset, no other font). Helvetica does not support the €
/// glyph, so amounts here never use the € symbol (see
/// _formatAmountForPdf) — column headers and totals spell out "euro"
/// in full instead.
Future<pw.Document> buildCashRegisterMonthPdf(
  CashRegisterMonthSummary summary,
) async {
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    ),
  );

  final monthLabel = _capitalize(
    DateFormat('MMMM yyyy', 'it_IT').format(summary.month),
  );
  final dayFormat = DateFormat('dd/MM', 'it_IT');

  pw.TextStyle cellStyle({bool bold = false, PdfColor? color}) => pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColors.black,
      );

  pw.Widget cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: cellStyle(bold: bold, color: color),
        textAlign: align,
      ),
    );
  }

  final headerRow = pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
    children: [
      cell('Giorno', bold: true),
      cell('Operazione', bold: true),
      cell('Entrata (euro)', bold: true, align: pw.TextAlign.right),
      cell('Uscita (euro)', bold: true, align: pw.TextAlign.right),
      cell('Saldo (euro)', bold: true, align: pw.TextAlign.right),
    ],
  );

  final dataRows = <pw.TableRow>[];
  for (var i = 0; i < summary.entries.length; i++) {
    final entry = summary.entries[i];
    final balance = summary.progressiveBalances[i];

    final operationParts = <String>[entry.description];
    if (entry.customerName != null && entry.customerName!.trim().isNotEmpty) {
      operationParts.add(entry.customerName!.trim());
    }
    if (entry.receiptNumber != null && entry.receiptNumber!.trim().isNotEmpty) {
      operationParts.add('ricevuta ${entry.receiptNumber}');
    }

    dataRows.add(
      pw.TableRow(
        children: [
          cell(dayFormat.format(entry.entryDate)),
          cell(operationParts.join(' - ')),
          cell(
            entry.isEntrata ? _formatAmountForPdf(entry.amount) : '',
            color: PdfColors.green800,
            align: pw.TextAlign.right,
          ),
          cell(
            !entry.isEntrata ? _formatAmountForPdf(entry.amount) : '',
            color: PdfColors.red800,
            align: pw.TextAlign.right,
          ),
          cell(
            _formatAmountForPdf(balance),
            color: balance < 0 ? PdfColors.red800 : PdfColors.black,
            align: pw.TextAlign.right,
          ),
        ],
      ),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.red700,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Team Ragnarok ASD',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Registro di Cassa - Prima Nota',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          monthLabel,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Saldo a inizio mese: ${_formatAmountForPdf(summary.balanceAtMonthStart)} euro',
          style: cellStyle(),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(3.2),
            2: pw.FlexColumnWidth(1.3),
            3: pw.FlexColumnWidth(1.3),
            4: pw.FlexColumnWidth(1.5),
          },
          children: [headerRow, ...dataRows],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale entrate del mese', style: cellStyle(bold: true)),
                  pw.Text(
                    '${_formatAmountForPdf(summary.totalEntrate)} euro',
                    style: cellStyle(bold: true, color: PdfColors.green800),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale uscite del mese', style: cellStyle(bold: true)),
                  pw.Text(
                    '${_formatAmountForPdf(summary.totalUscite)} euro',
                    style: cellStyle(bold: true, color: PdfColors.red800),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Saldo a fine mese', style: cellStyle(bold: true)),
                  pw.Text(
                    '${_formatAmountForPdf(summary.balanceAtMonthEnd)} euro',
                    style: cellStyle(
                      bold: true,
                      color: summary.balanceAtMonthEnd < 0
                          ? PdfColors.red800
                          : PdfColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return pdf;
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
