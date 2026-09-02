import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RecentActivityWidget extends StatelessWidget {
  final VoidCallback? onRefresh;

  const RecentActivityWidget({
    super.key,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> recentActivities = [
      {
        "id": 1,
        "type": "booking",
        "title": "Nuova prenotazione",
        "description": "Marco ha prenotato Karate Principianti",
        "timestamp": DateTime.now().subtract(const Duration(minutes: 15)),
        "icon": "book_online",
        "color": AppTheme.primaryLight,
        "actionable": true,
      },
      {
        "id": 2,
        "type": "payment",
        "title": "Pagamento ricevuto",
        "description": "Anna Rossi - Abbonamento mensile €80",
        "timestamp": DateTime.now().subtract(const Duration(hours: 2)),
        "icon": "payment",
        "color": AppTheme.successLight,
        "actionable": false,
      },
      {
        "id": 3,
        "type": "certificate",
        "title": "Certificato caricato",
        "description": "Luigi Verdi ha caricato il certificato medico",
        "timestamp": DateTime.now().subtract(const Duration(hours: 4)),
        "icon": "medical_services",
        "color": AppTheme.warningLight,
        "actionable": true,
      },
      {
        "id": 4,
        "type": "class",
        "title": "Lezione completata",
        "description": "Judo Avanzato - 8 studenti presenti",
        "timestamp": DateTime.now().subtract(const Duration(days: 1)),
        "icon": "check_circle",
        "color": AppTheme.successLight,
        "actionable": false,
      },
      {
        "id": 5,
        "type": "registration",
        "title": "Nuovo studente",
        "description": "Sofia Bianchi si è registrata",
        "timestamp": DateTime.now().subtract(const Duration(days: 2)),
        "icon": "person_add",
        "color": AppTheme.primaryLight,
        "actionable": true,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Attività Recenti",
                style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomIconWidget(
                    iconName: 'refresh',
                    color: AppTheme.primaryLight,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          itemCount: recentActivities.length,
          itemBuilder: (context, index) {
            final activity = recentActivities[index];
            return _buildActivityItem(
              context,
              activity["title"] as String,
              activity["description"] as String,
              activity["timestamp"] as DateTime,
              activity["icon"] as String,
              activity["color"] as Color,
              activity["actionable"] as bool,
              () => _handleActivityTap(
                  activity["type"] as String, activity["id"] as int),
            );
          },
        ),
        SizedBox(height: 2.h),
        Center(
          child: Text(
            'Ultimo aggiornamento: ${_formatTimestamp(DateTime.now())}',
            style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textDisabledLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String description,
    DateTime timestamp,
    String icon,
    Color color,
    bool actionable,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: actionable ? onTap : null,
      onLongPress: actionable ? () => _showContextMenu(context, title) : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.dividerLight,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowLight,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomIconWidget(
                iconName: icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTheme.lightTheme.textTheme.titleSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style:
                            AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    description,
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (actionable) ...[
              SizedBox(width: 2.w),
              CustomIconWidget(
                iconName: 'arrow_forward_ios',
                color: AppTheme.textSecondaryLight,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m fa';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h fa';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}g fa';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showContextMenu(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: AppTheme.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              title,
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'visibility',
                color: AppTheme.primaryLight,
                size: 24,
              ),
              title: Text('dashboard.view_details'.tr()),
              onTap: () {
                Navigator.pop(context);
                // Handle view details
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'share',
                color: AppTheme.secondaryLight,
                size: 24,
              ),
              title: Text('common.share'.tr()),
              onTap: () {
                Navigator.pop(context);
                // Handle share
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'notifications',
                color: AppTheme.warningLight,
                size: 24,
              ),
              title: Text('dashboard.set_reminder'.tr()),
              onTap: () {
                Navigator.pop(context);
                // Handle reminder
              },
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  void _handleActivityTap(String type, int id) {
    switch (type) {
      case 'booking':
        // Navigate to booking details
        break;
      case 'payment':
        // Navigate to payment details
        break;
      case 'certificate':
        // Navigate to certificate review
        break;
      case 'registration':
        // Navigate to student profile
        break;
      default:
        break;
    }
  }
}
