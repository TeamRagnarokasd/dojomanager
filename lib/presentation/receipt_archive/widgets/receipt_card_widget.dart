import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/receipt_model.dart';

class ReceiptCardWidget extends StatelessWidget {
  final ReceiptModel receipt;
  final bool isSelected;
  final bool bulkMode;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;
  final VoidCallback onViewPdf;
  final VoidCallback onSendEmail;
  final VoidCallback onDuplicate;

  const ReceiptCardWidget({
    Key? key,
    required this.receipt,
    required this.isSelected,
    required this.bulkMode,
    required this.onTap,
    required this.onToggleSelect,
    required this.onViewPdf,
    required this.onSendEmail,
    required this.onDuplicate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('receipt_${receipt.id}'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(true),
      secondaryBackground: _buildSwipeBackground(false),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onViewPdf();
        } else {
          onSendEmail();
        }
      },
      child: Card(
        elevation: 2,
        margin: EdgeInsets.only(bottom: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: Colors.blue.shade300, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSelected ? Colors.blue.shade50 : Colors.white,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    if (bulkMode) ...[
                      InkWell(
                        onTap: onToggleSelect,
                        child: Container(
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
                              ? Icon(Icons.check,
                                  color: Colors.white, size: 16.sp)
                              : null,
                        ),
                      ),
                      SizedBox(width: 16.w),
                    ],

                    // Receipt number and status
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: _getStatusColor().shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'N. ${receipt.receiptNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor().shade800,
                        ),
                      ),
                    ),

                    SizedBox(width: 12.w),

                    // Payment method indicator
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _getPaymentMethodColor().shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getPaymentMethodText(),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: _getPaymentMethodColor().shade800,
                        ),
                      ),
                    ),

                    Spacer(),

                    // Issue date
                    Text(
                      DateFormat('dd/MM/yyyy').format(receipt.issueDate),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    // Client avatar and info
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      radius: 20.0,
                      child: Text(
                        (receipt.user?.fullName ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receipt.user?.fullName ?? 'Cliente sconosciuto',
                            style: GoogleFonts.inter(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            receipt.description,
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (receipt.validityEnd != null) ...[
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14.sp,
                                  color: _isExpiringSoon()
                                      ? Colors.orange.shade600
                                      : Colors.grey.shade500,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Scade: ${DateFormat('dd/MM/yyyy').format(receipt.validityEnd!)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: _isExpiringSoon()
                                        ? Colors.orange.shade600
                                        : Colors.grey.shade500,
                                    fontWeight: _isExpiringSoon()
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: GoogleFonts.inter(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade600,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'IVA ${receipt.vatRate.toStringAsFixed(2)}%',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),

                    if (!bulkMode) ...[
                      SizedBox(width: 12.w),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey.shade600,
                          size: 20.sp,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'pdf':
                              onViewPdf();
                              break;
                            case 'email':
                              onSendEmail();
                              break;
                            case 'duplicate':
                              onDuplicate();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'pdf',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf,
                                    color: Colors.red.shade600, size: 18.sp),
                                SizedBox(width: 12.w),
                                Text(
                                  'Visualizza PDF',
                                  style: GoogleFonts.inter(fontSize: 14.sp),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'email',
                            child: Row(
                              children: [
                                Icon(Icons.email,
                                    color: Colors.blue.shade600, size: 18.sp),
                                SizedBox(width: 12.w),
                                Text(
                                  'Invia Email',
                                  style: GoogleFonts.inter(fontSize: 14.sp),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(Icons.content_copy,
                                    color: Colors.green.shade600, size: 18.sp),
                                SizedBox(width: 12.w),
                                Text(
                                  'Duplica Ricevuta',
                                  style: GoogleFonts.inter(fontSize: 14.sp),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(bool isLeft) {
    final color = isLeft ? Colors.blue : Colors.green;
    final icon = isLeft ? Icons.picture_as_pdf : Icons.email;
    final text = isLeft ? 'PDF' : 'Email';

    return Container(
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color.shade700,
            size: 24.sp,
          ),
          SizedBox(height: 4.h),
          Text(
            text,
            style: GoogleFonts.inter(
              color: color.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  MaterialColor _getStatusColor() {
    switch (receipt.status.toLowerCase()) {
      case 'issued':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  MaterialColor _getPaymentMethodColor() {
    switch (receipt.paymentMethod.toLowerCase()) {
      case 'sumup':
        return Colors.blue;
      case 'satispay':
        return Colors.orange;
      case 'cash':
        return Colors.green;
      case 'bank_transfer':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentMethodText() {
    switch (receipt.paymentMethod.toLowerCase()) {
      case 'sumup':
        return 'SumUp';
      case 'satispay':
        return 'Satispay';
      case 'cash':
        return 'Contanti';
      case 'bank_transfer':
        return 'Bonifico';
      default:
        return receipt.paymentMethod;
    }
  }

  bool _isExpiringSoon() {
    if (receipt.validityEnd == null) return false;

    final now = DateTime.now();
    final daysUntilExpiration = receipt.validityEnd!.difference(now).inDays;

    return daysUntilExpiration <= 7 && daysUntilExpiration >= 0;
  }
}