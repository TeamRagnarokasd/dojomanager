import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RoleManagementWidget extends StatefulWidget {
  final List<dynamic> users;
  final bool canModify;
  final Function(String, String) onRoleUpdate;

  const RoleManagementWidget({
    super.key,
    required this.users,
    required this.canModify,
    required this.onRoleUpdate,
  });

  @override
  State<RoleManagementWidget> createState() => _RoleManagementWidgetState();
}

class _RoleManagementWidgetState extends State<RoleManagementWidget> {
  String selectedFilter = 'all';
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

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
                  color: Colors.purple.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.people, color: Colors.purple, size: 24.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'admin_management.role_management_title'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'admin_management.role_management_subtitle'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.canModify)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14.sp, color: Colors.green),
                      SizedBox(width: 4.w),
                      Text(
                        'admin_management.edit_enabled'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildFilterAndSearch(),
          SizedBox(height: 20.h),
          _buildRoleStatistics(),
          SizedBox(height: 20.h),
          filteredUsers.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: filteredUsers
                      .map((user) => _buildUserRoleCard(user))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) {
                  setState(() => searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: 'admin_management.search_users'.tr(),
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            PopupMenuButton<String>(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.filter_list, color: AppTheme.primaryLight),
              ),
              onSelected: (value) {
                setState(() => selectedFilter = value);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'all',
                  child: Text('admin_management.all_roles'.tr()),
                ),
                PopupMenuItem(value: 'admin', child: Text('roles.admin'.tr())),
                PopupMenuItem(
                  value: 'instructor',
                  child: Text('admin_management.instructors_filter'.tr()),
                ),
                PopupMenuItem(
                  value: 'member',
                  child: Text('admin_management.members'.tr()),
                ),
                PopupMenuItem(
                  value: 'student',
                  child: Text('admin_management.students_filter'.tr()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleStatistics() {
    final roleStats = _getRoleStatistics();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin_management.role_distribution'.tr(),
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 8.h,
            children: roleStats.entries
                .map((entry) => _buildRoleStatChip(entry.key, entry.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleStatChip(String role, int count) {
    final color = _getRoleColor(role);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            '${_getRoleDisplayName(role)}: $count',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: color,
            ),
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
            Icons.search_off,
            size: 48.sp,
            color: Colors.grey.withAlpha(128),
          ),
          SizedBox(height: 16.h),
          Text(
            'reminders.no_users_found'.tr(),
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'admin_management.modify_search_filters'.tr(),
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

  Widget _buildUserRoleCard(Map<String, dynamic> user) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _getRoleColor(user['role']).withAlpha(26),
            child: Text(
              user['full_name']?.substring(0, 1).toUpperCase() ?? 'U',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: _getRoleColor(user['role']),
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
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                Text(
                  user['email'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
          if (widget.canModify) ...[
            SizedBox(width: 8.w),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18.sp),
              onSelected: (newRole) {
                if (newRole != user['role']) {
                  _showRoleChangeConfirmation(user, newRole);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'member',
                  child: Text('roles.member'.tr()),
                ),
                PopupMenuItem(
                  value: 'student',
                  child: Text('roles.student'.tr()),
                ),
                PopupMenuItem(
                  value: 'instructor',
                  child: Text('class_schedule.instructor'.tr()),
                ),
                PopupMenuItem(value: 'admin', child: Text('roles.admin'.tr())),
                PopupMenuItem(
                  value: 'instructor_admin',
                  child: Text('roles.instructor_admin'.tr()),
                ),
                PopupMenuItem(
                  value: 'instructor_student',
                  child: Text('Istruttore Allievo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<dynamic> _getFilteredUsers() {
    var filtered = widget.users;

    if (selectedFilter != 'all') {
      filtered = filtered
          .where((user) => user['role'] == selectedFilter)
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = (user['full_name'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        final query = searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    return filtered;
  }

  Map<String, int> _getRoleStatistics() {
    final stats = <String, int>{};
    for (final user in widget.users) {
      final role = user['role'] ?? 'unknown';
      stats[role] = (stats[role] ?? 0) + 1;
    }
    return stats;
  }

  void _showRoleChangeConfirmation(Map<String, dynamic> user, String newRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'admin_management.confirm_role_change_title'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('admin_management.confirm_role_change'.tr()),
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
                    'admin_management.user_label'.tr(
                      namedArgs: {'name': '${user['full_name']}'},
                    ),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'admin_management.current_role_label'.tr(
                      namedArgs: {'role': _getRoleDisplayName(user['role'])},
                    ),
                  ),
                  Text(
                    'admin_management.new_role'.tr(
                      namedArgs: {'role': _getRoleDisplayName(newRole)},
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
              widget.onRoleUpdate(user['id'], newRole);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
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
      case 'instructor_student':
        return Colors.teal;
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
      case 'instructor_student':
        return 'Istruttore Allievo';
      case 'member':
        return 'Membro';
      case 'student':
        return 'dashboard.role_student'.tr();
      default:
        return role ?? 'Sconosciuto';
    }
  }
}
