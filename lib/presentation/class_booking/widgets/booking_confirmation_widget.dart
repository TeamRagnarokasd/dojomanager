import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class BookingConfirmationWidget extends StatelessWidget {
  final String bookingId;
  final String qrCode;
  final Map<String, dynamic> classData;
  final VoidCallback onDone;

  const BookingConfirmationWidget({
    Key? key,
    required this.bookingId,
    required this.qrCode,
    required this.classData,
    required this.onDone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.sp),
      child: Column(
        children: [
          // Success Icon
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 60.w, color: Colors.green),
          ),
          SizedBox(height: 24.h),

          // Success Message
          Text(
            'Prenotazione Confermata!',
            style: GoogleFonts.inter(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'La tua prenotazione è stata registrata con successo',
            style: GoogleFonts.inter(fontSize: 16.sp, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),

          // Booking Details
          Container(
            padding: EdgeInsets.all(20.sp),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              children: [
                Text(
                  'Dettagli Prenotazione',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16.h),
                _buildDetailRow('ID Prenotazione', bookingId),
                _buildDetailRow('Disciplina', classData['discipline']),
                _buildDetailRow('Data', classData['date']),
                _buildDetailRow('Orario', classData['time']),
                _buildDetailRow('Istruttore', classData['instructor']['name']),
                _buildDetailRow(
                  'Prezzo',
                  '€${classData['price'].toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // QR Code Placeholder
          Container(
            width: 200.w,
            height: 200.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code, size: 80.w, color: Colors.grey[600]),
                SizedBox(height: 8.h),
                Text(
                  'QR Code',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  qrCode,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          // Done Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Fatto',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey[400],
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
