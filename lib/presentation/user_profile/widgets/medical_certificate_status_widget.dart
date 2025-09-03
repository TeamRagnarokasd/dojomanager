import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';
import '../../../core/app_export.dart';
import '../../../routes/app_routes.dart';

class MedicalCertificateStatusWidget extends StatelessWidget {
  const MedicalCertificateStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime expirationDate = DateTime.now().add(Duration(days: 45));
    bool isExpiringSoon = expirationDate.difference(DateTime.now()).inDays < 60;

    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
            color: isExpiringSoon
                ? Colors.orange.withAlpha(128)
                : Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Certificato Medico',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                isExpiringSoon ? Icons.warning : Icons.verified,
                color: isExpiringSoon ? Colors.orange : Colors.green,
                size: 6.w,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: isExpiringSoon
                  ? Colors.orange.withAlpha(26)
                  : Colors.green.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isExpiringSoon
                    ? Colors.orange.withAlpha(77)
                    : Colors.green.withAlpha(77),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: isExpiringSoon ? Colors.orange : Colors.green,
                      size: 4.w,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Scadenza: ${_formatDate(expirationDate)}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  isExpiringSoon
                      ? 'Attenzione: Il certificato scade tra ${expirationDate.difference(DateTime.now()).inDays} giorni'
                      : 'Certificato valido e aggiornato',
                  style: GoogleFonts.inter(
                    color: isExpiringSoon ? Colors.orange : Colors.green,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                        context, AppRoutes.medicalCertificateUpload);
                  },
                  icon: Icon(Icons.upload_file, size: 4.w),
                  label: Text(
                    isExpiringSoon ? 'Rinnova' : 'Aggiorna',
                    style: GoogleFonts.inter(fontSize: 11.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isExpiringSoon ? Colors.orange : Colors.red,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () =>
                      _showCertificateDetails(context, expirationDate),
                  icon: Icon(Icons.info_outline, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showCertificateDetails(BuildContext context, DateTime expirationDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'Dettagli Certificato',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tipo:', 'Certificato Medico Sportivo'),
            _buildDetailRow('Emesso da:', 'Dr. Giovanni Bianchi'),
            _buildDetailRow('Data emissione:', '15/08/2024'),
            _buildDetailRow('Scadenza:', _formatDate(expirationDate)),
            _buildDetailRow('Stato:', 'Valido'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Chiudi',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}