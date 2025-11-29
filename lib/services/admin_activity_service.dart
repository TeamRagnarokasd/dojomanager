import 'package:flutter/material.dart';
import './supabase_service.dart';

class AdminActivityService {
  static final AdminActivityService _instance =
      AdminActivityService._internal();
  factory AdminActivityService() => _instance;
  AdminActivityService._internal();

  static AdminActivityService get instance => _instance;

  /// Fetch recent activity data from Supabase database
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) async {
    try {
      final client = SupabaseService.instance.client;

      // Get recent admin activities - without joins to avoid auth.users permission issues
      final adminActivities = await client
          .from('admin_activity_log')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      // Get recent pending registrations - without joins to avoid auth.users permission issues
      final pendingRegistrations = await client
          .from('pending_registrations')
          .select('*')
          .order('created_at', ascending: false)
          .limit(5);

      // Get recent user registrations (approved in last 24h)
      final recentUsers = await client
          .from('user_profiles')
          .select('*')
          .eq('is_active', true)
          .not('approved_at', 'is', null)
          .gte(
            'approved_at',
            DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
          )
          .order('approved_at', ascending: false)
          .limit(3);

      List<Map<String, dynamic>> activities = [];

      // Process admin activities
      for (var activity in adminActivities) {
        // Fetch admin name separately if admin_id exists
        String actorName = 'Sistema';
        if (activity['admin_id'] != null) {
          try {
            final adminProfile =
                await client
                    .from('user_profiles')
                    .select('full_name')
                    .eq('id', activity['admin_id'])
                    .maybeSingle();
            actorName = adminProfile?['full_name'] ?? 'Admin';
          } catch (e) {
            print('Could not fetch admin name: $e');
          }
        }

        activities.add({
          'id': activity['id'],
          'action': _getActionTitle(activity['action_type']),
          'description': activity['description'],
          'actor': actorName,
          'timestamp': DateTime.parse(activity['created_at']),
          'icon': _getActionIcon(activity['action_type']),
          'color': _getActionColor(activity['action_type']),
          'type': _getActionType(activity['action_type']),
          'metadata': activity['metadata'],
        });
      }

      // Process pending registrations
      for (var registration in pendingRegistrations) {
        if (registration['status'] == 'pending') {
          activities.add({
            'id': registration['id'],
            'action': 'Nuova Registrazione',
            'description':
                '${registration['full_name']} ha richiesto registrazione come ${_getRoleDisplayName(registration['requested_role'])}',
            'actor': 'Sistema',
            'timestamp': DateTime.parse(registration['created_at']),
            'icon': _getRegistrationIcon(),
            'color': _getRegistrationColor(),
            'type': 'registration',
            'metadata': {'email': registration['email']},
          });
        }
      }

      // Process recent approved users
      for (var user in recentUsers) {
        activities.add({
          'id': user['id'],
          'action': 'Utente Approvato',
          'description':
              '${user['full_name']} è stato approvato come ${_getRoleDisplayName(user['role'])}',
          'actor': 'Admin',
          'timestamp': DateTime.parse(user['approved_at']),
          'icon': _getApprovalIcon(),
          'color': _getApprovalColor(),
          'type': 'approval',
          'metadata': {'email': user['email']},
        });
      }

      // Sort all activities by timestamp (newest first)
      activities.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      // Return limited results
      return activities.take(limit).toList();
    } catch (error) {
      print('Error fetching admin activity: $error');
      // Return fallback mock data on error
      return _getFallbackActivities();
    }
  }

  /// Get activity statistics for dashboard
  Future<Map<String, int>> getActivityStats() async {
    try {
      final client = SupabaseService.instance.client;

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final weekStart = today.subtract(Duration(days: 7));

      // Get today's activities count
      final todayActivities = await client
          .from('admin_activity_log')
          .select('id')
          .gte('created_at', todayStart.toIso8601String());
      final todayCount = (todayActivities as List).length;

      // Get week's activities count
      final weekActivities = await client
          .from('admin_activity_log')
          .select('id')
          .gte('created_at', weekStart.toIso8601String());
      final weekCount = (weekActivities as List).length;

      // Get pending registrations count
      final pendingList = await client
          .from('pending_registrations')
          .select('id')
          .eq('status', 'pending');
      final pendingCount = (pendingList as List).length;

      return {'today': todayCount, 'week': weekCount, 'pending': pendingCount};
    } catch (error) {
      print('Error fetching activity stats: $error');
      return {'today': 0, 'week': 0, 'pending': 0};
    }
  }

  // Helper methods for UI mapping
  String _getActionTitle(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'user_approval':
        return 'Approvazione Utente';
      case 'user_rejection':
        return 'Rifiuto Utente';
      case 'role_change':
        return 'Cambio Ruolo';
      case 'user_suspension':
        return 'Sospensione Utente';
      case 'user_activation':
        return 'Attivazione Utente';
      case 'system_backup':
        return 'Backup Sistema';
      case 'data_export':
        return 'Esportazione Dati';
      default:
        return 'Azione Admin';
    }
  }

  dynamic _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'user_approval':
        return Icons.verified_user;
      case 'user_rejection':
        return Icons.block;
      case 'role_change':
        return Icons.admin_panel_settings;
      case 'user_suspension':
        return Icons.pause_circle;
      case 'user_activation':
        return Icons.play_circle;
      case 'system_backup':
        return Icons.backup;
      case 'data_export':
        return Icons.download;
      default:
        return Icons.admin_panel_settings;
    }
  }

  dynamic _getActionColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'user_approval':
        return Colors.green;
      case 'user_rejection':
        return Colors.red;
      case 'role_change':
        return Colors.blue;
      case 'user_suspension':
        return Colors.orange;
      case 'user_activation':
        return Colors.teal;
      case 'system_backup':
        return Colors.purple;
      case 'data_export':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _getActionType(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'user_approval':
      case 'user_rejection':
        return 'approval';
      case 'role_change':
      case 'user_suspension':
      case 'user_activation':
        return 'user_management';
      case 'system_backup':
      case 'data_export':
        return 'system';
      default:
        return 'admin';
    }
  }

  dynamic _getRegistrationIcon() => Icons.person_add;
  dynamic _getRegistrationColor() => Colors.blue;

  dynamic _getApprovalIcon() => Icons.check_circle;
  dynamic _getApprovalColor() => Colors.green;

  String _getRoleDisplayName(String? role) {
    switch (role?.toLowerCase()) {
      case 'student':
        return 'Studente';
      case 'instructor':
        return 'Istruttore';
      case 'admin':
        return 'Amministratore';
      case 'instructor_admin':
        return 'Istruttore Admin';
      case 'principal_admin':
        return 'Admin Principale';
      default:
        return 'Utente';
    }
  }

  /// Fallback mock data for errors
  List<Map<String, dynamic>> _getFallbackActivities() {
    return [
      {
        'id': '1',
        'action': 'Nessuna Attività',
        'description': 'Non ci sono attività recenti da visualizzare',
        'actor': 'Sistema',
        'timestamp': DateTime.now(),
        'icon': Icons.info_outline,
        'color': Colors.grey,
        'type': 'info',
        'metadata': {},
      },
    ];
  }
}
