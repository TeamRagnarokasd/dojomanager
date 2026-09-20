import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/receipt_model.dart';
import '../../services/italian_receipt_service.dart';
import '../../services/work_attendance_service.dart';

/// The three "prospetti per la commercialista" required by articolo 5,
/// comma 4, del contratto — each read-only from server-computed data, never
/// recomputed here beyond simple per-row arithmetic already described by
/// the contract (e.g. km × tariffa for a single day).
enum WorkPdfDocType { compensation, mealVoucher, km }

const List<String> _kMonthNamesLower = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

const List<String> _kWeekdayNames = [
  'lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica',
];

int _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// A reporting period for the prospetti: either one calendar month or a
/// whole calendar year.
class WorkPdfPeriod {
  const WorkPdfPeriod.month(this.year, this.month) : isFullYear = false;
  const WorkPdfPeriod.year(this.year)
      : month = null,
        isFullYear = true;

  final int year;
  final int? month;
  final bool isFullYear;

  DateTime get start => isFullYear ? DateTime(year, 1, 1) : DateTime(year, month!, 1);
  DateTime get end => isFullYear
      ? DateTime(year, 12, 31)
      : DateTime(year, month!, _lastDayOfMonth(year, month!));

  String get label => isFullYear ? '$year' : '${_kMonthNamesLower[month! - 1]} $year';

  /// e.g. "2026-10" for a month, "2026" for a year — used in file names.
  String get fileTag => isFullYear ? '$year' : '$year-${month!.toString().padLeft(2, '0')}';
}

String workPdfDocLabel(WorkPdfDocType type) {
  switch (type) {
    case WorkPdfDocType.compensation:
      return 'Prospetto compensi';
    case WorkPdfDocType.mealVoucher:
      return 'Prospetto buoni pasto';
    case WorkPdfDocType.km:
      return 'Prospetto rimborso km';
  }
}

String _workPdfDocTitle(WorkPdfDocType type) {
  switch (type) {
    case WorkPdfDocType.compensation:
      return 'Prospetto compensi';
    case WorkPdfDocType.mealVoucher:
      return 'Prospetto buoni pasto';
    case WorkPdfDocType.km:
      return 'Prospetto rimborso chilometrico';
  }
}

String _workPdfFileSlug(WorkPdfDocType type) {
  switch (type) {
    case WorkPdfDocType.compensation:
      return 'compensi';
    case WorkPdfDocType.mealVoucher:
      return 'buoni_pasto';
    case WorkPdfDocType.km:
      return 'rimborso_km';
  }
}

/// e.g. "Prospetto_compensi_2026-10.pdf" or "Prospetto_compensi_2026.pdf".
String workPdfFileName(WorkPdfDocType type, WorkPdfPeriod period) =>
    'Prospetto_${_workPdfFileSlug(type)}_${period.fileTag}.pdf';

/// 'buoni_pasto' for the meal-voucher prospetto, 'lavoratori_sportivi' for
/// the other two — the asd_document_categories key to file it under when
/// saved to the Archivio documenti.
String workPdfArchiveCategory(WorkPdfDocType type) =>
    type == WorkPdfDocType.mealVoucher ? 'buoni_pasto' : 'lavoratori_sportivi';

/// € formatted the Italian way, WITHOUT the € symbol (the base Helvetica
/// font used here has no € glyph — see cash_register_pdf.dart, whose
/// approach this mirrors): amounts spell out "euro" in full instead.
String _formatAmountForPdf(num value) {
  final sign = value < 0 ? '-' : '';
  return '$sign${NumberFormat('#,##0.00', 'it_IT').format(value.abs())}';
}

String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

pw.TextStyle _cellStyle({bool bold = false, PdfColor? color}) => pw.TextStyle(
      fontSize: 9,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? PdfColors.black,
    );

pw.Widget _cell(
  String text, {
  bool bold = false,
  PdfColor? color,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Text(text, style: _cellStyle(bold: bold, color: color), textAlign: align),
  );
}

/// Same red-header layout as ItalianReceiptService.generateBeautifulReceiptPDF
/// and asd_document_generation_screen.dart's _buildPdf (logo + organization
/// info) — replicated here, not imported, so this file stays isolated and
/// neither of those is touched.
pw.Widget _buildHeader(pw.MemoryImage logo, OrganizationInfo orgInfo) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(20),
    decoration: pw.BoxDecoration(
      color: PdfColors.red700,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 60, height: 60, child: pw.Image(logo)),
        pw.SizedBox(width: 15),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                orgInfo.name,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(orgInfo.address, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
              pw.Text(
                'c.f. ${orgInfo.taxCode}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
              ),
              if (orgInfo.pec != null && orgInfo.pec!.isNotEmpty)
                pw.Text(
                  'PEC: ${orgInfo.pec}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                ),
              if (orgInfo.phone != null && orgInfo.phone!.isNotEmpty)
                pw.Text(
                  'Tel: ${orgInfo.phone}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                ),
              if (orgInfo.email != null && orgInfo.email!.isNotEmpty)
                pw.Text(
                  'Email: ${orgInfo.email}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          'Pagina ${context.pageNumber} di ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );

pw.Widget _subtitleBlock({
  required String instructorName,
  required WorkPdfPeriod period,
}) {
  final style = const pw.TextStyle(fontSize: 11);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Collaboratore: $instructorName', style: style),
      pw.Text('Periodo: ${_capitalize(period.label)}', style: style),
      pw.Text(
        'Prospetto redatto ai sensi dell\'articolo 5, comma 4, del contratto.',
        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
      ),
    ],
  );
}

pw.Widget _noteBlock(String text) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
    );

pw.Widget _signatureBlock() => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 32),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Data: _______________________', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 24),
          pw.Text('Firma del tecnico: _______________________', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 24),
          pw.Text('Per l\'ASD: _______________________', style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );

Future<pw.MemoryImage> _loadLogo() async {
  final bytes = await rootBundle.load('assets/images/146804-1764638363594.jpg');
  return pw.MemoryImage(bytes.buffer.asUint8List());
}

pw.Document _newDocument() => pw.Document(
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
    );

/// Builds "Prospetto compensi": the monthly (or single-month) breakdown from
/// [summary] plus the already-received-before-contract figure, the rate
/// periods in force and the year's totals/limit/margin — all read as-is
/// from `work_compensation_summary`, never recomputed here.
Future<pw.Document> buildWorkCompensationPdf({
  required WorkCompensationSummary summary,
  required WorkPdfPeriod period,
  required String instructorName,
}) async {
  final pdf = _newDocument();
  final logo = await _loadLogo();
  final orgInfo = await ItalianReceiptService().getOrganizationInfo();
  final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');

  final tableRows = <pw.TableRow>[];
  if (period.isFullYear) {
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('Mese', bold: true),
          _cell('Lezioni pagate', bold: true, align: pw.TextAlign.right),
          _cell('Importo (euro)', bold: true, align: pw.TextAlign.right),
          _cell('Cumulato (euro)', bold: true, align: pw.TextAlign.right),
        ],
      ),
    );
    var cumulative = 0.0;
    for (final month in summary.monthly) {
      cumulative += month.amount;
      tableRows.add(
        pw.TableRow(
          children: [
            _cell(_capitalize(_kMonthNamesLower[month.month - 1])),
            _cell('${month.lessons}', align: pw.TextAlign.right),
            _cell(_formatAmountForPdf(month.amount), align: pw.TextAlign.right),
            _cell(_formatAmountForPdf(cumulative), bold: true, align: pw.TextAlign.right),
          ],
        ),
      );
    }
  } else {
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _cell('Mese', bold: true),
          _cell('Lezioni pagate', bold: true, align: pw.TextAlign.right),
          _cell('Importo (euro)', bold: true, align: pw.TextAlign.right),
        ],
      ),
    );
    var cumulative = 0.0;
    WorkMonthlyAmount? selectedMonth;
    for (final month in summary.monthly) {
      if (month.month <= period.month!) cumulative += month.amount;
      if (month.month == period.month) selectedMonth = month;
    }
    tableRows.add(
      pw.TableRow(
        children: [
          _cell(_capitalize(period.label)),
          _cell('${selectedMonth?.lessons ?? 0}', align: pw.TextAlign.right),
          _cell(_formatAmountForPdf(selectedMonth?.amount ?? 0), align: pw.TextAlign.right),
        ],
      ),
    );
    tableRows.add(
      pw.TableRow(
        children: [
          _cell('Cumulato dal 1° gennaio', bold: true),
          _cell(''),
          _cell(_formatAmountForPdf(cumulative), bold: true, align: pw.TextAlign.right),
        ],
      ),
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (context) => [
        _buildHeader(logo, orgInfo),
        pw.SizedBox(height: 16),
        pw.Text(_workPdfDocTitle(WorkPdfDocType.compensation),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _subtitleBlock(instructorName: instructorName, period: period),
        pw.SizedBox(height: 4),
        pw.Text(
          'Già percepito prima del contratto: '
          '${_formatAmountForPdf(summary.alreadyReceivedBeforeContract)} euro',
          style: _cellStyle(),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          children: tableRows,
        ),
        pw.SizedBox(height: 16),
        pw.Text('Periodi di compenso in vigore', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 4),
        for (final rp in summary.periods)
          pw.Text(
            'Dal ${dayFormat.format(rp.validFrom)}: ${_formatAmountForPdf(rp.hourlyRate)} euro/h, '
            '${rp.paidLessonsPerWeek} lezioni a settimana, '
            '${NumberFormat('#,##0.##', 'it_IT').format(rp.hoursPerLesson)} ore/lezione',
            style: _cellStyle(),
          ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale anno', style: _cellStyle(bold: true)),
                  pw.Text('${_formatAmountForPdf(summary.totalToDate)} euro', style: _cellStyle(bold: true)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Limite annuo', style: _cellStyle(bold: true)),
                  pw.Text('${_formatAmountForPdf(summary.annualLimit)} euro', style: _cellStyle(bold: true)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Margine a fine anno', style: _cellStyle(bold: true)),
                  pw.Text(
                    '${_formatAmountForPdf(summary.marginAtYearEnd)} euro',
                    style: _cellStyle(
                      bold: true,
                      color: summary.marginAtYearEnd < 0 ? PdfColors.red800 : PdfColors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _noteBlock(
          'Compenso calcolato sull\'autorizzazione (lezioni pagate a settimana), '
          'non sulle presenze registrate.',
        ),
        _signatureBlock(),
      ],
    ),
  );

  return pdf;
}

/// Builds "Prospetto buoni pasto": one row per day with a confirmed
/// presence in [period] (one voucher per day, never per lesson). When
/// [period] is a full year and [yearSummaryForCheck] is given, the totals
/// are cross-checked against `work_presence_summary` and any mismatch is
/// only logged — the day-by-day list built from the actual presence rows
/// is always what's shown.
Future<pw.Document> buildWorkMealVoucherPdf({
  required List<DateTime> presenceDays,
  required double voucherValue,
  required WorkPdfPeriod period,
  required String instructorName,
  WorkPresenceSummary? yearSummaryForCheck,
}) async {
  final pdf = _newDocument();
  final logo = await _loadLogo();
  final orgInfo = await ItalianReceiptService().getOrganizationInfo();
  final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');

  final total = presenceDays.length * voucherValue;

  if (yearSummaryForCheck != null &&
      (presenceDays.length != yearSummaryForCheck.days ||
          (total - yearSummaryForCheck.voucherTotal).abs() > 0.01)) {
    debugPrint(
      'work_pdfs: discrepanza buoni pasto per l\'anno ${period.year} — '
      'elenco: ${presenceDays.length} giorni/${_formatAmountForPdf(total)} euro, '
      'work_presence_summary: ${yearSummaryForCheck.days} giorni/'
      '${_formatAmountForPdf(yearSummaryForCheck.voucherTotal)} euro',
    );
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (context) => [
        _buildHeader(logo, orgInfo),
        pw.SizedBox(height: 16),
        pw.Text(_workPdfDocTitle(WorkPdfDocType.mealVoucher),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _subtitleBlock(instructorName: instructorName, period: period),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Data', bold: true),
                _cell('Giorno', bold: true),
                _cell('Valore buono (euro)', bold: true, align: pw.TextAlign.right),
              ],
            ),
            for (final day in presenceDays)
              pw.TableRow(
                children: [
                  _cell(dayFormat.format(day)),
                  _cell(_capitalize(_kWeekdayNames[day.weekday - 1])),
                  _cell(_formatAmountForPdf(voucherValue), align: pw.TextAlign.right),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale giorni', style: _cellStyle(bold: true)),
                  pw.Text('${presenceDays.length}', style: _cellStyle(bold: true)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale', style: _cellStyle(bold: true)),
                  pw.Text('${_formatAmountForPdf(total)} euro', style: _cellStyle(bold: true)),
                ],
              ),
            ],
          ),
        ),
        _noteBlock(
          'Un buono pasto elettronico per ogni giornata di effettiva prestazione, '
          'di valore non superiore al limite di esenzione vigente.',
        ),
        _signatureBlock(),
      ],
    ),
  );

  return pdf;
}

/// Builds "Prospetto rimborso chilometrico": one row per day with a
/// confirmed presence in [period], at the fixed round-trip km and ACI rate
/// from `work_settings`. Same year cross-check as the meal-voucher
/// prospetto (log only, list unchanged).
Future<pw.Document> buildWorkKmPdf({
  required List<DateTime> presenceDays,
  required WorkSettings settings,
  required WorkPdfPeriod period,
  required String instructorName,
  WorkPresenceSummary? yearSummaryForCheck,
}) async {
  final pdf = _newDocument();
  final logo = await _loadLogo();
  final orgInfo = await ItalianReceiptService().getOrganizationInfo();
  final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');

  final perDayAmount = double.parse((settings.kmRoundTrip * settings.kmRate).toStringAsFixed(2));
  final totalKm = presenceDays.length * settings.kmRoundTrip;
  final totalAmount = presenceDays.length * perDayAmount;

  if (yearSummaryForCheck != null &&
      (presenceDays.length != yearSummaryForCheck.days ||
          (totalAmount - yearSummaryForCheck.kmAmount).abs() > 0.01)) {
    debugPrint(
      'work_pdfs: discrepanza rimborso km per l\'anno ${period.year} — '
      'elenco: ${presenceDays.length} giorni/${_formatAmountForPdf(totalAmount)} euro, '
      'work_presence_summary: ${yearSummaryForCheck.days} giorni/'
      '${_formatAmountForPdf(yearSummaryForCheck.kmAmount)} euro',
    );
  }

  final routeFrom = settings.routeFrom;
  final routeTo = settings.routeTo;
  final routeLabel = (routeFrom != null &&
          routeFrom.trim().isNotEmpty &&
          routeTo != null &&
          routeTo.trim().isNotEmpty)
      ? '$routeFrom → $routeTo, andata e ritorno'
      : 'andata e ritorno';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: _footer,
      build: (context) => [
        _buildHeader(logo, orgInfo),
        pw.SizedBox(height: 16),
        pw.Text(_workPdfDocTitle(WorkPdfDocType.km),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _subtitleBlock(instructorName: instructorName, period: period),
        pw.SizedBox(height: 4),
        if (settings.vehicle != null && settings.vehicle!.trim().isNotEmpty)
          pw.Text('Veicolo: ${settings.vehicle}', style: _cellStyle()),
        pw.Text('Percorso: $routeLabel', style: _cellStyle()),
        pw.Text(
          'Km andata e ritorno: ${NumberFormat('#,##0.##', 'it_IT').format(settings.kmRoundTrip)} km '
          '- Tariffa ACI: ${_formatAmountForPdf(settings.kmRate)} euro/km',
          style: _cellStyle(),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('Data', bold: true),
                _cell('Percorso', bold: true),
                _cell('Km', bold: true, align: pw.TextAlign.right),
                _cell('Importo (euro)', bold: true, align: pw.TextAlign.right),
              ],
            ),
            for (final day in presenceDays)
              pw.TableRow(
                children: [
                  _cell(dayFormat.format(day)),
                  _cell(routeLabel),
                  _cell(NumberFormat('#,##0.##', 'it_IT').format(settings.kmRoundTrip),
                      align: pw.TextAlign.right),
                  _cell(_formatAmountForPdf(perDayAmount), align: pw.TextAlign.right),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale km', style: _cellStyle(bold: true)),
                  pw.Text('${NumberFormat('#,##0.##', 'it_IT').format(totalKm)} km',
                      style: _cellStyle(bold: true)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Totale', style: _cellStyle(bold: true)),
                  pw.Text('${_formatAmountForPdf(totalAmount)} euro', style: _cellStyle(bold: true)),
                ],
              ),
            ],
          ),
        ),
        _noteBlock(
          'Importo calcolato sulle tabelle nazionali ACI vigenti per il veicolo indicato.',
        ),
        _signatureBlock(),
      ],
    ),
  );

  return pdf;
}
