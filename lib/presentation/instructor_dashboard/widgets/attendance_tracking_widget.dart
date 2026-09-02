import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this import
import '../../../constants/app_constants.dart';

class AttendanceTrackingWidget extends StatefulWidget {
  const AttendanceTrackingWidget({Key? key}) : super(key: key);

  @override
  State<AttendanceTrackingWidget> createState() =>
      _AttendanceTrackingWidgetState();
}

class _AttendanceTrackingWidgetState extends State<AttendanceTrackingWidget> {
  bool _isQuickCheckIn = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.blue, size: 5.w),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Presenze',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildAttendanceStats(),
          SizedBox(height: 2.h),
          _buildQuickCheckInToggle(),
          SizedBox(height: 2.h),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildAttendanceStats() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Oggi', '87%', Colors.green),
              _buildStatItem('Settimana', '92%', Colors.blue),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Mese', '89%', Colors.orange),
              _buildStatItem('Media', '91%', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String percentage, Color color) {
    return Column(
      children: [
        Text(
          percentage,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 8.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickCheckInToggle() {
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            _isQuickCheckIn ? Icons.face_retouching_natural : Icons.edit,
            color: Colors.red,
            size: 4.w,
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isQuickCheckIn ? 'Riconoscimento Foto' : 'Check-in Manuale',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isQuickCheckIn
                      ? 'Auto-riconoscimento attivo'
                      : 'Inserimento manuale',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 8.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isQuickCheckIn,
            onChanged: (value) => setState(() => _isQuickCheckIn = value),
            activeThumbColor: Colors.red,
            activeTrackColor: Colors.red.withAlpha(77),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openAttendanceScanner,
            icon: Icon(Icons.qr_code_scanner, size: 3.w),
            label: Text(
              'Scanner',
              style: GoogleFonts.inter(fontSize: 8.sp),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withAlpha(51),
              foregroundColor: Colors.blue,
              side: BorderSide(color: Colors.blue.withAlpha(128)),
              padding: EdgeInsets.symmetric(vertical: 1.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openManualEntry,
            icon: Icon(Icons.edit, size: 3.w),
            label: Text(
              'Manuale',
              style: GoogleFonts.inter(fontSize: 8.sp),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.withAlpha(51),
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green.withAlpha(128)),
              padding: EdgeInsets.symmetric(vertical: 1.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openAttendanceScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: 50.h,
        padding: EdgeInsets.all(6.w),
        child: Column(
          children: [
            Text(
              'Scanner Presenze',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.red, size: 15.w),
                      SizedBox(height: 2.h),
                      Text(
                        'Scanner QR Code o\nRiconoscimento Viso',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.close'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openManualEntry() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('instructor_dashboard_ui.manual_attendance'.tr()),
        backgroundColor: Colors.green,
      ),
    );
  }
}
