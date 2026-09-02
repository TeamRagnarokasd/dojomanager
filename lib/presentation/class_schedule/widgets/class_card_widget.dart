import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

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

  /// Parse a hex color string (e.g. '#D32F2F' or 'D32F2F') to a Flutter Color.
  /// Falls back to grey if the string is invalid.
  Color _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF757575);
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF757575);
  }

  /// Returns the discipline color: prefers the hex from classData['discipline_color'],
  /// falls back to a hardcoded map keyed on the discipline name.
  Color _getDisciplineColor(String type) {
    final hexFromData = classData['discipline_color']?.toString();
    if (hexFromData != null && hexFromData.isNotEmpty) {
      return _parseHexColor(hexFromData);
    }
    // Fallback for legacy data without discipline_color
    switch (type.toLowerCase()) {
      case 'bjj':
        return const Color(0xFF1565C0);
      case 'mma':
        return const Color(0xFFD32F2F);
      case 'sambo':
        return const Color(0xFF1976D2);
      case 'grappling':
        return const Color(0xFF7B1FA2);
      case 'prep. atletica':
      case 'preparazione atletica':
      case 'fitness':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF757575);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawType = classData['type']?.toString().trim() ?? '';
    final type = rawType.isNotEmpty ? rawType : 'BJJ';
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

    final disciplineColor = _getDisciplineColor(type);

    return GestureDetector(
      onTap: isCancelled ? null : onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isCancelled
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: isCancelled
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
          boxShadow: isCancelled
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
                // Discipline badge — always visible with its own color
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 0.8.h,
                  ),
                  decoration: BoxDecoration(
                    color: disciplineColor.withValues(
                      alpha: isCancelled ? 0.15 : 0.18,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: disciplineColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    type,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: disciplineColor,
                      fontWeight: FontWeight.w700,
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
                          'class_schedule.status_cancelled'.tr(),
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
                          'class_schedule.status_modified'.tr(),
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
                          'class_schedule.status_holiday'.tr(),
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
                          'class_schedule.status_booked'.tr(),
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
                  color: isCancelled
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
                      color: isCancelled
                          ? theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            )
                          : theme.colorScheme.onSurface,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
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
                  color: isCancelled
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
                    color: isCancelled
                        ? theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          )
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: 4.w),
                CustomIconWidget(
                  iconName: 'location_on',
                  color: isCancelled
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
                      color: isCancelled
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
                          color: hasAvailableSpots
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.error,
                          size: 20,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          hasAvailableSpots
                              ? '$availableSpots posti disponibili'
                              : 'class_schedule.class_full_short'.tr(),
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: hasAvailableSpots
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action button
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
                      child: Text('common.cancel'.tr()),
                    )
                  else if (hasAvailableSpots)
                    ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.event_available, size: 20),
                      label: Text(
                        'class_schedule.book'.tr(),
                        style: const TextStyle(
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
