import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class CancellationPolicyWidget extends StatelessWidget {
  const CancellationPolicyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              SizedBox(width: 8.w),
              Text(
                'Politica di Cancellazione',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '• Cancellazione gratuita fino a 24 ore prima della lezione\n'
            '• Cancellazione tardiva: rimborso del 50%\n'
            '• Nessun rimborso per cancellazioni il giorno stesso',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.orange[800],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
