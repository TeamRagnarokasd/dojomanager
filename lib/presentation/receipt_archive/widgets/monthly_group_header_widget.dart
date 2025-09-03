import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';


class MonthlyGroupHeaderWidget extends StatelessWidget {
  final String monthKey;
  final int receiptCount;
  final double totalAmount;

  const MonthlyGroupHeaderWidget({
    Key? key,
    required this.monthKey,
    required this.receiptCount,
    required this.totalAmount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse('$monthKey-01');
    final monthName = _getItalianMonthName(date.month);
    final year = date.year;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.calendar_month,
              color: Colors.blue.shade700,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$monthName $year',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '$receiptCount ${receiptCount == 1 ? 'ricevuta' : 'ricevute'}',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '€${totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade600,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Totale mese',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getItalianMonthName(int month) {
    const months = [
      '',
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    return months[month];
  }
}