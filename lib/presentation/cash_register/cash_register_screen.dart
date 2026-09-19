import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';
import 'package:universal_html/html.dart' as html;

import '../../services/auth_service.dart';
import '../../services/cash_register_service.dart';
import './cash_register_pdf.dart';
import './widgets/add_outflow_sheet.dart';
import './widgets/opening_balance_dialog.dart';

/// Registro di Cassa (Fase 1): month selector + chronological "Prima Nota"
/// list (day, operation, entrata/uscita, running balance), month/current
/// cash totals, manual outflow entry with optional receipt photo, opening
/// balance editor and a monthly PDF export.
///
/// Purely additive: reads/writes only the cash_register_* tables/RPCs and
/// the private 'cash-receipts' bucket via CashRegisterService. Nothing here
/// touches payments, bookings, receipts, subscriptions, SumUp or Satispay.
class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({Key? key}) : super(key: key);

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  bool _isCheckingAccess = true;
  bool _isPrincipalAdmin = false;

  bool _isLoading = true;
  String? _loadError;

  DateTime _openingDate = DateTime.now();
  double _openingBalance = 0.0;
  double? _currentCashBalance;

  late DateTime _selectedMonth;
  CashRegisterMonthSummary? _monthSummary;
  bool _isLoadingMonth = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    final isPrincipal = await AuthService.instance.isPrincipalAdmin();
    if (!mounted) return;
    setState(() {
      _isPrincipalAdmin = isPrincipal;
      _isCheckingAccess = false;
    });
    if (isPrincipal) {
      await _loadAll();
    }
  }

  DateTime get _minMonth => DateTime(_openingDate.year, _openingDate.month, 1);

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await CashRegisterService.instance.sync();

      final settings = await CashRegisterService.instance.getSettings();
      final openingBalance = (settings['opening_balance'] as num).toDouble();
      final openingDate = DateTime.parse(settings['opening_date'] as String);

      final currentBalance = await CashRegisterService.instance.getCurrentCashBalance();

      var selectedMonth = _selectedMonth;
      final minMonth = DateTime(openingDate.year, openingDate.month, 1);
      if (selectedMonth.isBefore(minMonth)) {
        selectedMonth = minMonth;
      }

      final monthSummary = await CashRegisterService.instance.getMonthSummary(
        selectedMonth,
      );

      if (!mounted) return;
      setState(() {
        _openingBalance = openingBalance;
        _openingDate = openingDate;
        _currentCashBalance = currentBalance;
        _selectedMonth = selectedMonth;
        _monthSummary = monthSummary;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento del registro di cassa: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() {
      _isLoadingMonth = true;
      _selectedMonth = month;
    });
    try {
      final summary = await CashRegisterService.instance.getMonthSummary(month);
      if (!mounted) return;
      setState(() {
        _monthSummary = summary;
        _isLoadingMonth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMonth = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nel caricamento del mese: $e')),
      );
    }
  }

  void _goToPreviousMonth() {
    final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    if (prev.isBefore(_minMonth)) return;
    _loadMonth(prev);
  }

  void _goToNextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    _loadMonth(next);
  }

  Future<void> _openAddOutflowSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddOutflowSheet(),
    );
    if (added == true) {
      await _loadAll();
    }
  }

  Future<void> _openOpeningBalanceDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => OpeningBalanceDialog(
        currentBalance: _openingBalance,
        currentDate: _openingDate,
      ),
    );
    if (saved == true) {
      await _loadAll();
    }
  }

  Future<void> _confirmDeleteEntry(CashRegisterEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa uscita?'),
        content: Text(
          '${entry.description}\n${formatEuro(-entry.amount)}\n\nQuesta azione non può essere annullata.',
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
      await CashRegisterService.instance.deleteOutflow(entry.id);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
      );
    }
  }

  Future<void> _viewReceiptPhoto(CashRegisterEntry entry) async {
    if (entry.photoPath == null) return;
    try {
      final url = await CashRegisterService.instance.getReceiptPhotoUrl(
        entry.photoPath!,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire la foto: $e')),
      );
    }
  }

  Future<void> _exportMonthPdf() async {
    final summary = _monthSummary;
    if (summary == null) return;
    try {
      final pdf = await buildCashRegisterMonthPdf(summary);
      final bytes = await pdf.save();
      final monthTag = DateFormat('yyyy-MM').format(summary.month);
      final filename = 'registro-cassa-$monthTag.pdf';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = filename;
        html.document.body?.append(anchor);
        anchor.click();
        anchor.remove();
        Future.delayed(const Duration(milliseconds: 100), () {
          html.Url.revokeObjectUrl(url);
        });
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'esportazione PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isPrincipalAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registro di Cassa')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Accesso riservato all\'amministratore principale.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro di Cassa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Esporta PDF del mese',
            onPressed: _monthSummary == null ? null : _exportMonthPdf,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Saldo iniziale',
            onPressed: _openOpeningBalanceDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAll,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: EdgeInsets.all(4.w),
                    children: [
                      _buildSummaryCard(),
                      SizedBox(height: 2.h),
                      _buildMonthSelector(),
                      SizedBox(height: 1.h),
                      _buildEntriesList(),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddOutflowSheet,
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text('Uscita'),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _monthSummary;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow(
              'Entrate del mese',
              summary == null ? '-' : formatEuro(summary.totalEntrate),
              color: Colors.green,
            ),
            _summaryRow(
              'Uscite del mese',
              summary == null ? '-' : formatEuro(summary.totalUscite),
              color: Colors.red,
            ),
            _summaryRow(
              'Saldo a fine mese',
              summary == null ? '-' : formatEuro(summary.balanceAtMonthEnd),
              color: (summary?.balanceAtMonthEnd ?? 0) < 0 ? Colors.red : null,
              bold: true,
            ),
            const Divider(height: 24),
            _summaryRow(
              'Saldo di cassa attuale',
              _currentCashBalance == null ? '-' : formatEuro(_currentCashBalance!),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final monthLabel = _capitalize(
      DateFormat('MMMM yyyy', 'it_IT').format(_selectedMonth),
    );
    final isAtMinMonth = !_selectedMonth.isAfter(_minMonth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: isAtMinMonth || _isLoadingMonth ? null : _goToPreviousMonth,
        ),
        Text(
          monthLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _isLoadingMonth ? null : _goToNextMonth,
        ),
      ],
    );
  }

  Widget _buildEntriesList() {
    if (_isLoadingMonth) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _monthSummary;
    final entries = summary?.entries ?? const [];

    if (entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Center(
          child: Text(
            'Nessun movimento in questo mese.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final dayFormat = DateFormat('dd/MM', 'it_IT');

    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final balance = summary!.progressiveBalances[index];
        final amountColor = entry.isEntrata ? Colors.green : Colors.red;
        final amountText =
            '${entry.isEntrata ? '+' : '-'}${formatEuro(entry.amount)}';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            onTap: entry.photoPath != null ? () => _viewReceiptPhoto(entry) : null,
            leading: CircleAvatar(
              backgroundColor: amountColor.withValues(alpha: 0.15),
              child: Text(
                dayFormat.format(entry.entryDate),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ),
            title: Text(entry.description),
            subtitle: Text(
              [
                if (entry.customerName != null && entry.customerName!.isNotEmpty)
                  entry.customerName!,
                if (entry.receiptNumber != null && entry.receiptNumber!.isNotEmpty)
                  'ricevuta ${entry.receiptNumber}',
                'saldo progressivo: ${formatEuro(balance)}',
              ].join(' · '),
              style: TextStyle(
                color: balance < 0 ? Colors.red : null,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.photoPath != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.photo_outlined, size: 18),
                  ),
                Text(
                  amountText,
                  style: TextStyle(color: amountColor, fontWeight: FontWeight.w700),
                ),
                if (entry.isManual)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDeleteEntry(entry),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
