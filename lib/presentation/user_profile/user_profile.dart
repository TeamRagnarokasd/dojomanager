import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/account_security_widget.dart';
import './widgets/emergency_contacts_widget.dart';
import './widgets/martial_arts_progress_widget.dart';
import './widgets/medical_certificate_status_widget.dart';
import './widgets/personal_info_widget.dart';
import './widgets/profile_header_widget.dart';
import './widgets/settings_section_widget.dart';
import './widgets/subscription_details_widget.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({Key? key}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  bool _notificationsEnabled = true;
  bool _autoRenewal = true;
  String _selectedTheme = 'dark';

  @override
  Widget build(BuildContext context) {
    return MainNavigationWrapper(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Profilo Utente',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            Image.asset(
              AppConstants.teamLogo,
              width: 8.w,
              height: 4.h,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 4.w),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(4.w),
          child: Column(
            children: [
              ProfileHeaderWidget(),
              SizedBox(height: 3.h),
              PersonalInfoWidget(),
              SizedBox(height: 3.h),
              MartialArtsProgressWidget(),
              SizedBox(height: 3.h),
              MedicalCertificateStatusWidget(),
              SizedBox(height: 3.h),
              SubscriptionDetailsWidget(
                autoRenewal: _autoRenewal,
                onAutoRenewalChanged: (value) =>
                    setState(() => _autoRenewal = value),
              ),
              SizedBox(height: 3.h),
              SettingsSectionWidget(
                notificationsEnabled: _notificationsEnabled,
                onNotificationChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
              ),
              SizedBox(height: 3.h),
              EmergencyContactsWidget(),
              SizedBox(height: 3.h),
              AccountSecurityWidget(),
              SizedBox(height: 3.h),
              _buildLogoutButton(),
              // Bottom padding for navigation bar
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showLogoutDialog(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultBorderRadius),
          ),
        ),
        child: Text(
          'Logout',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'Conferma Logout',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'Sei sicuro di voler uscire dall\'app?',
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            child: Text(
              'Logout',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}