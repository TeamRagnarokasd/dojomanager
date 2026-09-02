import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_export.dart';
import '../../../theme/app_theme.dart';

class ActivityLogWidget extends StatelessWidget {
  final List<dynamic> activities;

  const ActivityLogWidget({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10.0,
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
                  color: Colors.indigo.withAlpha(26),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(
                  Icons.history,
                  color: Colors.indigo,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log delle Attività',
                      style: GoogleFonts.inter(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'Tracciamento azioni amministrative',
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
                  color: Colors.indigo.withAlpha(26),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Text(
                  '${activities.length} attività',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Vengono mostrate le ultime 20 attività con timestamp e attribuzione utente',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          activities.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: activities
                      .map((activity) => _buildActivityCard(activity))
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
            Icons.history_edu,
            size: 48.sp,
            color: Colors.grey.withAlpha(128),
          ),
          SizedBox(height: 16.h),
          Text(
            'Nessuna attività registrata',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryLight,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Le attività amministrative appariranno qui una volta registrate',
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

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final userProfile = activity['user_profiles'] ?? {};
    final timestamp =
        _formatTimestamp(activity['created_at'] ?? activity['timestamp']);
    final actionIcon = _getActionIcon(activity['action']);
    final actionColor = _getActionColor(activity['action']);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: actionColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Icon(
                  actionIcon,
                  color: actionColor,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['action'] ?? 'Azione sconosciuta',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryLight,
                      ),
                    ),
                    Text(
                      'da ${userProfile['full_name'] ?? 'Utente sconosciuto'}',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                timestamp,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (activity['details'] != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dettagli:',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  ..._buildActivityDetails(activity['details']),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActivityDetails(dynamic details) {
    final widgets = <Widget>[];

    if (details is Map) {
      details.forEach((key, value) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80.w,
                  child: Text(
                    '$key:',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
    } else {
      widgets.add(
        Text(
          details.toString(),
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: AppTheme.textPrimaryLight,
          ),
        ),
      );
    }

    return widgets;
  }

  IconData _getActionIcon(String? action) {
    if (action == null) return Icons.help_outline;

    if (action.toLowerCase().contains('approv')) {
      return Icons.check_circle;
    } else if (action.toLowerCase().contains('reject') ||
        action.toLowerCase().contains('respint')) {
      return Icons.cancel;
    } else if (action.toLowerCase().contains('promot') ||
        action.toLowerCase().contains('promoss')) {
      return Icons.trending_up;
    } else if (action.toLowerCase().contains('login') ||
        action.toLowerCase().contains('accesso')) {
      return Icons.login;
    } else if (action.toLowerCase().contains('logout') ||
        action.toLowerCase().contains('uscita')) {
      return Icons.logout;
    } else if (action.toLowerCase().contains('creat') ||
        action.toLowerCase().contains('crea')) {
      return Icons.add_circle;
    } else if (action.toLowerCase().contains('delet') ||
        action.toLowerCase().contains('elimin')) {
      return Icons.delete;
    } else if (action.toLowerCase().contains('updat') ||
        action.toLowerCase().contains('aggiorn')) {
      return Icons.edit;
    } else {
      return Icons.info;
    }
  }

  Color _getActionColor(String? action) {
    if (action == null) return Colors.grey;

    if (action.toLowerCase().contains('approv')) {
      return Colors.green;
    } else if (action.toLowerCase().contains('reject') ||
        action.toLowerCase().contains('respint')) {
      return Colors.red;
    } else if (action.toLowerCase().contains('promot') ||
        action.toLowerCase().contains('promoss')) {
      return Colors.blue;
    } else if (action.toLowerCase().contains('login') ||
        action.toLowerCase().contains('accesso')) {
      return Colors.green;
    } else if (action.toLowerCase().contains('logout') ||
        action.toLowerCase().contains('uscita')) {
      return Colors.orange;
    } else if (action.toLowerCase().contains('creat') ||
        action.toLowerCase().contains('crea')) {
      return Colors.green;
    } else if (action.toLowerCase().contains('delet') ||
        action.toLowerCase().contains('elimin')) {
      return Colors.red;
    } else if (action.toLowerCase().contains('updat') ||
        action.toLowerCase().contains('aggiorn')) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Data sconosciuta';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Ora';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}min fa';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h fa';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}g fa';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Data non valida';
    }
  }
}
