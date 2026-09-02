import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class AvailabilityIndicatorWidget extends StatelessWidget {
  final int capacity;
  final int booked;

  const AvailabilityIndicatorWidget({
    Key? key,
    required this.capacity,
    required this.booked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final available = capacity - booked;
    final percentage = (booked / capacity) * 100;

    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disponibilità',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'class_schedule.available_spots'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                    Text(
                      '$available di $capacity',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: available > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _getAvailabilityColor(percentage),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getAvailabilityText(percentage),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getAvailabilityColor(percentage),
            ),
            minHeight: 8.h,
          ),
        ],
      ),
    );
  }

  Color _getAvailabilityColor(double percentage) {
    if (percentage >= 90) return Colors.red;
    if (percentage >= 75) return Colors.orange;
    if (percentage >= 50) return Colors.yellow[700]!;
    return Colors.green;
  }

  String _getAvailabilityText(double percentage) {
    if (percentage >= 90) return 'Quasi pieno';
    if (percentage >= 75) return 'Pochi posti';
    if (percentage >= 50) return 'Disponibile';
    return 'Molti posti';
  }
}
