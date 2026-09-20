import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/admin_section_visibility_service.dart';
import '../../services/asd_documents_service.dart';
import '../../services/auth_service.dart';
import '../../services/work_attendance_service.dart';
import '../asd_documents_archive/widgets/asd_category_documents_screen.dart';
import 'widgets/work_pdf_preview_screen.dart';
import 'widgets/work_settings_screen.dart';
import 'work_pdfs.dart';

/// "Mese" or "Anno intero" for the PDF prospetti period picker.
enum _WorkPdfPeriodMode { month, year }

const List<String> _kMonthNames = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

String _formatEuro(num value) => '€ ${NumberFormat('#,##0.00', 'it_IT').format(value)}';

String _formatWholeEuro(num value) => '${NumberFormat('#,##0', 'it_IT').format(value)} €';

/// "Presenze e compensi": year selector plus three cards (compenso, buoni
/// pasto, rimborso km) built entirely from work_compensation_summary and
/// work_presence_summary — the app never recomputes the compensation
/// itself. "Lezioni da confermare" and "Registra presenza fuori
/// calendario" are principal-admin-only write actions; everyone with
/// section access sees the three cards and the read-only presence list.
/// Purely additive: touches only work_settings/work_rate_periods/
/// instructor_presences and, read-only, schedule_instances — nothing here
/// changes payments, bookings, subscriptions, receipts, the Registro di
/// Cassa, the Scadenzario or the documents archive.
class WorkAttendanceScreen extends StatefulWidget {
  const WorkAttendanceScreen({Key? key}) : super(key: key);

  @override
  State<WorkAttendanceScreen> createState() => _WorkAttendanceScreenState();
}

class _WorkAttendanceScreenState extends State<WorkAttendanceScreen> {
  final _service = WorkAttendanceService.instance;

  bool _isCheckingAccess = true;
  bool _canAccess = false;
  bool _isPrincipalAdmin = false;

  int _selectedYear = DateTime.now().year;

  bool _isLoadingSummary = true;
  String? _loadError;
  WorkCompensationSummary? _compensation;
  WorkPresenceSummary? _presenceSummary;
  WorkSettings? _settings;

  bool _isLoadingPendingLessons = true;
  List<WorkPendingLesson> _pendingLessons = [];

  bool _isLoadingPresences = true;
  List<WorkPresenceEntry> _presences = [];

  /// The 'buoni_pasto' asd_document_categories row, if reachable — null
  /// (RLS denial, missing category, or any load error) just hides the
  /// "Fatture e prospetti" button.
  AsdDocumentCategory? _buoniPastoCategory;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    bool canAccess;
    bool isPrincipal;
    try {
      canAccess =
          await AdminSectionVisibilityService.instance.canAccess('attendance_compensation');
    } catch (_) {
      canAccess = false;
    }
    try {
      isPrincipal = await AuthService.instance.isPrincipalAdmin();
    } catch (_) {
      isPrincipal = false;
    }
    if (!mounted) return;
    setState(() {
      _canAccess = canAccess;
      _isPrincipalAdmin = isPrincipal;
      _isCheckingAccess = false;
    });
    if (!canAccess) return;
    await _loadSettingsInfo();
    await _loadSummary();
    await _loadPresences();
    await _loadBuoniPastoCategory();
    if (isPrincipal) await _loadPendingLessons();
  }

  Future<void> _loadBuoniPastoCategory() async {
    try {
      final categories = await AsdDocumentsService.instance.getCategories();
      AsdDocumentCategory? found;
      for (final category in categories) {
        if (category.key == 'buoni_pasto') {
          found = category;
          break;
        }
      }
      if (!mounted) return;
      setState(() => _buoniPastoCategory = found);
    } catch (_) {
      // RLS denial, missing category, or any other error — just hide the
      // button (the archive screen itself decides who can actually see it).
      if (!mounted) return;
      setState(() => _buoniPastoCategory = null);
    }
  }

  Future<void> _loadSettingsInfo() async {
    try {
      final settings = await _service.getSettings();
      if (!mounted) return;
      setState(() => _settings = settings);
    } catch (_) {
      // Not critical — the km card just won't show vehicle/route/ACI link.
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _loadError = null;
    });
    try {
      final compensation = await _service.getCompensationSummary(_selectedYear);
      final presenceSummary = await _service.getPresenceSummary(_selectedYear);
      if (!mounted) return;
      setState(() {
        _compensation = compensation;
        _presenceSummary = presenceSummary;
        _isLoadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento del riepilogo: $e';
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _loadPendingLessons() async {
    setState(() => _isLoadingPendingLessons = true);
    try {
      final pending = await _service.getPendingLessons();
      if (!mounted) return;
      setState(() {
        _pendingLessons = pending;
        _isLoadingPendingLessons = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPendingLessons = false);
    }
  }

  Future<void> _loadPresences() async {
    setState(() => _isLoadingPresences = true);
    try {
      final presences = await _service.getPresences();
      if (!mounted) return;
      setState(() {
        _presences = presences;
        _isLoadingPresences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPresences = false);
    }
  }

  Future<void> _refreshAll() async {
    await _loadSummary();
    await _loadPresences();
    if (_isPrincipalAdmin) await _loadPendingLessons();
  }

  Future<void> _changeYear(int delta) async {
    setState(() => _selectedYear += delta);
    await _loadSummary();
  }

  Future<void> _answerLesson(WorkPendingLesson lesson, bool confirmed) async {
    try {
      if (confirmed) {
        await _service.confirmLesson(lesson);
      } else {
        await _service.declineLesson(lesson);
      }
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _openManualEntryDialog() async {
    var date = DateTime.now();
    var reason = kWorkPresenceReasonKeys.first;
    final notesController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registra presenza fuori calendario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data'),
                  subtitle: Text(DateFormat('dd/MM/yyyy', 'it_IT').format(date)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  items: kWorkPresenceReasonKeys
                      .map((key) => DropdownMenuItem(
                            value: key,
                            child: Text(workPresenceReasonLabel(key)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Note (facoltative)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await _service.addManualPresence(date: date, reason: reason, notes: notesController.text);
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  Future<void> _confirmDeletePresence(WorkPresenceEntry presence) async {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa presenza?'),
        content: Text(
          'Eliminare la presenza del ${dayFormat.format(presence.presenceDate)}? Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deletePresence(presence.id);
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkSettingsScreen(isPrincipalAdmin: _isPrincipalAdmin),
      ),
    );
    await _loadSettingsInfo();
    await _refreshAll();
  }

  Future<void> _openPdfPanel() async {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    var docType = WorkPdfDocType.compensation;
    var mode = _WorkPdfPeriodMode.month;
    var selectedMonth = previousMonth.month;
    final yearController = TextEditingController(text: '${previousMonth.year}');

    final result = await showModalBottomSheet<Map<String, Object>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Prospetti PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<WorkPdfDocType>(
                initialValue: docType,
                decoration: const InputDecoration(labelText: 'Tipo di documento'),
                items: WorkPdfDocType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(workPdfDocLabel(t))))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => docType = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_WorkPdfPeriodMode>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Periodo'),
                items: const [
                  DropdownMenuItem(value: _WorkPdfPeriodMode.month, child: Text('Mese')),
                  DropdownMenuItem(value: _WorkPdfPeriodMode.year, child: Text('Anno intero')),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => mode = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (mode == _WorkPdfPeriodMode.month) ...[
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedMonth,
                        decoration: const InputDecoration(labelText: 'Mese'),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(value: i + 1, child: Text(_kMonthNames[i])),
                        ),
                        onChanged: (value) {
                          if (value != null) setSheetState(() => selectedMonth = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: yearController,
                      decoration: const InputDecoration(labelText: 'Anno'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final year = int.tryParse(yearController.text.trim()) ?? previousMonth.year;
                    Navigator.pop(sheetContext, {
                      'docType': docType,
                      'mode': mode,
                      'month': selectedMonth,
                      'year': year,
                    });
                  },
                  child: const Text('Genera'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    final docType = result['docType'] as WorkPdfDocType;
    final mode = result['mode'] as _WorkPdfPeriodMode;
    final year = result['year'] as int;
    final month = result['month'] as int;
    final period =
        mode == _WorkPdfPeriodMode.year ? WorkPdfPeriod.year(year) : WorkPdfPeriod.month(year, month);
    await _generateAndPreviewPdf(docType, period);
  }

  Future<void> _generateAndPreviewPdf(WorkPdfDocType docType, WorkPdfPeriod period) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final instructorId = await _service.getInstructorUserId();
      if (instructorId == null) {
        throw Exception('Collaboratore non configurato in Impostazioni.');
      }
      final instructorName = await _service.getUserFullName(instructorId);

      late final Uint8List bytes;
      if (docType == WorkPdfDocType.compensation) {
        final summary = await _service.getCompensationSummary(period.year);
        final pdf = await buildWorkCompensationPdf(
          summary: summary,
          period: period,
          instructorName: instructorName,
        );
        bytes = await pdf.save();
      } else {
        final presenceDays = await _service.getConfirmedPresenceDays(
          userId: instructorId,
          start: period.start,
          end: period.end,
        );
        final settings = _settings ?? await _service.getSettings();
        WorkPresenceSummary? yearSummaryForCheck;
        if (period.isFullYear) {
          yearSummaryForCheck = await _service.getPresenceSummary(period.year);
        }
        final pdf = docType == WorkPdfDocType.mealVoucher
            ? await buildWorkMealVoucherPdf(
                presenceDays: presenceDays,
                voucherValue: settings.mealVoucherValue,
                period: period,
                instructorName: instructorName,
                yearSummaryForCheck: yearSummaryForCheck,
              )
            : await buildWorkKmPdf(
                presenceDays: presenceDays,
                settings: settings,
                period: period,
                instructorName: instructorName,
                yearSummaryForCheck: yearSummaryForCheck,
              );
        bytes = await pdf.save();
      }

      if (!mounted) return;
      Navigator.pop(context);

      final fileName = workPdfFileName(docType, period);
      final title = '${workPdfDocLabel(docType)} - ${period.label}';

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkPdfPreviewScreen(
            title: workPdfDocLabel(docType),
            bytes: bytes,
            fileName: fileName,
            onSaveToArchive: _isPrincipalAdmin
                ? () => _saveWorkPdfToArchive(
                      docType: docType,
                      bytes: bytes,
                      fileName: fileName,
                      title: title,
                      subject: instructorName,
                    )
                : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante la generazione del PDF: $e')),
      );
    }
  }

  Future<void> _saveWorkPdfToArchive({
    required WorkPdfDocType docType,
    required Uint8List bytes,
    required String fileName,
    required String title,
    required String subject,
  }) async {
    final documentsService = AsdDocumentsService.instance;
    final sanitizedFileName = documentsService.sanitizeFileName(fileName);
    final storagePath = documentsService.generatedStoragePath(
      deadlineId: null,
      fileName: documentsService.timestampedFileName(sanitizedFileName),
    );
    await documentsService.uploadBytes(storagePath, bytes, contentType: 'application/pdf');
    await documentsService.createDocument(
      title: title,
      storagePath: storagePath,
      category: workPdfArchiveCategory(docType),
      subject: subject,
      docDate: DateTime.now(),
      source: kAsdDocumentSourceGenerated,
      fileName: sanitizedFileName,
      mimeType: 'application/pdf',
    );
  }

  Future<void> _openAciTable(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Presenze e compensi')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Non hai accesso a questa sezione.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presenze e compensi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Prospetti PDF',
            onPressed: _openPdfPanel,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Impostazioni',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            4.w,
            2.h,
            4.w,
            MediaQuery.of(context).viewPadding.bottom + 88,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeYear(-1),
                ),
                Text(
                  '$_selectedYear',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeYear(1),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            if (_isLoadingSummary)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadSummary, child: const Text('Riprova')),
                    ],
                  ),
                ),
              )
            else ...[
              if (_compensation != null) _buildCompensationCard(_compensation!),
              SizedBox(height: 2.h),
              if (_presenceSummary != null) _buildMealVoucherCard(_presenceSummary!),
              SizedBox(height: 2.h),
              if (_presenceSummary != null) _buildKmCard(_presenceSummary!),
            ],
            if (_isPrincipalAdmin) ...[
              SizedBox(height: 2.h),
              _buildPendingLessonsSection(),
            ],
            SizedBox(height: 2.h),
            _buildPresencesSection(),
          ],
        ),
      ),
      floatingActionButton: _isPrincipalAdmin
          ? FloatingActionButton(
              onPressed: _openManualEntryDialog,
              tooltip: 'Registra presenza fuori calendario',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCompensationCard(WorkCompensationSummary summary) {
    final marginColor = summary.isOverLimitAtYearEnd ? Colors.red : Colors.green;
    final coversUntil = summary.calendarCoversUntil;
    final coversFullYear = coversUntil != null &&
        coversUntil.year == summary.year &&
        coversUntil.month == 12 &&
        coversUntil.day == 31;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined),
                SizedBox(width: 2.w),
                const Text('Compenso', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              '${_formatWholeEuro(summary.hourlyRate)}/h, ${summary.paidLessonsPerWeek} '
              '${summary.paidLessonsPerWeek == 1 ? 'lezione a settimana' : 'lezioni a settimana'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 1.5.h),
            Text('Percepito + maturato', style: Theme.of(context).textTheme.bodySmall),
            Text(
              _formatEuro(summary.totalToDate),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
            SizedBox(height: 1.h),
            Text('Ti restano ${_formatEuro(summary.remainingToLimitNow)} ai '
                '${_formatWholeEuro(summary.annualLimit)}'),
            SizedBox(height: 1.h),
            Text('Previsto a fine anno: ${_formatEuro(summary.projectedYearEnd)}'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: marginColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                summary.isOverLimitAtYearEnd
                    ? 'Superi i ${_formatWholeEuro(summary.annualLimit)}'
                    : 'Margine a fine anno: ${_formatEuro(summary.marginAtYearEnd)}',
                style: TextStyle(color: marginColor, fontWeight: FontWeight.w700),
              ),
            ),
            if (coversUntil != null && !coversFullYear) ...[
              SizedBox(height: 1.h),
              Text(
                'Il calendario copre fino al '
                '${DateFormat('dd/MM/yyyy', 'it_IT').format(coversUntil)}: i mesi dopo non '
                'sono ancora inclusi nella previsione',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (summary.monthly.isNotEmpty) ...[
              SizedBox(height: 2.h),
              const Divider(),
              const Text('Andamento mensile', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 1.h),
              ..._buildMonthlyRows(summary.monthly),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMonthlyRows(List<WorkMonthlyAmount> monthly) {
    var cumulative = 0.0;
    final rows = <Widget>[
      Row(
        children: const [
          Expanded(flex: 3, child: Text('Mese', style: TextStyle(fontWeight: FontWeight.w700))),
          Expanded(
            flex: 2,
            child: Text('Lezioni', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 3,
            child: Text('Importo', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 3,
            child: Text('Cumulato', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      const Divider(height: 12),
    ];
    for (final month in monthly) {
      cumulative += month.amount;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(_kMonthNames[month.month - 1])),
              Expanded(flex: 2, child: Text('${month.lessons}', textAlign: TextAlign.right)),
              Expanded(flex: 3, child: Text(_formatEuro(month.amount), textAlign: TextAlign.right)),
              Expanded(
                flex: 3,
                child: Text(
                  _formatEuro(cumulative),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildMealVoucherCard(WorkPresenceSummary summary) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_outlined),
                SizedBox(width: 2.w),
                const Text('Buoni pasto', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            SizedBox(height: 1.5.h),
            Text('${summary.days} giorni con presenza'),
            Text('Valore buono: ${_formatEuro(summary.voucherValue)}'),
            SizedBox(height: 1.h),
            Text(
              'Totale: ${_formatEuro(summary.voucherTotal)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (_buoniPastoCategory != null) ...[
              SizedBox(height: 1.h),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AsdCategoryDocumentsScreen(category: _buoniPastoCategory!),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Fatture e prospetti'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKmCard(WorkPresenceSummary summary) {
    final settings = _settings;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_outlined),
                SizedBox(width: 2.w),
                const Text('Rimborso km', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            SizedBox(height: 1.5.h),
            Text(
              '${summary.days} giorni, ${NumberFormat('#,##0.#', 'it_IT').format(summary.kmTotal)} km totali',
            ),
            Text('Tariffa: ${_formatEuro(summary.kmRate)}/km'),
            SizedBox(height: 1.h),
            Text(
              'Importo: ${_formatEuro(summary.kmAmount)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (settings?.vehicle != null && settings!.vehicle!.trim().isNotEmpty) ...[
              SizedBox(height: 1.h),
              Text('Veicolo: ${settings.vehicle}'),
            ],
            if (settings?.routeFrom != null &&
                settings!.routeFrom!.trim().isNotEmpty &&
                settings.routeTo != null &&
                settings.routeTo!.trim().isNotEmpty)
              Text('Tratta: ${settings.routeFrom} → ${settings.routeTo}'),
            if (settings?.aciUrl != null && settings!.aciUrl!.trim().isNotEmpty) ...[
              SizedBox(height: 1.h),
              OutlinedButton.icon(
                onPressed: () => _openAciTable(settings.aciUrl!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Tabella ACI'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingLessonsSection() {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return Card(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lezioni da confermare', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(height: 1.h),
            if (_isLoadingPendingLessons)
              const Center(child: CircularProgressIndicator())
            else if (_pendingLessons.isEmpty)
              const Text('Nessuna lezione da confermare.')
            else
              ..._pendingLessons.map((lesson) {
                final time = (lesson.startTime != null && lesson.startTime!.length >= 5)
                    ? lesson.startTime!.substring(0, 5)
                    : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lesson.discipline} · ${dayFormat.format(lesson.classDate)}'
                        '${time != null ? ' · $time' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text('Hai tenuto tu la lezione?'),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _answerLesson(lesson, true),
                            child: const Text('Sì'),
                          ),
                          TextButton(
                            onPressed: () => _answerLesson(lesson, false),
                            child: const Text('No'),
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPresencesSection() {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return Card(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Presenze registrate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            SizedBox(height: 1.h),
            if (_isLoadingPresences)
              const Center(child: CircularProgressIndicator())
            else if (_presences.isEmpty)
              const Text('Nessuna presenza registrata.')
            else
              ..._presences.map((presence) {
                final subtitleParts = <String>[
                  if (presence.reason != null) workPresenceReasonLabel(presence.reason!),
                  presence.source == 'manual' ? 'manuale' : 'da calendario',
                ];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dayFormat.format(presence.presenceDate)),
                  subtitle: Text(subtitleParts.join(' · ')),
                  trailing: _isPrincipalAdmin
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _confirmDeletePresence(presence),
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }
}
