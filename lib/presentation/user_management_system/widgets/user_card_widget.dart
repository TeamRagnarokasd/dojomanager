import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_theme.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final role = user['role']?.toString() ?? 'student';
    final isActive = user['is_active'] == true;
    final subscriptionStatus = _getSubscriptionStatus();
    final lastActivity = _getLastActivity();

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 4.h),
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
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: subscriptionStatus['color'].withAlpha(26),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            subscriptionStatus['label'],
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w500,
                              color: subscriptionStatus['color'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.red,
                      size: 14.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      isActive ? 'Attivo' : 'Disattivato',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ultima attività: $lastActivity',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Swipe actions row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildActionChip(
                        label: 'Visualizza Profilo',
                        icon: Icons.visibility,
                        color: Colors.blue,
                        onTap: onViewProfile,
                      ),
                      if (isPrincipalAdmin && role != 'principal_admin') ...[
                        SizedBox(width: 8.w),
                        _buildActionChip(
                          label: 'Modifica Ruolo',
                          icon: Icons.admin_panel_settings,
                          color: Colors.orange,
                          onTap: onChangeRole,
                        ),
                      ],
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label: 'Invia Messaggio',
                        icon: Icons.message,
                        color: Colors.green,
                        onTap: onSendMessage,
                      ),
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label:
                            isActive ? 'Sospendi Account' : 'Riattiva Account',
                        icon: isActive ? Icons.block : Icons.check_circle,
                        color: isActive ? Colors.red : Colors.green,
                        onTap: onSuspendAccount,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                // Quick actions panel
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
                          'Benvenuto', Icons.email, onSendWelcomeEmail),
                      _buildQuickAction(
                          'Reset Password', Icons.lock_reset, onResetPassword),
                      _buildQuickAction(
                          'Genera Report', Icons.description, onGenerateReport),
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
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: color.withAlpha(77)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 10.sp,
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

  Map<String, dynamic> _getSubscriptionStatus() {
    // Mock subscription status logic
    final isActive = user['is_active'] == true;
    if (isActive) {
      return {'label': 'Premium', 'color': Colors.green};
    } else {
      return {'label': 'Basic', 'color': Colors.orange};
    }
  }

  String _getLastActivity() {
    // Mock last activity logic
    final createdAt =
        DateTime.parse(user['created_at'] ?? DateTime.now().toIso8601String());
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${difference.inDays} giorni fa';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} giorni fa';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ore fa';
    } else {
      return 'Oggi';
    }
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
        return 'Admin Principale';
      case 'admin':
        return 'Amministratore';
      case 'instructor_admin':
        return 'Istruttore Admin';
      case 'instructor':
        return 'Istruttore';
      case 'student':
      default:
        return 'Studente';
    }
  }
}
