import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';

class SettingsSectionWidget extends StatelessWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationChanged;

  const SettingsSectionWidget({
    Key? key,
    required this.notificationsEnabled,
    required this.onNotificationChanged,
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
            'Impostazioni',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          _buildNotificationToggle(),
          SizedBox(height: 2.h),
          _buildPrivacyControls(),
        ],
      ),
    );
  }

  Widget _buildNotificationToggle() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications, color: Colors.red, size: 5.w),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifiche Push',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Ricevi notifiche per lezioni e aggiornamenti',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 9.sp,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: notificationsEnabled,
            onChanged: onNotificationChanged,
            activeColor: Colors.red,
            activeTrackColor: Colors.red.withAlpha(77),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyControls() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.privacy_tip, color: Colors.red, size: 5.w),
              SizedBox(width: 3.w),
              Text(
                'Privacy e Sicurezza',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildPrivacyOption('Profilo Pubblico', true),
          SizedBox(height: 1.h),
          _buildPrivacyOption('Condividi Progressi', false),
          SizedBox(height: 1.h),
          _buildPrivacyOption('Ricevi Messaggi da Istruttori', true),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(String title, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.grey[300],
            fontSize: 10.sp,
          ),
        ),
        Switch(
          value: value,
          onChanged: (newValue) {
            // Handle privacy setting change
          },
          activeColor: Colors.red,
          activeTrackColor: Colors.red.withAlpha(77),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
