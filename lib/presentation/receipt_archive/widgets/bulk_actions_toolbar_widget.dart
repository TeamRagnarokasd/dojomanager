import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class BulkActionsToolbarWidget extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkEmail;
  final VoidCallback onBulkExport;

  const BulkActionsToolbarWidget({
    Key? key,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onBulkEmail,
    required this.onBulkExport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: Colors.blue.shade50,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle,
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
                  '$selectedCount selezionate',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
                Text(
                  'Azioni disponibili per le ricevute selezionate',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Row(
            children: [
              _buildActionButton(
                'Tutto',
                Icons.select_all,
                Colors.grey,
                onSelectAll,
              ),
              SizedBox(width: 6.w),
              _buildActionButton(
                'Email',
                Icons.email,
                Colors.green,
                onBulkEmail,
              ),
              SizedBox(width: 6.w),
              _buildActionButton(
                'PDF',
                Icons.picture_as_pdf,
                Colors.red,
                onBulkExport,
              ),
              SizedBox(width: 6.w),
              _buildActionButton(
                'Annulla',
                Icons.close,
                Colors.orange,
                onClearSelection,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    MaterialColor color,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color.shade700,
              size: 16.sp,
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: color.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}