import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class UserPromotionWidget extends StatelessWidget {
  final List<dynamic> users;
  final Function(String, String) onPromote;

  const UserPromotionWidget({
    super.key,
    required this.users,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final promotableUsers = users
        .where(
          (user) => user['role'] == 'member' || user['role'] == 'student',
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.blue,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin_management.user_promotion_title'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'admin_management.user_promotion_subtitle'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'admin_management.available_count'
                      .tr(namedArgs: {'count': '${promotableUsers.length}'}),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade700,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'admin_management.promotion_roles_available'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'admin_management.promotion_roles_list'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          promotableUsers.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: promotableUsers
                      .map((user) => _buildUserPromotionCard(user, context))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(32.w),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48.sp,
            color: Colors.grey.withAlpha(128),
          ),
          SizedBox(height: 16.h),
          Text(
            'admin_management.no_users_to_promote'.tr(),
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'admin_management.all_users_have_roles'.tr(),
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: AppTheme.textSecondaryLight.withAlpha(179),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserPromotionCard(
      Map<String, dynamic> user, BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryLight.withAlpha(26),
                child: Text(
                  user['full_name']?.substring(0, 1).toUpperCase() ?? 'U',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryLight,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['full_name'] ??
                          'registration_mgmt.name_unavailable'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      user['email'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getRoleColor(user['role']).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getRoleDisplayName(user['role']),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: _getRoleColor(user['role']),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _buildPromotionButton(
                  'class_schedule.instructor'.tr(),
                  Icons.fitness_center,
                  Colors.green,
                  () => _showPromotionConfirmation(
                    context,
                    user,
                    'instructor',
                    'class_schedule.instructor'.tr(),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildPromotionButton(
                  'roles.admin'.tr(),
                  Icons.admin_panel_settings,
                  Colors.blue,
                  () => _showPromotionConfirmation(
                    context,
                    user,
                    'admin',
                    'roles.admin'.tr(),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildPromotionButton(
                  'admin_management.instructor_admin_short'.tr(),
                  Icons.shield,
                  Colors.purple,
                  () => _showPromotionConfirmation(
                    context,
                    user,
                    'instructor_admin',
                    'roles.instructor_admin'.tr(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16.sp),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11.sp),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showPromotionConfirmation(
    BuildContext context,
    Map<String, dynamic> user,
    String newRole,
    String roleDisplayName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'admin_management.confirm_promotion_title'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('admin_management.promote_confirm'.tr()),
            SizedBox(height: 16.h),
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
                    'Utente: ${user['full_name']}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  Text('Email: ${user['email']}'),
                  SizedBox(height: 8.h),
                  Text('Ruolo attuale: ${_getRoleDisplayName(user['role'])}'),
                  Text('admin_management.new_role'
                      .tr(namedArgs: {'role': roleDisplayName})),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Questa azione assegnerà automaticamente i permessi appropriati',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onPromote(user['id'], newRole);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.blue;
      case 'instructor':
        return Colors.green;
      case 'instructor_admin':
        return Colors.purple;
      case 'member':
        return Colors.orange;
      case 'student':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String? role) {
    switch (role) {
      case 'admin':
        return 'roles.admin'.tr();
      case 'instructor':
        return 'dashboard.role_instructor'.tr();
      case 'instructor_admin':
        return 'Istruttore/Admin';
      case 'member':
        return 'Membro';
      case 'student':
        return 'dashboard.role_student'.tr();
      default:
        return role ?? 'Sconosciuto';
    }
  }
}
