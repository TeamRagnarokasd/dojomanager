import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../services/italian_receipt_service.dart';
import '../../theme/app_theme.dart';

/// "Entrate mensili": solo elenco mese/anno + totale in euro, nessun
/// dettaglio né grafico. Aperta toccando la card "Entrate Mese" nella
/// dashboard admin. Dati dalla RPC get_monthly_revenue_totals (verifica
/// già i permessi admin lato database).
class MonthlyRevenueScreen extends StatefulWidget {
  const MonthlyRevenueScreen({Key? key}) : super(key: key);

  @override
  State<MonthlyRevenueScreen> createState() => _MonthlyRevenueScreenState();
}

class _MonthlyRevenueScreenState extends State<MonthlyRevenueScreen> {
  final _service = ItalianReceiptService();

  bool _isLoading = true;
  String? _loadError;
  List<Map<String, dynamic>> _months = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final months = await _service.getMonthlyRevenueTotals(monthsBack: 12);
      if (!mounted) return;
      setState(() {
        _months = months;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Impossibile caricare le entrate mensili.';
        _isLoading = false;
      });
    }
  }

  String _monthLabel(DateTime date) {
    final label = DateFormat('MMMM yyyy', 'it_IT').format(date);
    return label[0].toUpperCase() + label.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Entrate mensili',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0000)))
          : _loadError != null
              ? Center(
                  child: Text(
                    _loadError!,
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFFF0000),
                  backgroundColor: const Color(0xFF1E1E1E),
                  child: _months.isEmpty
                      ? ListView(
                          padding: EdgeInsets.all(4.w),
                          children: [
                            SizedBox(height: 10.h),
                            Center(
                              child: Text(
                                'Nessuna entrata registrata.',
                                style: GoogleFonts.inter(color: Colors.white70),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: EdgeInsets.all(4.w),
                          itemCount: _months.length,
                          separatorBuilder: (_, __) => SizedBox(height: 1.5.h),
                          itemBuilder: (context, index) {
                            final row = _months[index];
                            final monthStart =
                                DateTime.tryParse(row['month_start'].toString());
                            final total =
                                (row['total'] as num?)?.toDouble() ?? 0.0;
                            final receiptsCount =
                                (row['receipts_count'] as num?)?.toInt() ?? 0;
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[800]!),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    monthStart != null
                                        ? _monthLabel(monthStart)
                                        : row['month_start'].toString(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '€${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFF0000),
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
