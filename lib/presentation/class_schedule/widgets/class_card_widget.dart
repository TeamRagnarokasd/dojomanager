import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class ClassCardWidget extends StatelessWidget {
  final Map<String, dynamic> classData;
  final bool isBooked;
  final VoidCallback onTap;
  final VoidCallback onCancelBooking;

  const ClassCardWidget({
    Key? key,
    required this.classData,
    required this.isBooked,
    required this.onTap,
    required this.onCancelBooking,
  }) : super(key: key);

  Color _getDisciplineColor(BuildContext context, String type) {
    final theme = Theme.of(context);
    switch (type.toLowerCase()) {
      case 'bjj':
        return theme.primaryColor;
      case 'mma':
        return theme.colorScheme.error;
      case 'sambo':
        return const Color(0xFF2196F3);
      case 'grappling':
        return const Color(0xFF9C27B0);
      case 'prep. atletica':
      case 'fitness':
        return const Color(0xFFFF9800);
      default:
        return theme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = classData['type'] ?? 'BJJ';
    final instructor = classData['instructor'] ?? 'Istruttore Disponibile';
    final time = classData['time'] ?? '00:00 - 01:00';
    final location = classData['location'] ?? 'Palestra';
    final capacity = classData['capacity'] ?? 20;
    final enrolled = classData['enrolled'] ?? 0;
    final isCancelled =
        classData['is_cancelled'] ?? classData['isCancelled'] ?? false;
    final cancellationReason =
        classData['cancellation_reason'] ?? classData['cancellationReason'];
    final isModified =
        classData['is_modified'] ?? classData['isModified'] ?? false;
    final isHolidayAffected =
        classData['is_holiday_affected'] ??
        classData['isHolidayAffected'] ??
        false;

    final availableSpots = capacity - enrolled;
    final hasAvailableSpots = availableSpots > 0 && !isCancelled;
    final isFull = availableSpots <= 0 && !isCancelled;

    return GestureDetector(
      onTap: isCancelled ? null : onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color:
              isCancelled
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  )
                  : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border:
              isCancelled
                  ? Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                    width: 1,
                  )
                  : isModified
                  ? Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  )
                  : null,
          boxShadow:
              isCancelled
                  ? []
                  : [
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
            // Header with discipline badge and status badges
            Row(
              children: [
                // Discipline badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: _getDisciplineColor(
                      context,
                      type,
                    ).withValues(alpha: isCancelled ? 0.3 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    type,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: _getDisciplineColor(context, type),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 2.w),

                // Admin modification badges
                if (isCancelled)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: 'cancel',
                          color: theme.colorScheme.error,
                          size: 16,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Annullata',
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isModified)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: 'edit',
                          color: theme.primaryColor,
                          size: 14,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Modificata',
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isHolidayAffected)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: 'event_busy',
                          color: const Color(0xFFFF9800),
                          size: 14,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Festività',
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: const Color(0xFFFF9800),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Booking status badge
                if (!isCancelled && isBooked)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: 'check_circle',
                          color: theme.colorScheme.tertiary,
                          size: 16,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          'Prenotato',
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Cancellation reason (if cancelled)
            if (isCancelled &&
                cancellationReason != null &&
                cancellationReason.toString().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 1.h),
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'info',
                        color: theme.colorScheme.error,
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'Motivo: $cancellationReason',
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 2.h),

            // Instructor and time info
            Row(
              children: [
                CustomIconWidget(
                  iconName: 'person',
                  color:
                      isCancelled
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          )
                          : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    instructor,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          isCancelled
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              )
                              : theme.colorScheme.onSurface,
                      decoration:
                          isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 1.h),

            // Time and location
            Row(
              children: [
                CustomIconWidget(
                  iconName: 'schedule',
                  color:
                      isCancelled
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          )
                          : theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                SizedBox(width: 2.w),
                Text(
                  time,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color:
                        isCancelled
                            ? theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            )
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: 4.w),
                CustomIconWidget(
                  iconName: 'location_on',
                  color:
                      isCancelled
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          )
                          : theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    location,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color:
                          isCancelled
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              )
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 2.h),

            // Availability info and action button
            if (!isCancelled)
              Row(
                children: [
                  // Availability indicator
                  Expanded(
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: hasAvailableSpots ? 'people' : 'group',
                          color:
                              hasAvailableSpots
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.error,
                          size: 20,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          hasAvailableSpots
                              ? '$availableSpots posti disponibili'
                              : 'Classe piena',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color:
                                hasAvailableSpots
                                    ? theme.colorScheme.tertiary
                                    : theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action button - ENHANCED VISIBILITY
                  if (isBooked)
                    TextButton(
                      onPressed: onCancelBooking,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 1.2.h,
                        ),
                      ),
                      child: const Text('Cancella'),
                    )
                  else if (hasAvailableSpots)
                    ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.event_available, size: 20),
                      label: const Text(
                        'Prenota',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 5.w,
                          vertical: 1.5.h,
                        ),
                        elevation: 3,
                        shadowColor: Colors.red.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
