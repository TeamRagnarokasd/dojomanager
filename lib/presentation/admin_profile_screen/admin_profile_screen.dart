import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../user_profile/widgets/account_security_widget.dart';
import '../user_profile/widgets/emergency_contacts_widget.dart';
import '../user_profile/widgets/medical_certificate_status_widget.dart';
import '../user_profile/widgets/personal_info_widget.dart';
import '../user_profile/widgets/profile_header_widget.dart';
import '../user_profile/widgets/settings_section_widget.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({Key? key}) : super(key: key);

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _notificationsEnabled = true;
  bool _isLoading = true;
  Map<String, dynamic>? _adminProfile;
  String? _adminRole;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    if (!AuthService.instance.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    try {
      final userId = AuthService.instance.currentUser!.id;
      final profile = await AuthService.instance.getUserProfile(userId);
      final role = await AuthService.instance.getUserRole();

      // Verify admin privileges
      if (!['admin', 'principal_admin', 'instructor_admin'].contains(role)) {
        Navigator.pushReplacementNamed(context, '/dashboard-home');
        return;
      }

      if (mounted) {
        setState(() {
          _adminProfile = profile;
          _adminRole = role;
          _currentUserId = userId;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'payment.load_profile_error'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _getAdminLevelTitle() {
    switch (_adminRole) {
      case 'principal_admin':
        return 'roles.principal_admin'.tr();
      case 'instructor_admin':
        return 'dashboard.role_instructor_admin'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      default:
        return 'roles.admin'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'admin_profile.title'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    }

    if (_adminProfile == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'admin_profile.title'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: 2.h),
              Text(
                'admin_profile.load_error'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'admin_profile.title'.tr(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
            // Admin Role Badge
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.2),
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getAdminLevelTitle(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'admin_profile.full_access'.tr(),
                          style: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),

            // Profile Header - Reusing from user profile
            ProfileHeaderWidget(userId: _currentUserId),
            SizedBox(height: 3.h),

            // Personal Info - Reusing from user profile
            PersonalInfoWidget(userId: _currentUserId),
            SizedBox(height: 3.h),

            // Medical Certificate Status - Reusing from user profile
            MedicalCertificateStatusWidget(userId: _currentUserId),
            SizedBox(height: 3.h),

            // Settings Section - Reusing from user profile
            SettingsSectionWidget(
              notificationsEnabled: _notificationsEnabled,
              onNotificationChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
            ),
            SizedBox(height: 3.h),

            // Emergency Contacts - Reusing from user profile
            EmergencyContactsWidget(userId: _currentUserId),
            SizedBox(height: 3.h),

            // Account Security - Reusing from user profile
            AccountSecurityWidget(),
            SizedBox(height: 3.h),

            // Back to Dashboard Button
            _buildBackToDashboardButton(),

            // Bottom padding
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  Widget _buildBackToDashboardButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard, color: Colors.white),
            SizedBox(width: 2.w),
            Text(
              'admin_profile.back_to_dashboard'.tr(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
