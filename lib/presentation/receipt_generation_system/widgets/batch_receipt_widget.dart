import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';


class BatchReceiptWidget extends StatefulWidget {
  final List<Map<String, dynamic>> userProfiles;
  final Function(List<Map<String, dynamic>>) onGenerate;

  const BatchReceiptWidget({
    Key? key,
    required this.userProfiles,
    required this.onGenerate,
  });

  @override
  State<BatchReceiptWidget> createState() => _BatchReceiptWidgetState();
}

class _BatchReceiptWidgetState extends State<BatchReceiptWidget> {
  final Set<String> _selectedUsers = <String>{};
  bool _selectAll = false;

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      if (_selectAll) {
        _selectedUsers
            .addAll(widget.userProfiles.map((user) => user['id'] as String));
      } else {
        _selectedUsers.clear();
      }
    });
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUsers.contains(userId)) {
        _selectedUsers.remove(userId);
        _selectAll = false;
      } else {
        _selectedUsers.add(userId);
        if (_selectedUsers.length == widget.userProfiles.length) {
          _selectAll = true;
        }
      }
    });
  }

  void _generateBatchReceipts() {
    if (_selectedUsers.isEmpty) {
      Fluttertoast.showToast(
        msg: "Seleziona almeno un utente",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    final selectedUserProfiles = widget.userProfiles
        .where((user) => _selectedUsers.contains(user['id']))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.batch_prediction, color: Colors.blue.shade700),
            SizedBox(width: 12.w),
            Text(
              'Conferma Generazione',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generare ${_selectedUsers.length} ricevute mensili con:',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card,
                          color: Colors.blue.shade700, size: 16.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Pagamento: SumUp',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: Colors.blue.shade700, size: 16.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Tipo: Abbonamento Mensile',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(Icons.euro,
                          color: Colors.blue.shade700, size: 16.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Importo: €30,00 per ricevuta',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Totale: €${(_selectedUsers.length * 30).toStringAsFixed(2).replaceAll('.', ',')}',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onGenerate(selectedUserProfiles);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Genera Ricevute',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Batch header
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.blue.shade200),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.batch_prediction, color: Colors.blue.shade700),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Generazione Batch Ricevute',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          Text(
                            'Seleziona utenti per generazione multipla',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_selectedUsers.length}/${widget.userProfiles.length}',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _toggleSelectAll,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectAll
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: Colors.blue.shade700,
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                _selectAll
                                    ? 'Deseleziona Tutti'
                                    : 'Seleziona Tutti',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton(
                      onPressed: _selectedUsers.isNotEmpty
                          ? _generateBatchReceipts
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            vertical: 12.h, horizontal: 20.w),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, size: 16.sp),
                          SizedBox(width: 6.w),
                          Text(
                            'Genera',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: widget.userProfiles.length,
              itemBuilder: (context, index) {
                final user = widget.userProfiles[index];
                final isSelected = _selectedUsers.contains(user['id']);

                return Card(
                  elevation: 1,
                  margin: EdgeInsets.only(bottom: 8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.blue.shade300
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _toggleUser(user['id']),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Container(
                            width: 24.w,
                            height: 24.h,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade600
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16.sp,
                                  )
                                : null,
                          ),
                          SizedBox(width: 16.w),
                          CircleAvatar(
                            backgroundColor: isSelected
                                ? Colors.blue.shade100
                                : Colors.grey.shade100,
                            child: Text(
                              user['full_name'][0].toUpperCase(),
                              style: GoogleFonts.inter(
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['full_name'],
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                    color: isSelected
                                        ? Colors.blue.shade900
                                        : Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  user['email'],
                                  style: GoogleFonts.inter(
                                    color: Colors.grey.shade600,
                                    fontSize: 12.sp,
                                  ),
                                ),
                                if (user['tax_code'] != null) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    'CF: ${user['tax_code']}',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade500,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '€30,00',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}