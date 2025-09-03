import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class PaymentMethodSelectionWidget extends StatelessWidget {
  final VoidCallback onSumUpSelected;
  final VoidCallback onSatispaySelected;

  const PaymentMethodSelectionWidget({
    Key? key,
    required this.onSumUpSelected,
    required this.onSatispaySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPaymentButton(
          'SumUp',
          Colors.blue,
          Icons.credit_card,
          onSumUpSelected,
        ),
        SizedBox(width: 8.w),
        _buildPaymentButton(
          'Satispay',
          Colors.orange,
          Icons.account_balance_wallet,
          onSatispaySelected,
        ),
      ],
    );
  }

  Widget _buildPaymentButton(
    String label,
    MaterialColor color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 8.h,
        ),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color.shade700,
              size: 16.sp,
            ),
            SizedBox(width: 6.w),
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
}