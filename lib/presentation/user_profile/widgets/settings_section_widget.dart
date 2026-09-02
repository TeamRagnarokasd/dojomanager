import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/profile_typography.dart';
import '../../../widgets/language_settings_widget.dart';

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
            'profile.settings'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: ProfileTypography.sectionTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          const LanguageSettingsWidget(),
          SizedBox(height: 2.h),
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
          Icon(Icons.notifications, color: Colors.red, size: 22),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'profile.push_notifications'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.rowLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  'profile.push_notifications_subtitle'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: ProfileTypography.subtitle,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: notificationsEnabled,
            onChanged: onNotificationChanged,
            activeThumbColor: Colors.red,
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
              Icon(Icons.privacy_tip, color: Colors.red, size: 22),
              SizedBox(width: 3.w),
              Text(
                'profile.privacy_security'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: ProfileTypography.rowLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildPrivacyOption('profile.public_profile'.tr(), true),
          SizedBox(height: 1.h),
          _buildPrivacyOption('profile.share_progress'.tr(), false),
          SizedBox(height: 1.h),
          _buildPrivacyOption('profile.instructor_messages'.tr(), true),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption(String title, bool value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.grey[300],
              fontSize: ProfileTypography.optionLabel,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: (newValue) {
            // Handle privacy setting change
          },
          activeThumbColor: Colors.red,
          activeTrackColor: Colors.red.withAlpha(77),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}
