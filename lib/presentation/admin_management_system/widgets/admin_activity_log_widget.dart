import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/supabase_service.dart';

class AdminActivityLogWidget extends StatefulWidget {
  const AdminActivityLogWidget({super.key});

  @override
  State<AdminActivityLogWidget> createState() => _AdminActivityLogWidgetState();
}

class _AdminActivityLogWidgetState extends State<AdminActivityLogWidget> {
  List<Map<String, dynamic>> _activityLogs = [];
  bool _isLoading = true;
  String _filterAction = 'all';
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  @override
  void initState() {
    super.initState();
    _loadActivityLogs();
  }

  Future<void> _loadActivityLogs() async {
    try {
      setState(() => _isLoading = true);

      final client = SupabaseService.instance.client;

      var query = client.from('admin_activity_log').select(
            '*, admin:user_profiles!admin_activity_log_admin_id_fkey(full_name)',
          );

      // Apply action filter
      if (_filterAction != 'all') {
        query = query.eq('action_type', _filterAction);
      }

      // Apply date filters
      if (_filterDateFrom != null) {
        query = query.gte('created_at', _filterDateFrom!.toIso8601String());
      }
      if (_filterDateTo != null) {
        final endDate = _filterDateTo!.add(const Duration(days: 1));
        query = query.lt('created_at', endDate.toIso8601String());
      }

      final response =
          await query.order('created_at', ascending: false).limit(100);

      setState(() {
        _activityLogs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('admin_management.activity_log_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _filterDateFrom != null && _filterDateTo != null
          ? DateTimeRange(start: _filterDateFrom!, end: _filterDateTo!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _filterDateFrom = picked.start;
        _filterDateTo = picked.end;
      });
      _loadActivityLogs();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _filterDateFrom = null;
      _filterDateTo = null;
    });
    _loadActivityLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters
        Container(
          padding: EdgeInsets.all(16.sp),
          child: Column(
            children: [
              // Action filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Tutte', Colors.grey),
                    SizedBox(width: 8.w),
                    _buildFilterChip(
                      'USER_PROMOTION',
                      'Promozioni',
                      Colors.green,
                    ),
                    SizedBox(width: 8.w),
                    _buildFilterChip(
                      'REGISTRATION_APPROVED',
                      'Approvazioni',
                      Colors.blue,
                    ),
                    SizedBox(width: 8.w),
                    _buildFilterChip(
                      'REGISTRATION_REJECTED',
                      'Rifiuti',
                      Colors.red,
                    ),
                    SizedBox(width: 8.w),
                    _buildFilterChip(
                      'BULK_ROLE_CHANGE',
                      'Op. Massa',
                      Colors.purple,
                    ),
                    SizedBox(width: 8.w),
                    _buildFilterChip(
                      'SYSTEM_INITIALIZATION',
                      'Sistema',
                      Colors.orange,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Date filter
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _filterDateFrom != null && _filterDateTo != null
                            ? '${_formatDate(_filterDateFrom!)} - ${_formatDate(_filterDateTo!)}'
                            : 'Seleziona periodo',
                        style: GoogleFonts.inter(fontSize: 12.sp),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _filterDateFrom != null
                            ? AppTheme.lightTheme.primaryColor.withAlpha(26)
                            : Colors.grey[200],
                        foregroundColor: _filterDateFrom != null
                            ? AppTheme.lightTheme.primaryColor
                            : Colors.grey[600],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (_filterDateFrom != null) ...[
                    SizedBox(width: 8.w),
                    IconButton(
                      onPressed: _clearDateFilter,
                      icon: const Icon(Icons.clear, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(26),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Activity logs list
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.lightTheme.primaryColor,
                  ),
                )
              : _activityLogs.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: AppTheme.lightTheme.primaryColor,
                      onRefresh: _loadActivityLogs,
                      child: ListView.separated(
                        padding: EdgeInsets.all(16.sp),
                        itemCount: _activityLogs.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final log = _activityLogs[index];
                          return _buildActivityLogCard(log);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String action, String label, Color color) {
    final isSelected = _filterAction == action;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : color,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filterAction = action);
          _loadActivityLogs();
        }
      },
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: color.withAlpha(26),
      side: BorderSide(color: color),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text(
            'common.no_activity'.tr(),
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'admin_dashboard.activity_empty_subtitle'.tr(),
            style: GoogleFonts.inter(fontSize: 14.sp, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLogCard(Map<String, dynamic> log) {
    final actionType = log['action_type'] as String;
    final createdAt = DateTime.parse(log['created_at'] as String);
    final admin = log['admin'] as Map<String, dynamic>?;
    final adminName = admin?['full_name'] ?? 'Admin sconosciuto';

    final actionInfo = _getActionInfo(actionType);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with action type and timestamp
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: actionInfo['color'].withAlpha(26),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: actionInfo['color'].withAlpha(77),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        actionInfo['icon'],
                        size: 14,
                        color: actionInfo['color'],
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        actionInfo['label'],
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: actionInfo['color'],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Admin info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.lightTheme.primaryColor.withAlpha(
                    26,
                  ),
                  radius: 16,
                  child: Text(
                    adminName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightTheme.primaryColor,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    adminName,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Description
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.sp),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                log['description'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ),

            // Target user info if available
            if (log['target_email'] != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.sp),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue, size: 16),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (log['target_email'] != null) ...[
                            Text(
                              'Utente: ${log['target_email']}',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                          if (log['old_role'] != null &&
                              log['new_role'] != null) ...[
                            Text(
                              'Ruolo: ${_formatRole(log['old_role'])} → ${_formatRole(log['new_role'])}',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: Colors.blue[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Metadata if available
            if (log['metadata'] != null) ...[
              SizedBox(height: 8.h),
              ExpansionTile(
                title: Text(
                  'Dettagli aggiuntivi',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.sp),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log['metadata'].toString(),
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getActionInfo(String actionType) {
    switch (actionType) {
      case 'USER_PROMOTION':
        return {
          'label': 'Promozione',
          'color': Colors.green,
          'icon': Icons.trending_up,
        };
      case 'REGISTRATION_APPROVED':
        return {
          'label': 'Approvazione',
          'color': Colors.blue,
          'icon': Icons.check_circle,
        };
      case 'REGISTRATION_REJECTED':
        return {'label': 'Rifiuto', 'color': Colors.red, 'icon': Icons.cancel};
      case 'BULK_ROLE_CHANGE':
        return {
          'label': 'Op. Massa',
          'color': Colors.purple,
          'icon': Icons.people,
        };
      case 'SYSTEM_INITIALIZATION':
        return {
          'label': 'Sistema',
          'color': Colors.orange,
          'icon': Icons.settings,
        };
      default:
        return {
          'label': 'Altro',
          'color': Colors.grey,
          'icon': Icons.help_outline,
        };
    }
  }

  String _formatRole(String? role) {
    if (role == null) return 'N/A';
    switch (role) {
      case 'student':
        return 'dashboard.role_student'.tr();
      case 'instructor':
        return 'dashboard.role_instructor'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      case 'instructor_admin':
        return 'Istruttore/Amministratore';
      case 'principal_admin':
        return 'dashboard.role_principal_admin'.tr();
      default:
        return role;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
