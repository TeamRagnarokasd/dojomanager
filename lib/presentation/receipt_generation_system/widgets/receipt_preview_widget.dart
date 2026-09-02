import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/receipt_model.dart';
import '../../../core/app_export.dart';

class ReceiptPreviewWidget extends StatelessWidget {
  final ReceiptModel receipt;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onEmail;

  const ReceiptPreviewWidget({
    Key? key,
    required this.receipt,
    required this.onPrint,
    required this.onShare,
    required this.onEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.green.shade700,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ricevuta Generata',
                        style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'N. ${receipt.receiptNumber} - ${DateFormat('dd/MM/yyyy').format(receipt.issueDate)}',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'COMPLETATA',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Receipt preview content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company header
                  _buildCompanyHeader(),

                  SizedBox(height: 24.h),

                  // Client details
                  _buildClientDetails(),

                  SizedBox(height: 24.h),

                  // Receipt details
                  _buildReceiptDetails(),

                  SizedBox(height: 24.h),

                  // Payment summary
                  _buildPaymentSummary(),

                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Stampa',
                    Icons.print,
                    Colors.blue,
                    onPrint,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildActionButton(
                    'PDF',
                    Icons.picture_as_pdf,
                    Colors.orange,
                    onShare,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildActionButton(
                    'common.email'.tr(),
                    Icons.email,
                    Colors.green,
                    onEmail,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.h,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.sports_martial_arts,
              color: Colors.red.shade700,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.gym?.name ?? 'TEAM RAGNAROK ASD',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  receipt.gym?.address ?? 'Via Giulio Bezzi 25, 48026 Russi-RA',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'CF: ${receipt.gym?.taxCode ?? '92100170395'}',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientDetails() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESTINATARIO',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            receipt.user?.fullName ?? '',
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (receipt.validityEnd != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 6.h,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Scadenza: ${DateFormat('dd-MM-yyyy').format(receipt.validityEnd!)}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETTAGLI RICEVUTA',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                ),
                children: [
                  _buildTableCell('DESCRIZIONE', isHeader: true),
                  _buildTableCell('QTÀ', isHeader: true),
                  _buildTableCell('PREZZO', isHeader: true),
                  _buildTableCell('IMPORTO', isHeader: true),
                ],
              ),
              // Data
              TableRow(
                children: [
                  _buildTableCell(receipt.description),
                  _buildTableCell(receipt.quantity.toString()),
                  _buildTableCell(
                      '€${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}'),
                  _buildTableCell(
                      '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'METODO PAGAMENTO:',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
              Text(
                _getPaymentMethodText(receipt.paymentMethod),
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Divider(color: Colors.green.shade300),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RIEPILOGO IVA',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Imponibile:',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.green.shade700,
                ),
              ),
              Text(
                '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'IVA ${receipt.vatRate.toStringAsFixed(2)}%:',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.green.shade700,
                ),
              ),
              Text(
                '€0,00',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Divider(color: Colors.green.shade300),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTALE:',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
              Text(
                '€${receipt.totalAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: EdgeInsets.all(12.w),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          color: isHeader ? Colors.grey.shade800 : Colors.grey.shade700,
        ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color.shade700,
              size: 24.sp,
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'sumup':
        return 'SumUp';
      case 'satispay':
        return 'payment.satispay'.tr();
      case 'cash':
        return 'payment.cash'.tr();
      case 'bank_transfer':
        return 'payment.bank_transfer'.tr();
      default:
        return method;
    }
  }
}
