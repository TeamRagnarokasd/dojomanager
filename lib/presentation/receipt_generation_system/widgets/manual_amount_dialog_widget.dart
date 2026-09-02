import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_export.dart';

class ManualAmountDialogWidget extends StatefulWidget {
  final Map<String, dynamic> user;
  final String paymentMethod;

  const ManualAmountDialogWidget({
    Key? key,
    required this.user,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  State<ManualAmountDialogWidget> createState() =>
      _ManualAmountDialogWidgetState();
}

class _ManualAmountDialogWidgetState extends State<ManualAmountDialogWidget> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedType = 'monthly';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_validateInput);
  }

  void _validateInput() {
    final amount = double.tryParse(_amountController.text);
    setState(() {
      _isValid = amount != null && amount > 0;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Colors.orange.shade700,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'receipt.payment_label'
                    .tr(namedArgs: {'method': widget.paymentMethod}),
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'receipt.manual_entry_subtitle'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'receipt.client_label'.tr(namedArgs: {
                      'name': widget.user['full_name'] as String? ?? '',
                    }),
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.user['email'] != null)
                    Text(
                      widget.user['email'],
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'payment_confirm.subscription_type'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: _buildSubscriptionTypeCard(
                    'monthly',
                    'payment.monthly_plan'.tr(),
                    'receipt.monthly_standard'.tr(),
                    _selectedType == 'monthly',
                    () => setState(() => _selectedType = 'monthly'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildSubscriptionTypeCard(
                    'annual',
                    'payment.annual_plan'.tr(),
                    'receipt.annual_standard'.tr(),
                    _selectedType == 'annual',
                    () => setState(() => _selectedType = 'annual'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              'receipt.payment_amount'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'receipt.amount_hint'.tr(),
                prefixText: '€ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.orange.shade500),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 16.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'receipt.expiry_rules'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _selectedType == 'monthly'
                        ? 'receipt.monthly_expiry_rule'.tr()
                        : 'receipt.annual_expiry_rule'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'common.cancel'.tr(),
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ),
        ElevatedButton(
          onPressed: _isValid
              ? () {
                  Navigator.pop(context, {
                    'amount': double.parse(_amountController.text),
                    'type': _selectedType,
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'receipt.generate_receipt'.tr(),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionTypeCard(
    String value,
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orange.shade300 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? Colors.orange.shade700
                      : Colors.grey.shade500,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.orange.shade800
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
