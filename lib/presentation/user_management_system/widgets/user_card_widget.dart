import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class UserCardWidget extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isSelected;
  final bool isPrincipalAdmin;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onUpdatePhoto;
  final VoidCallback onViewProfile;
  final VoidCallback onChangeRole;
  final VoidCallback onSendMessage;
  final VoidCallback onSuspendAccount;
  final VoidCallback onSendWelcomeEmail;
  final VoidCallback onResetPassword;
  final VoidCallback onGenerateReport;
  final VoidCallback onDeleteUser;
  final VoidCallback onFullProfileEdit;
  final VoidCallback? onTogglePasspartout;
  final VoidCallback? onViewReceipts;

  const UserCardWidget({
    super.key,
    required this.user,
    required this.isSelected,
    required this.isPrincipalAdmin,
    required this.onTap,
    required this.onLongPress,
    required this.onUpdatePhoto,
    required this.onViewProfile,
    required this.onChangeRole,
    required this.onSendMessage,
    required this.onSuspendAccount,
    required this.onSendWelcomeEmail,
    required this.onResetPassword,
    required this.onGenerateReport,
    required this.onDeleteUser,
    required this.onFullProfileEdit,
    this.onTogglePasspartout,
    this.onViewReceipts,
  });

  @override
  Widget build(BuildContext context) {
    final role = user['role']?.toString() ?? 'student';
    final isActive = user['is_active'] == true;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withAlpha(26) : Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        elevation: isSelected ? 4 : 2,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User header with avatar and basic info
                Row(
                  children: [
                    GestureDetector(
                      onTap: onUpdatePhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getRoleColor(role).withAlpha(26),
                            backgroundImage: user['profile_image_url'] != null
                                ? NetworkImage(user['profile_image_url'])
                                : null,
                            radius: 28.w,
                            child: user['profile_image_url'] == null
                                ? Icon(
                                    _getRoleIcon(role),
                                    color: _getRoleColor(role),
                                    size: 24.sp,
                                  )
                                : null,
                          ),
                          if (isSelected)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: CircleAvatar(
                                radius: 10.w,
                                backgroundColor: AppTheme.primaryColor,
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14.sp,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['full_name']?.toString() ??
                                'Nome non disponibile',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                              color: AppTheme.textPrimaryLight,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            user['email']?.toString() ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                          if (user['phone'] != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Tel: ${user['phone']}',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role).withAlpha(26),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        _getRoleLabel(role),
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: _getRoleColor(role),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                // 🎯 REQUIREMENT 1: Status Badges - Medical Certificate & Subscription
                Row(
                  children: [
                    // Medical Certificate Badge 🩺
                    Expanded(
                      child: _buildStatusBadge(
                        _getMedicalCertificateBadgeData(),
                        'Certificato 🩺',
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Subscription Badge 💰
                    Expanded(
                      child: _buildStatusBadge(
                        _getSubscriptionBadgeData(),
                        'Abbonamento 💰',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                // 🎯 REQUIREMENT 2: Redesigned Button Logic - "Modifica Veloce" & "Profilo Completo"
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // BUTTON 1: "Modifica Veloce" - Opens quick edit popup
                      _buildActionChip(
                        label: 'user_mgmt.quick_edit'.tr(),
                        icon: Icons.flash_on,
                        color: Colors.orange,
                        onTap: onLongPress, // Opens quick edit dialog
                      ),
                      SizedBox(width: 8.w),
                      // BUTTON 2: "Profilo Completo" - Navigates to full profile
                      _buildActionChip(
                        label: 'Profilo Completo',
                        icon: Icons.person_outline,
                        color: Colors.blue,
                        onTap: onFullProfileEdit, // Opens full profile screen
                      ),
                      SizedBox(width: 8.w),
                      // BUTTON 3: "Ricevute" - Opens receipt dropdown
                      _buildActionChip(
                        label: 'Ricevute',
                        icon: Icons.receipt_long,
                        color: Colors.teal,
                        onTap: onViewReceipts ?? () {},
                      ),
                      if ((isPrincipalAdmin ||
                              user['role']?.toString() == 'admin' ||
                              user['role']?.toString() == 'instructor_admin') &&
                          user['email'] != 'lutadordeeliteravenna@gmail.com' &&
                          user['role']?.toString() != 'principal_admin') ...[
                        SizedBox(width: 8.w),
                        _buildActionChip(
                          label: 'common.delete'.tr(),
                          icon: Icons.delete,
                          color: Colors.red,
                          onTap: onDeleteUser,
                        ),
                      ],
                      if (isPrincipalAdmin &&
                          user['role']?.toString() != 'principal_admin') ...[
                        SizedBox(width: 8.w),
                        _buildActionChip(
                          label: 'profile.role'.tr(),
                          icon: Icons.admin_panel_settings,
                          color: Colors.purple,
                          onTap: onChangeRole,
                        ),
                      ],
                      if (isPrincipalAdmin &&
                          user['role']?.toString() != 'principal_admin' &&
                          onTogglePasspartout != null) ...[
                        SizedBox(width: 8.w),
                        _buildActionChip(
                          label: user['booking_passpartout'] == true
                              ? 'Passpartout ON'
                              : 'Passpartout',
                          icon: Icons.key,
                          color: user['booking_passpartout'] == true
                              ? Colors.amber
                              : Colors.grey,
                          onTap: onTogglePasspartout!,
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 8.h),

                // Quick actions
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight.withAlpha(128),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Wrap(
                    spacing: 8.w,
                    runSpacing: 4.h,
                    children: [
                      _buildQuickAction(
                        'Visualizza',
                        Icons.visibility,
                        onViewProfile,
                      ),
                      _buildQuickAction(
                        isActive ? 'Sospendi' : 'Riattiva',
                        isActive ? Icons.block : Icons.check_circle,
                        onSuspendAccount,
                      ),
                      _buildQuickAction(
                        'communication.message_label'.tr(),
                        Icons.message,
                        onSendMessage,
                      ),
                      _buildQuickAction(
                        'Report',
                        Icons.description,
                        onGenerateReport,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> badgeData, String labelPrefix) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: badgeData['color'].withAlpha(26),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: badgeData['color'].withAlpha(77), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(badgeData['icon'], color: badgeData['color'], size: 16.sp),
          SizedBox(width: 6.w),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labelPrefix,
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w400,
                    color: badgeData['color'].withAlpha(179),
                  ),
                ),
                Text(
                  badgeData['label'],
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: badgeData['color'],
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

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: color.withAlpha(77), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12.sp, color: AppTheme.textSecondaryLight),
              SizedBox(width: 4.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  color: AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🩺 Medical Certificate Badge Logic
  /// Status: Valido (Green) | Scaduto (Red) | Da Caricare (Grey)
  Map<String, dynamic> _getMedicalCertificateBadgeData() {
    final certificateUrl = user['medical_certificate_url'];
    final certificateExpiry = user['medical_certificate_expiry'];
    final hasCertificate =
        certificateUrl != null && certificateUrl.toString().isNotEmpty;

    if (!hasCertificate) {
      return {
        'label': 'Da Caricare',
        'color': Colors.grey,
        'icon': Icons.upload_file,
      };
    }

    if (certificateExpiry != null) {
      try {
        final expiryDate = DateTime.parse(certificateExpiry);
        final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

        if (daysUntilExpiry < 0) {
          return {
            'label': 'profile.status_expired'.tr(),
            'color': Colors.red,
            'icon': Icons.error_outline,
          };
        } else if (daysUntilExpiry <= 60) {
          return {
            'label': 'profile.status_expiring_short'.tr(),
            'color': Colors.orange,
            'icon': Icons.warning_amber_outlined,
          };
        } else {
          return {
            'label': 'profile.status_valid'.tr(),
            'color': Colors.green,
            'icon': Icons.check_circle_outline,
          };
        }
      } catch (e) {
        return {
          'label': 'user_mgmt.error_label'.tr(),
          'color': Colors.grey,
          'icon': Icons.error_outline,
        };
      }
    }

    return {
      'label': 'common.uploaded'.tr(),
      'color': Colors.blue,
      'icon': Icons.description_outlined,
    };
  }

  /// 💰 Subscription Badge Logic
  /// Status: Attivo (Green) | Inattivo/Scaduto (Red)
  Map<String, dynamic> _getSubscriptionBadgeData() {
    final subscriptionData = user['subscription_data'] as Map<String, dynamic>?;

    if (subscriptionData == null) {
      return {
        'label': 'common.none'.tr(),
        'color': Colors.grey,
        'icon': Icons.cancel_outlined,
      };
    }

    final isActive = subscriptionData['is_active'] == true;
    final expiresAt = subscriptionData['expires_at'];

    if (!isActive) {
      return {
        'label': 'common.inactive'.tr(),
        'color': Colors.grey,
        'icon': Icons.cancel_outlined,
      };
    }

    if (expiresAt != null) {
      try {
        final expiryDate = DateTime.parse(expiresAt);
        final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

        if (daysUntilExpiry < 0) {
          return {
            'label': 'profile.status_expired'.tr(),
            'color': Colors.red,
            'icon': Icons.error_outline,
          };
        } else if (daysUntilExpiry <= 7) {
          return {
            'label': 'profile.status_expiring_short'.tr(),
            'color': Colors.orange,
            'icon': Icons.warning_amber_outlined,
          };
        } else {
          return {
            'label': 'common.active'.tr(),
            'color': Colors.green,
            'icon': Icons.check_circle_outline,
          };
        }
      } catch (e) {
        return {
          'label': 'user_mgmt.error_label'.tr(),
          'color': Colors.grey,
          'icon': Icons.error_outline,
        };
      }
    }

    return {
      'label': 'common.active'.tr(),
      'color': Colors.green,
      'icon': Icons.check_circle_outline,
    };
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'principal_admin':
        return Colors.red;
      case 'admin':
        return Colors.orange;
      case 'instructor_admin':
        return Colors.purple;
      case 'instructor':
        return Colors.blue;
      case 'student':
      default:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'principal_admin':
        return Icons.shield;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'instructor_admin':
        return Icons.supervisor_account;
      case 'instructor':
        return Icons.school;
      case 'student':
      default:
        return Icons.person;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'principal_admin':
        return 'dashboard.role_principal_admin'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      case 'instructor_admin':
        return 'dashboard.role_instructor_admin'.tr();
      case 'instructor':
        return 'dashboard.role_instructor'.tr();
      case 'student':
      default:
        return 'dashboard.role_student'.tr();
    }
  }
}
