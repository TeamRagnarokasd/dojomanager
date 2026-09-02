import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class UserManagementListWidget extends StatefulWidget {
  final bool isPrincipalAdmin;

  const UserManagementListWidget({
    super.key,
    required this.isPrincipalAdmin,
  });

  @override
  State<UserManagementListWidget> createState() =>
      _UserManagementListWidgetState();
}

class _UserManagementListWidgetState extends State<UserManagementListWidget> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);
      final client = SupabaseService.instance.client;

      final response = await client
          .from('user_profiles')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _filteredUsers = _users;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() => _isLoading = false);
      Fluttertoast.showToast(
        msg: "Errore nel caricamento utenti",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = _searchQuery.isEmpty ||
            (user['full_name']
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (user['email']
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);

        final matchesRole =
            _selectedRoleFilter == 'all' || user['role'] == _selectedRoleFilter;

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    if (!widget.isPrincipalAdmin) {
      Fluttertoast.showToast(
        msg: "Solo l'admin principale può modificare i ruoli",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      final client = SupabaseService.instance.client;

      await client
          .from('user_profiles')
          .update({'role': newRole}).eq('id', userId);

      // Log activity
      await client.from('admin_activity_log').insert({
        'admin_id': client.auth.currentUser?.id,
        'action_type': 'ROLE_UPDATE',
        'description': 'Ruolo utente aggiornato da admin principale',
        'target_user_id': userId,
        'new_role': newRole,
        'metadata': {'updated_at': DateTime.now().toIso8601String()}
      });

      Fluttertoast.showToast(
        msg: "Ruolo utente aggiornato con successo",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      await _loadUsers();
    } catch (e) {
      debugPrint('Error updating user role: $e');
      Fluttertoast.showToast(
        msg: "Errore nell'aggiornamento del ruolo",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    if (!widget.isPrincipalAdmin) {
      Fluttertoast.showToast(
        msg: "Solo l'admin principale può modificare lo stato utenti",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      final client = SupabaseService.instance.client;

      await client
          .from('user_profiles')
          .update({'is_active': !currentStatus}).eq('id', userId);

      // Log activity
      await client.from('admin_activity_log').insert({
        'admin_id': client.auth.currentUser?.id,
        'action_type': 'USER_STATUS_UPDATE',
        'description':
            'Stato utente modificato: ${!currentStatus ? 'attivato' : 'disattivato'}',
        'target_user_id': userId,
        'metadata': {
          'previous_status': currentStatus,
          'new_status': !currentStatus,
          'updated_at': DateTime.now().toIso8601String()
        }
      });

      Fluttertoast.showToast(
        msg: "Stato utente aggiornato con successo",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      await _loadUsers();
    } catch (e) {
      debugPrint('Error updating user status: $e');
      Fluttertoast.showToast(
        msg: "Errore nell'aggiornamento dello stato",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _togglePasspartout(String userId, bool currentValue) async {
    if (!widget.isPrincipalAdmin) {
      Fluttertoast.showToast(
        msg: "Solo l'admin principale può gestire il passpartout",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      final client = SupabaseService.instance.client;
      final newValue = !currentValue;

      await client
          .from('user_profiles')
          .update({'booking_passpartout': newValue}).eq('id', userId);

      await client.from('admin_activity_log').insert({
        'admin_id': client.auth.currentUser?.id,
        'action_type': 'PASSPARTOUT_UPDATE',
        'description':
            'Passpartout prenotazione ${newValue ? 'abilitato' : 'disabilitato'} per utente',
        'target_user_id': userId,
        'metadata': {
          'passpartout_enabled': newValue,
          'updated_at': DateTime.now().toIso8601String()
        }
      });

      Fluttertoast.showToast(
        msg: newValue
            ? "🗝️ Passpartout abilitato: l'utente può prenotare senza abbonamento"
            : "🔒 Passpartout disabilitato",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );

      await _loadUsers();
    } catch (e) {
      debugPrint('Error toggling passpartout: $e');
      Fluttertoast.showToast(
        msg: "Errore nell'aggiornamento del passpartout",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _showPasspartoutDialog(Map<String, dynamic> user) {
    final hasPasspartout = user['booking_passpartout'] == true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.key,
              color: hasPasspartout ? Colors.amber : Colors.grey,
            ),
            SizedBox(width: 8.w),
            Text(
              'Passpartout Prenotazione',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Utente: ${user['full_name'] ?? 'N/A'}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Text(
              hasPasspartout
                  ? '✅ Il passpartout è attualmente ATTIVO.\n\nL\'utente può prenotare qualsiasi lezione anche senza abbonamento.\n\nVuoi disabilitarlo?'
                  : '🔒 Il passpartout è attualmente DISATTIVO.\n\nAbilitandolo, l\'utente potrà prenotare qualsiasi lezione anche senza abbonamento acquistato.',
              style: GoogleFonts.inter(fontSize: 13.sp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla', style: GoogleFonts.inter()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _togglePasspartout(user['id'], hasPasspartout);
            },
            icon: Icon(hasPasspartout ? Icons.lock : Icons.key, size: 16),
            label: Text(
              hasPasspartout ? 'Disabilita' : 'Abilita',
              style: GoogleFonts.inter(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPasspartout ? Colors.red : Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _buildHeader(),
          _buildFiltersSection(),
          _buildStatistics(),
          _buildUsersList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.people_alt,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestione Utenti Sistema',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Amministrazione completa degli utenti',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.white.withAlpha(204),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isPrincipalAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(51),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings,
                      size: 14.sp, color: Colors.white),
                  SizedBox(width: 4.w),
                  Text(
                    'roles.principal_admin_short'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'admin_management.search_users_full'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _applyFilters();
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryLight),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRoleFilter,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    onChanged: (value) {
                      setState(() => _selectedRoleFilter = value ?? 'all');
                      _applyFilters();
                    },
                    items: [
                      DropdownMenuItem(
                          value: 'all',
                          child: Text('admin_management.all_roles'.tr())),
                      DropdownMenuItem(
                          value: 'student',
                          child: Text('admin_management.students_filter'.tr())),
                      DropdownMenuItem(
                          value: 'instructor',
                          child:
                              Text('admin_management.instructors_filter'.tr())),
                      DropdownMenuItem(
                          value: 'admin', child: Text('roles.admin'.tr())),
                      DropdownMenuItem(
                          value: 'instructor_admin',
                          child:
                              Text('admin_management.instructor_admins'.tr())),
                      DropdownMenuItem(
                          value: 'principal_admin',
                          child: Text('roles.principal_admin_short'.tr())),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    if (_isLoading) return Container();

    final roleStats = <String, int>{};
    for (final user in _users) {
      final role = user['role'] ?? 'unknown';
      roleStats[role] = (roleStats[role] ?? 0) + 1;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'admin_management.user_stats_title'.tr(namedArgs: {
              'filtered': '${_filteredUsers.length}',
              'total': '${_users.length}',
            }),
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

  Widget _buildUsersList() {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(40.w),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredUsers.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40.w),
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
            Text(
              'admin_management.modify_filters_hint'.tr(),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: AppTheme.textSecondaryLight.withAlpha(179),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: 60.h),
      margin: EdgeInsets.all(20.w),
      child: ListView.builder(
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['is_active'] ?? true;
    final role = user['role'] ?? 'student';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.grey.shade200 : Colors.grey.shade300,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getRoleColor(role).withAlpha(26),
                child: Text(
                  user['full_name']?.substring(0, 1).toUpperCase() ?? 'U',
                  style: GoogleFonts.inter(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(role),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user['full_name'] ?? 'Nome non disponibile',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppTheme.textPrimaryLight
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (!isActive)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'admin_management.inactive_status'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      user['email'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: isActive
                            ? AppTheme.textSecondaryLight
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getRoleColor(role).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getRoleDisplayName(role),
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: _getRoleColor(role),
                  ),
                ),
              ),
            ],
          ),
          if (widget.isPrincipalAdmin) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRoleChangeDialog(user),
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(
                      'admin_management.change_role'.tr(),
                      style: GoogleFonts.inter(fontSize: 12.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleUserStatus(user['id'], isActive),
                    icon: Icon(isActive ? Icons.block : Icons.check_circle,
                        size: 16),
                    label: Text(
                      isActive
                          ? 'admin_discipline.deactivate'.tr()
                          : 'common.active'.tr(),
                      style: GoogleFonts.inter(fontSize: 12.sp),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () => _showPasspartoutDialog(user),
                  icon: Icon(
                    Icons.key,
                    color: user['booking_passpartout'] == true
                        ? Colors.amber
                        : Colors.grey.shade500,
                  ),
                  tooltip: user['booking_passpartout'] == true
                      ? 'Passpartout ATTIVO'
                      : 'Passpartout disattivo',
                  style: IconButton.styleFrom(
                    backgroundColor: user['booking_passpartout'] == true
                        ? Colors.amber.withAlpha(30)
                        : Colors.grey.shade200,
                    foregroundColor: user['booking_passpartout'] == true
                        ? Colors.amber
                        : Colors.grey.shade700,
                  ),
                ),
                SizedBox(width: 8.w),
                IconButton(
                  onPressed: () => _showUserDetailsDialog(user),
                  icon: const Icon(Icons.info_outline),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRoleChangeDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cambia Ruolo Utente',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Utente: ${user['full_name']}'),
            SizedBox(height: 8.h),
            Text('Ruolo attuale: ${_getRoleDisplayName(user['role'])}'),
            SizedBox(height: 16.h),
            Text('admin_management.select_new_role'.tr()),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              children: [
                'student',
                'instructor',
                'admin',
                'instructor_admin',
                'principal_admin'
              ]
                  .map((role) => FilterChip(
                        label: Text(_getRoleDisplayName(role)),
                        onSelected: (selected) {
                          if (selected) {
                            Navigator.pop(context);
                            _updateUserRole(user['id'], role);
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'admin_management.user_details'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('profile.first_name'.tr(), user['full_name']),
              _buildDetailRow('common.email'.tr(), user['email']),
              _buildDetailRow('profile.phone'.tr(),
                  user['phone'] ?? 'profile.phone_not_provided'.tr()),
              _buildDetailRow(
                  'profile.role'.tr(), _getRoleDisplayName(user['role'])),
              _buildDetailRow(
                  'common.status'.tr(),
                  user['is_active']
                      ? 'common.active'.tr()
                      : 'common.inactive'.tr()),
              _buildDetailRow(
                  'admin_management.creation_date'.tr(),
                  user['created_at'] != null
                      ? DateTime.parse(user['created_at'])
                          .toLocal()
                          .toString()
                          .split('.')[0]
                      : 'N/A'),
              _buildDetailRow('profile.medical_certificate'.tr(),
                  user['medical_certificate_status'] ?? 'Pending'),
              if (user['emergency_contact'] != null)
                _buildDetailRow(
                    'Contatto Emergenza', user['emergency_contact']),
              if (user['emergency_phone'] != null)
                _buildDetailRow('Tel. Emergenza', user['emergency_phone']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: GoogleFonts.inter(fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'principal_admin':
        return Colors.red;
      case 'admin':
        return Colors.blue;
      case 'instructor_admin':
        return Colors.purple;
      case 'instructor':
        return Colors.green;
      case 'student':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String? role) {
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
        return 'dashboard.role_student'.tr();
      default:
        return role ?? 'Sconosciuto';
    }
  }
}
