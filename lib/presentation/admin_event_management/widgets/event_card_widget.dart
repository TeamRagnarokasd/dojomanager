import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class EventCardWidget extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onViewAttendees;
  final VoidCallback onToggleStatus;

  const EventCardWidget({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onViewAttendees,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = event['status'] == 'active';
    final priorityColor = _getPriorityColor(event['priority']);
    final occupancyRate = (event['registered'] / event['capacity']) * 100;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      child: Card(
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: priorityColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image and priority indicator
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CustomImageWidget(
                    imageUrl: event['image'],
                    height: 20.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 3.w,
                  right: 3.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      event['priority'].toUpperCase(),
                      style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 3.w,
                  left: 3.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.successLight
                          : AppTheme.errorLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'ATTIVO' : 'INATTIVO',
                      style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Event content
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and type
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.w, vertical: 0.5.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event['type'].toUpperCase(),
                          style: AppTheme.lightTheme.textTheme.labelSmall
                              ?.copyWith(
                            color: const Color(0xFFFF0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 2.w, vertical: 0.5.w),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event['category'],
                          style: AppTheme.lightTheme.textTheme.labelSmall
                              ?.copyWith(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.w),

                  // Event title
                  Text(
                    event['title'],
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1.5.w),

                  // Event details row
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'schedule',
                        color: Colors.grey[400]!,
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${_formatDate(event['date'])} • ${event['time']}',
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.w),

                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'person',
                        color: Colors.grey[400]!,
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        event['instructor'],
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.w),

                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'location_on',
                        color: Colors.grey[400]!,
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        event['venue'],
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.w),

                  // Registration status
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Iscrizioni: ${event['registered']}/${event['capacity']}',
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 1.w),
                            LinearProgressIndicator(
                              value: occupancyRate / 100,
                              backgroundColor: Colors.grey[700],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                occupancyRate > 80
                                    ? AppTheme.errorLight
                                    : occupancyRate > 60
                                        ? AppTheme.warningLight
                                        : AppTheme.successLight,
                              ),
                              minHeight: 0.5.h,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '€${event['price'].toStringAsFixed(0)}',
                        style:
                            AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFFF0000),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.w),

                  // Action buttons
                  Row(
                    children: [
                      _buildActionButton(
                        icon: 'edit',
                        label: 'profile.modify'.tr(),
                        onTap: onEdit,
                      ),
                      SizedBox(width: 2.w),
                      _buildActionButton(
                        icon: 'copy',
                        label: 'Duplica',
                        onTap: onDuplicate,
                      ),
                      SizedBox(width: 2.w),
                      _buildActionButton(
                        icon: 'group',
                        label: 'class_schedule.participants'.tr(),
                        onTap: onViewAttendees,
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        color: Colors.grey[800],
                        icon: CustomIconWidget(
                          iconName: 'more_vert',
                          color: Colors.grey[400]!,
                          size: 20,
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'toggle_status':
                              onToggleStatus();
                              break;
                            case 'delete':
                              onDelete();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle_status',
                            child: Row(
                              children: [
                                CustomIconWidget(
                                  iconName: isActive ? 'pause' : 'play_arrow',
                                  color: Colors.grey[300]!,
                                  size: 18,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  isActive
                                      ? 'admin_discipline.deactivate'.tr()
                                      : 'common.active'.tr(),
                                  style: TextStyle(color: Colors.grey[300]),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                CustomIconWidget(
                                  iconName: 'delete',
                                  color: AppTheme.errorLight,
                                  size: 18,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  'common.delete'.tr(),
                                  style: TextStyle(color: AppTheme.errorLight),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.w),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomIconWidget(
              iconName: icon,
              color: Colors.grey[300]!,
              size: 16,
            ),
            SizedBox(width: 1.w),
            Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[300],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppTheme.errorLight;
      case 'medium':
        return AppTheme.warningLight;
      case 'low':
        return AppTheme.successLight;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return 'Oggi';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'Domani';
    } else {
      final months = [
        '',
        'Gen',
        'Feb',
        'Mar',
        'Apr',
        'Mag',
        'Giu',
        'Lug',
        'Ago',
        'Set',
        'Ott',
        'Nov',
        'Dic'
      ];
      return '${date.day} ${months[date.month]}';
    }
  }
}
