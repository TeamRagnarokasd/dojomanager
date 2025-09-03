import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';


class BulkApprovalWidget extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onBulkApprove;
  final VoidCallback onClearSelection;

  const BulkApprovalWidget({
    super.key,
    required this.selectedCount,
    required this.onBulkApprove,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: double.infinity,
      color: Colors.green.withAlpha(230),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              Icons.approval,
              color: Colors.white,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approvazione Multipla',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
                Text(
                  '$selectedCount registrazioni selezionate per approvazione',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(204),
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClearSelection,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(51),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.clear,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Annulla',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showBulkApprovalConfirmation(context),
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.done_all,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Approva Tutto',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBulkApprovalConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.approval, color: Colors.green, size: 24.sp),
            SizedBox(width: 8.w),
            Text(
              'Conferma Approvazione Multipla',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stai per approvare $selectedCount registrazioni contemporaneamente.',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Azioni automatiche che verranno eseguite:',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                      color: Colors.green.shade800,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  ...[
                    '• Creazione account utente automatica',
                    '• Invio email di benvenuto personalizzata',
                    '• Assegnazione ruolo richiesto',
                    '• Notifica amministratori completamento',
                    '• Archiviazione documenti verificati',
                  ].map((item) => Padding(
                        padding: EdgeInsets.only(bottom: 2.h),
                        child: Text(
                          item,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: Colors.green.shade700,
                          ),
                        ),
                      )),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16.sp),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Questa azione non può essere annullata.',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: Colors.blue.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onBulkApprove();
            },
            icon: Icon(Icons.done_all, size: 16.sp),
            label: Text('Conferma Approvazione'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
