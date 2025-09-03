import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/receipt_model.dart';

class ReceiptPreviewWidget extends StatelessWidget {
  final ItalianReceiptModel receipt;
  final VoidCallback onGeneratePdf;

  const ReceiptPreviewWidget({
    Key? key,
    required this.receipt,
    required this.onGeneratePdf,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.sp),
      child: Column(
        children: [
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onGeneratePdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Genera PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.sp),
                  ),
                ),
              ),
              SizedBox(width: 12.sp),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Add share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Funzione di condivisione in arrivo!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Condividi'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.sp),
                    side: BorderSide(color: Colors.red.shade600),
                    foregroundColor: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.sp),

          // Professional Receipt Preview Card
          Expanded(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.sp),
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.sp),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.sp),
                  color: Colors.white,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfessionalHeader(),
                      SizedBox(height: 24.sp),
                      _buildReceiptTitle(),
                      SizedBox(height: 20.sp),
                      _buildCustomerInfo(),
                      SizedBox(height: 20.sp),
                      _buildProfessionalReceiptTable(),
                      SizedBox(height: 20.sp),
                      _buildPaymentInfo(),
                      SizedBox(height: 20.sp),
                      _buildVatSummary(),
                      SizedBox(height: 24.sp),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalHeader() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade500],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12.sp),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Ragnarok Logo
          Container(
            width: 80.sp,
            height: 80.sp,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.sp),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.sp),
              child: Image.asset(
                'assets/images/152933-1756821415426.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'TEAM\nRAGNAROK',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 20.sp),

          // Organization info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.organizationInfo?.name ?? 'Team Ragnarok ASD',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6.sp),
                Text(
                  receipt.organizationInfo?.address ??
                      'via giulio bezzi 25, 48026 Russi - RA',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.white.withAlpha(230),
                  ),
                ),
                SizedBox(height: 4.sp),
                Text(
                  'C.F.: ${receipt.organizationInfo?.taxCode ?? '92100170395'}',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.white.withAlpha(230),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTitle() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.sp),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ricevuta Fiscale - ${receipt.receiptNumber.split('-').last} del ${receipt.formattedIssueDate}',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          if (receipt.validityEndDate != null) ...[
            SizedBox(height: 6.sp),
            Text(
              'Scadenza iscrizione: ${receipt.validityEndDate!.day.toString().padLeft(2, '0')}-${receipt.validityEndDate!.month.toString().padLeft(2, '0')}-${receipt.validityEndDate!.year}',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.sp),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.blue.shade600,
                size: 16.sp,
              ),
              SizedBox(width: 8.sp),
              Text(
                'Dati di fatturazione',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.sp),
          _buildInfoRow('DEST:', receipt.customerName),
          if (receipt.customerTaxCode != null) ...[
            SizedBox(height: 4.sp),
            _buildInfoRow('C.F.', receipt.customerTaxCode!),
          ],
          if (receipt.customerAddress != null) ...[
            SizedBox(height: 4.sp),
            _buildInfoRow('Indirizzo', receipt.customerAddress!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70.sp,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalReceiptTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.sp),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8.sp),
                topRight: Radius.circular(8.sp),
              ),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _buildProfessionalTableCell('Nome', isHeader: true),
                    _buildProfessionalTableCell('Quantità', isHeader: true),
                    _buildProfessionalTableCell('Prezzo unitario',
                        isHeader: true),
                    _buildProfessionalTableCell('Sconto', isHeader: true),
                    _buildProfessionalTableCell('Iva', isHeader: true),
                    _buildProfessionalTableCell('Importo', isHeader: true),
                  ],
                ),
              ],
            ),
          ),

          // Data row with alternating background
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8.sp),
                bottomRight: Radius.circular(8.sp),
              ),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    _buildProfessionalTableCell(
                        '${receipt.description}\n${receipt.formattedValidityPeriod}'),
                    _buildProfessionalTableCell(receipt.quantity.toString()),
                    _buildProfessionalTableCell(
                      '€${receipt.unitPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                    _buildProfessionalTableCell(
                      receipt.discountPercentage > 0
                          ? '${receipt.discountPercentage.toStringAsFixed(0)}%'
                          : '-',
                    ),
                    _buildProfessionalTableCell(
                      '${receipt.vatRate}% ${receipt.fiscalNotes?.contains('N2.2') == true ? 'N2.2' : ''}',
                    ),
                    _buildProfessionalTableCell(
                      '€${receipt.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                      isTotal: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalTableCell(String text,
      {bool isHeader = false, bool isTotal = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 12.sp),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: isHeader ? 11.sp : 10.sp,
          fontWeight: isHeader
              ? FontWeight.bold
              : (isTotal ? FontWeight.bold : FontWeight.normal),
          color: isHeader
              ? Colors.white
              : isTotal
                  ? Colors.red.shade700
                  : Colors.grey.shade800,
          height: 1.2,
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8.sp),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payment,
                color: Colors.green.shade600,
                size: 16.sp,
              ),
              SizedBox(width: 8.sp),
              Text(
                'METODO PAGAMENTO: ${receipt.paymentMethodText}',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          if (receipt.fiscalNotes != null) ...[
            SizedBox(height: 12.sp),
            Text(
              'NOTE FISCALI',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 4.sp),
            Text(
              receipt.fiscalNotes!,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVatSummary() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8.sp),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RIEPILOGO IVA',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          SizedBox(height: 12.sp),

          // IVA Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6.sp),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(vertical: 8.sp, horizontal: 12.sp),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6.sp),
                      topRight: Radius.circular(6.sp),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'IMPONIBILE',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'IMPOSTE',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        'IMPORTO',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 8.sp, horizontal: 12.sp),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${receipt.vatRate}%',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        '€${receipt.taxableAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        '€${receipt.vatAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.sp),

          // Total summary
          Container(
            padding: EdgeInsets.all(12.sp),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade500],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8.sp),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Imponibile €${receipt.taxableAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Totale IVA €${receipt.vatAmount.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.sp),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 8.sp),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6.sp),
                  ),
                  child: Text(
                    'TOTALE: €${receipt.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.sp),
      ),
      child: Center(
        child: Column(
          children: [
            Text(
              'Ricevuta Fiscale generata da APP Palestre',
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.sp),
            Text(
              'powered by Shaggy Owl S.r.l.s',
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
