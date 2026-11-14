import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../services/work_attendance_service.dart';
import '../work_pdfs.dart';

/// Quale dei due elenchi mostrare: buoni pasto o rimborso chilometrico.
enum WorkMonthlyKind { mealVoucher, km }

const List<String> _kMonths = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

String _euro(num value) => '€ ${NumberFormat('#,##0.00', 'it_IT').format(value)}';

/// Elenco MESE PER MESE di buoni pasto (giorni e importo) o di rimborso km
/// (viaggi, km e importo), con il prospetto PDF di ogni mese. I numeri
/// arrivano da `work_presence_monthly`; il PDF è lo stesso già usato in
/// "Presenze e compensi" ([onGeneratePdf]).
class WorkMonthlyScreen extends StatefulWidget {
  const WorkMonthlyScreen({
    super.key,
    required this.kind,
    required this.initialYear,
    required this.onGeneratePdf,
  });

  final WorkMonthlyKind kind;
  final int initialYear;
  final Future<void> Function(WorkPdfDocType docType, WorkPdfPeriod period) onGeneratePdf;

  @override
  State<WorkMonthlyScreen> createState() => _WorkMonthlyScreenState();
}

class _WorkMonthlyScreenState extends State<WorkMonthlyScreen> {
  late int _year = widget.initialYear;
  bool _loading = true;
  String? _error;
  List<WorkMonthPresence> _months = [];

  bool get _isMeal => widget.kind == WorkMonthlyKind.mealVoucher;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final months = await WorkAttendanceService.instance.getPresenceMonthly(_year);
      if (!mounted) return;
      setState(() {
        _months = months.reversed.toList(); // dal più recente
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore nel caricamento: $e';
        _loading = false;
      });
    }
  }

  void _changeYear(int delta) {
    _year += delta;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalAmount = _months.fold<double>(
        0, (sum, m) => sum + (_isMeal ? m.voucherTotal : m.kmAmount));
    return Scaffold(
      appBar: AppBar(title: Text(_isMeal ? 'Buoni pasto mese per mese' : 'Rimborso km mese per mese')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeYear(-1),
                ),
                Column(
                  children: [
                    Text('$_year', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    if (!_loading && _error == null)
                      Text('Totale anno: ${_euro(totalAmount)}'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _year >= now.year ? null : () => _changeYear(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(4.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _load, child: const Text('Riprova')),
                            ],
                          ),
                        ),
                      )
                    : _months.isEmpty
                        ? const Center(child: Text('Nessuna presenza in questo anno'))
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                            itemCount: _months.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) => _buildRow(_months[index], now),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(WorkMonthPresence m, DateTime now) {
    final isCurrent = _year == now.year && m.month == now.month;
    final amount = _isMeal ? m.voucherTotal : m.kmAmount;
    final detail = _isMeal
        ? '${m.days} ${m.days == 1 ? 'buono' : 'buoni'} (${m.days} ${m.days == 1 ? 'giorno' : 'giorni'} con presenza)'
        : '${m.days} ${m.days == 1 ? 'giorno' : 'giorni'}'
            '${m.trips != m.days ? ', ${m.trips} viaggi' : ''}, '
            '${NumberFormat('#,##0.#', 'it_IT').format(m.kmTotal)} km';
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrent ? '${_kMonths[m.month - 1]} (in corso)' : _kMonths[m.month - 1],
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(detail),
                ],
              ),
            ),
            Text(_euro(amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            IconButton(
              tooltip: 'Prospetto PDF del mese',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => widget.onGeneratePdf(
                _isMeal ? WorkPdfDocType.mealVoucher : WorkPdfDocType.km,
                WorkPdfPeriod.month(_year, m.month),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
