import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class SubscriptionDetailsWidget extends StatelessWidget {
  final bool autoRenewal;
  final ValueChanged<bool> onAutoRenewalChanged;

  const SubscriptionDetailsWidget({
    Key? key,
    required this.autoRenewal,
    required this.onAutoRenewalChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dettagli Abbonamento',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          _buildSubscriptionCard(),
          SizedBox(height: 2.h),
          _buildPaymentStatus(),
          SizedBox(height: 2.h),
          _buildAutoRenewalToggle(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withAlpha(51), Colors.red.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team Ragnarok Premium',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(128)),
                ),
                child: Text(
                  'ATTIVO',
                  style: GoogleFonts.inter(
                    color: Colors.green,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildPlanDetail('Prezzo Mensile', '€89/mese'),
              ),
              Expanded(
                child: _buildPlanDetail('Prossima Fatturazione', '15/01/2025'),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Include: Accesso illimitato a BJJ, SAMBO, MMA, GRAPPLING + Personal Training',
            style: GoogleFonts.inter(
              color: Colors.grey[300],
              fontSize: 9.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 9.sp,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatus() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha(77)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 5.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagamento Aggiornato',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Ultimo pagamento: 15/12/2024 - Carta **** 1234',
                  style: GoogleFonts.inter(
                    color: Colors.grey[300],
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoRenewalToggle() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rinnovo Automatico',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Il tuo abbonamento si rinnoverà automaticamente',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: autoRenewal,
            onChanged: onAutoRenewalChanged,
            activeColor: Colors.red,
            activeTrackColor: Colors.red.withAlpha(77),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withAlpha(77),
          ),
        ],
      ),
    );
  }
}