import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleManagementCardsWidget extends StatefulWidget {
  final List<Map<String, dynamic>> allUsers;
  final Function(String, String, String) onPromoteUser;

  const RoleManagementCardsWidget({
    Key? key,
    required this.allUsers,
    required this.onPromoteUser,
  }) : super(key: key);

  @override
  State<RoleManagementCardsWidget> createState() =>
      _RoleManagementCardsWidgetState();
}

class _RoleManagementCardsWidgetState extends State<RoleManagementCardsWidget> {
  String _selectedRoleFilter = 'all';
  String _searchQuery = '';

  final List<Map<String, String>> _roleFilters = [
    {'value': 'all', 'label': 'All Users', 'icon': 'group'},
    {'value': 'member', 'label': 'Members', 'icon': 'person'},
    {'value': 'instructor', 'label': 'Instructors', 'icon': 'school'},
    {'value': 'admin', 'label': 'Admins', 'icon': 'admin'},
    {
      'value': 'instructor_admin',
      'label': 'Instructor/Admin',
      'icon': 'supervisor'
    },
  ];

  Map<String, List<Map<String, dynamic>>> get _groupedUsers {
    final filtered = widget.allUsers.where((user) {
      final matchesRole =
          _selectedRoleFilter == 'all' || user['role'] == _selectedRoleFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          (user['full_name'] ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (user['email'] ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchesRole && matchesSearch;
    }).toList();

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final user in filtered) {
      final role = user['role'] as String? ?? 'member';
      grouped[role] = grouped[role] ?? [];
      grouped[role]!.add(user);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.sp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role Management Overview',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.sp),
          Text(
            'Organize users by their current roles and permissions',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 16.sp),
          _buildFilterAndSearch(),
          SizedBox(height: 16.sp),
          _buildRoleCards(),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    return Container(
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8.sp),
      ),
      child: Column(
        children: [
          // Role filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _roleFilters.map((filter) {
                final isSelected = _selectedRoleFilter == filter['value'];
                return Container(
                  margin: EdgeInsets.only(right: 8.sp),
                  child: FilterChip(
                    label: Text(
                      filter['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedRoleFilter =
                            selected ? filter['value']! : 'all';
                      });
                    },
                    backgroundColor: Colors.white.withAlpha(13),
                    selectedColor: Colors.orange.withAlpha(77),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? Colors.orange
                          : Colors.white.withAlpha(51),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 12.sp),
          // Search field
          TextField(
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12.sp),
            decoration: InputDecoration(
              hintText: 'Search users...',
              hintStyle:
                  GoogleFonts.inter(color: Colors.white54, fontSize: 12.sp),
              prefixIcon:
                  Icon(Icons.search, color: Colors.white54, size: 18.sp),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.sp),
                borderSide: BorderSide(color: Colors.white.withAlpha(51)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.sp),
                borderSide: BorderSide(color: Colors.white.withAlpha(51)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.sp),
                borderSide: const BorderSide(color: Colors.orange),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.sp),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCards() {
    final groupedUsers = _groupedUsers;

    if (groupedUsers.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: groupedUsers.entries.map((entry) {
        return _buildRoleGroupCard(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(24.sp),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            color: Colors.white54,
            size: 48.sp,
          ),
          SizedBox(height: 12.sp),
          Text(
            'No Users Found',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.sp),
          Text(
            'Try adjusting your search or filter criteria',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleGroupCard(String role, List<Map<String, dynamic>> users) {
    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);
    final formattedRole = _formatRole(role);

    return Container(
      margin: EdgeInsets.only(bottom: 16.sp),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12.sp),
        border: Border.all(color: roleColor.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.sp),
            decoration: BoxDecoration(
              color: roleColor.withAlpha(26),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.sp),
                topRight: Radius.circular(12.sp),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.sp),
                  decoration: BoxDecoration(
                    color: roleColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(8.sp),
                  ),
                  child: Icon(
                    roleIcon,
                    color: roleColor,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.sp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedRole,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${users.length} user${users.length != 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...users.map((user) => _buildUserTile(user, roleColor)).toList(),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, Color roleColor) {
    final isPrincipalAdmin = user['email'] == 'lutadordeeliteravenna@gmail.com';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 12.sp),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(26)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32.sp,
            height: 32.sp,
            decoration: BoxDecoration(
              color: roleColor.withAlpha(51),
              borderRadius: BorderRadius.circular(16.sp),
            ),
            child: Icon(
              Icons.person,
              color: roleColor,
              size: 16.sp,
            ),
          ),
          SizedBox(width: 12.sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user['full_name'] ?? 'Unknown User',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isPrincipalAdmin)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.sp, vertical: 2.sp),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(51),
                          borderRadius: BorderRadius.circular(4.sp),
                        ),
                        child: Text(
                          'PRINCIPAL',
                          style: GoogleFonts.inter(
                            color: Colors.red,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  user['email'] ?? 'no-email@example.com',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (!isPrincipalAdmin)
            IconButton(
              onPressed: () => _showQuickPromotionOptions(user),
              icon: Icon(
                Icons.more_vert,
                color: Colors.white54,
                size: 16.sp,
              ),
            ),
        ],
      ),
    );
  }

  void _showQuickPromotionOptions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.sp)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions for ${user['full_name']}',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.sp),
            _buildQuickActionTile(
              'Promote to Instructor',
              Icons.school,
              Colors.green,
              () => widget.onPromoteUser(user['id'], 'instructor',
                  'Quick promotion via role management'),
            ),
            _buildQuickActionTile(
              'Promote to Admin',
              Icons.admin_panel_settings,
              Colors.red,
              () => widget.onPromoteUser(
                  user['id'], 'admin', 'Quick promotion via role management'),
            ),
            _buildQuickActionTile(
              'Promote to Instructor/Admin',
              Icons.supervisor_account,
              Colors.purple,
              () => widget.onPromoteUser(user['id'], 'instructor_admin',
                  'Quick promotion via role management'),
            ),
            _buildQuickActionTile(
              'Demote to Member',
              Icons.person,
              Colors.blue,
              () => widget.onPromoteUser(
                  user['id'], 'member', 'Demotion via role management'),
            ),
            SizedBox(height: 8.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20.sp),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: EdgeInsets.symmetric(horizontal: 8.sp),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'instructor':
        return Colors.green;
      case 'admin':
        return Colors.red;
      case 'instructor_admin':
        return Colors.purple;
      case 'principal_admin':
        return Colors.deepOrange;
      default:
        return Colors.blue;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'instructor':
        return Icons.school;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'instructor_admin':
        return Icons.supervisor_account;
      case 'principal_admin':
        return Icons.security;
      default:
        return Icons.group;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'instructor':
        return 'Instructors';
      case 'admin':
        return 'Administrators';
      case 'instructor_admin':
        return 'Instructor/Administrators';
      case 'principal_admin':
        return 'Principal Administrator';
      default:
        return 'Members';
    }
  }
}
