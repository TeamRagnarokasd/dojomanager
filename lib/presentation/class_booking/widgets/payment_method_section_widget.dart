import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

class PaymentMethodSectionWidget extends StatelessWidget {
  final String? selectedMethod;
  final Function(String) onMethodSelected;
  final double classPrice;

  const PaymentMethodSectionWidget({
    Key? key,
    required this.selectedMethod,
    required this.onMethodSelected,
    required this.classPrice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final paymentMethods = [
      {
        'id': 'sumup',
        'name': 'SumUp',
        'icon': Icons.payment,
        'description': 'Pagamento con carta',
      },
      {
        'id': 'satispay',
        'name': 'Satispay',
        'icon': Icons.phone_android,
        'description': 'Pagamento mobile',
      },
      {
        'id': 'subscription',
        'name': 'Abbonamento',
        'icon': Icons.card_membership,
        'description': 'Usa crediti abbonamento',
      },
      {
        'id': 'card',
        'name': 'Carta Salvata',
        'icon': Icons.credit_card,
        'description': 'Carta registrata',
      },
    ];

    return Container(
      padding: EdgeInsets.all(16.sp),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Metodo di Pagamento',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Spacer(),
              Text(
                '€${classPrice.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...paymentMethods.map((method) => _buildPaymentOption(method)),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(Map<String, dynamic> method) {
    final isSelected = selectedMethod == method['id'];

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: RadioListTile<String>(
        value: method['id'],
        groupValue: selectedMethod,
        onChanged: (value) => onMethodSelected(value!),
        title: Row(
          children: [
            Icon(method['icon'], color: Colors.red, size: 20),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['name'],
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    method['description'],
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        activeColor: Colors.red,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
