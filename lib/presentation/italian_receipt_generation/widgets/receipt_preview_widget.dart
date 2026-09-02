import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/receipt_model.dart';
import '../../../core/app_export.dart';

class ReceiptPreviewWidget extends StatelessWidget {
  final ItalianReceiptModel receipt;
  final VoidCallback onGeneratePdf;

  const ReceiptPreviewWidget({
    Key? key,
    required this.receipt,
    required this.onGeneratePdf,
  }) : super(key: key);

  String _fmt(double v) => '€${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Action buttons ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onGeneratePdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text('italian_receipt.generate_pdf'.tr(),
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('receipt.share_coming_soon'.tr())),
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: Text('italian_receipt.share'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Colors.red.shade600),
                    foregroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Receipt card ────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              color: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 14),
                    _buildReceiptTitle(),
                    const SizedBox(height: 12),
                    _buildCustomerInfo(),
                    const SizedBox(height: 12),
                    _buildItemDetail(),
                    const SizedBox(height: 12),
                    _buildPaymentInfo(),
                    const SizedBox(height: 12),
                    _buildVatAndTotal(),
                    const SizedBox(height: 14),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade500],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/152933-1756821415426.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'TR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.organizationInfo?.name ?? 'Team Ragnarok ASD',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 3),
                Text(
                  receipt.organizationInfo?.address ??
                      'via giulio bezzi 25, 48026 Russi - RA',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withAlpha(230),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  'C.F.: ${receipt.organizationInfo?.taxCode ?? '92100170395'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withAlpha(220),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Receipt title ─────────────────────────────────────────────────────
  Widget _buildReceiptTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'italian_receipt.fiscal_receipt_n'.tr(
                namedArgs: {'number': receipt.receiptNumber.split('-').last}),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'italian_receipt.issued_on'
                .tr(namedArgs: {'date': receipt.formattedIssueDate}),
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (receipt.validityEndDate != null) ...[
            const SizedBox(height: 2),
            Text(
              'italian_receipt.subscription_expiry'.tr(namedArgs: {
                'date': '${receipt.validityEndDate!.day.toString().padLeft(2, '0')}-'
                    '${receipt.validityEndDate!.month.toString().padLeft(2, '0')}-'
                    '${receipt.validityEndDate!.year}'
              }),
              style:
                  GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  // ── Customer info ─────────────────────────────────────────────────────
  Widget _buildCustomerInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.blue.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'italian_receipt.billing_data'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _kv('italian_receipt.recipient'.tr(), receipt.customerName),
          if (receipt.customerTaxCode != null) ...[
            const SizedBox(height: 4),
            _kv('profile.tax_code'.tr(), receipt.customerTaxCode!),
          ],
          if (receipt.customerAddress != null) ...[
            const SizedBox(height: 4),
            _kv('profile.address'.tr(), receipt.customerAddress!),
          ],
        ],
      ),
    );
  }

  // ── Item detail ───────────────────────────────────────────────────────
  Widget _buildItemDetail() {
    final hasDiscount = receipt.discountPercentage > 0;
    final vatLabel =
        '${receipt.vatRate}%${receipt.fiscalNotes?.contains('N2.2') == true ? ' (N2.2)' : ''}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade500],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text(
                  'italian_receipt.service_details'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Text(
              receipt.description,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800),
            ),
          ),
          if (receipt.formattedValidityPeriod.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
              child: Text(
                receipt.formattedValidityPeriod,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ),

          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade200, height: 1),

          // Details grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _detailChip('italian_receipt.quantity'.tr(),
                            receipt.quantity.toString())),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _detailChip('italian_receipt.unit_price'.tr(),
                            _fmt(receipt.unitPrice))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _detailChip(
                            'italian_receipt.discount'.tr(),
                            hasDiscount
                                ? '${receipt.discountPercentage.toStringAsFixed(0)}%'
                                : '—')),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            _detailChip('italian_receipt.vat'.tr(), vatLabel)),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey.shade200, height: 1),

          // Row amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'italian_receipt.amount'.tr(),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700),
                ),
                Text(
                  _fmt(receipt.amount),
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Payment info ──────────────────────────────────────────────────────
  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.payment, color: Colors.green.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'italian_receipt.payment_method_header'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            receipt.paymentMethodText,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
          if (receipt.fiscalNotes != null) ...[
            const SizedBox(height: 10),
            Text(
              'italian_receipt.fiscal_notes_header'.tr(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              receipt.fiscalNotes!,
              style:
                  GoogleFonts.inter(fontSize: 12, color: Colors.green.shade800),
            ),
          ],
        ],
      ),
    );
  }

  // ── VAT summary + grand total ─────────────────────────────────────────
  Widget _buildVatAndTotal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // VAT table
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              // Header row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('italian_receipt.vat_rate_header'.tr(),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ),
                    Expanded(
                      child: Text('italian_receipt.taxable_header'.tr(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ),
                    Expanded(
                      child: Text('italian_receipt.tax_header'.tr(),
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ),
                  ],
                ),
              ),
              // Data row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${receipt.vatRate}%',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade800)),
                    ),
                    Expanded(
                      child: Text(_fmt(receipt.taxableAmount),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade800)),
                    ),
                    Expanded(
                      child: Text(_fmt(receipt.vatAmount),
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade800)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Grand total
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade500],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _totalLine(
                      'italian_receipt.taxable'.tr(),
                      _fmt(receipt.taxableAmount),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _totalLine(
                      'italian_receipt.vat'.tr(),
                      _fmt(receipt.vatAmount),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'italian_receipt.total'
                      .tr(namedArgs: {'amount': _fmt(receipt.amount)}),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalLine(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withAlpha(200))),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'italian_receipt.generated_by'.tr(),
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'italian_receipt.powered_by'.tr(),
            style: GoogleFonts.inter(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _kv(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade800),
          ),
        ),
      ],
    );
  }
}
