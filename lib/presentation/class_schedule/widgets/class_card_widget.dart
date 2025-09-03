import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class ClassCardWidget extends StatelessWidget {
  final Map<String, dynamic> classData;
  final VoidCallback onTap;
  final VoidCallback? onCancelBooking;
  final bool isBooked;

  const ClassCardWidget({
    Key? key,
    required this.classData,
    required this.onTap,
    this.onCancelBooking,
    this.isBooked = false,
  }) : super(key: key);

  Color _getClassTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'karate':
        return const Color(0xFF2196F3); // Blue
      case 'judo':
        return const Color(0xFF4CAF50); // Green
      case 'taekwondo':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9C27B0); // Purple as default color
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classType = classData['type'] as String? ?? '';
    final instructor = classData['instructor'] as String? ?? '';
    final time = classData['time'] as String? ?? '';
    final capacity = classData['capacity'] as int? ?? 0;
    final enrolled = classData['enrolled'] as int? ?? 0;
    final isAvailable = enrolled < capacity;
    final waitlistPosition = classData['waitlistPosition'] as int?;

    return Dismissible(
      key: Key('class_${classData['id']}'),
      direction: isBooked ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'delete',
              color: theme.colorScheme.onError,
              size: 24,
            ),
            SizedBox(height: 0.5.h),
            Text(
              'Cancella\nPrenotazione',
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onError,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      onDismissed: (direction) {
        if (onCancelBooking != null) {
          onCancelBooking!();
        }
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getClassTypeColor(classType).withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getClassTypeColor(classType),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      classType.toUpperCase(),
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isBooked)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PRENOTATO',
                        style: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'access_time',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    time,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'person',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      instructor,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'group',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    '$enrolled/$capacity posti',
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color:
                          isAvailable
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (waitlistPosition != null) ...[
                    SizedBox(width: 2.w),
                    Text(
                      '(Lista d\'attesa: $waitlistPosition)',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (!isAvailable && waitlistPosition == null)
                Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'warning',
                        color: theme.colorScheme.error,
                        size: 16,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Classe completa',
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 3.h),
                ListTile(
                  leading: CustomIconWidget(
                    iconName: 'notification_add',
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  title: Text(
                    'Aggiungi Promemoria',
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // Add reminder functionality
                  },
                ),
                ListTile(
                  leading: CustomIconWidget(
                    iconName: 'share',
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  title: Text('Condividi', style: theme.textTheme.titleMedium),
                  onTap: () {
                    Navigator.pop(context);
                    // Share functionality
                  },
                ),
                ListTile(
                  leading: CustomIconWidget(
                    iconName: 'person_outline',
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  title: Text(
                    'Visualizza Istruttore',
                    style: theme.textTheme.titleMedium,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // View instructor functionality
                  },
                ),
                SizedBox(height: 2.h),
              ],
            ),
          ),
    );
  }
}