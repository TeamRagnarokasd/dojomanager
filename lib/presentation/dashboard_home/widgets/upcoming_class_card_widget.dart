import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class UpcomingClassCardWidget extends StatelessWidget {
  final String className;
  final String instructor;
  final String instructorImage;
  final String time;
  final String date;
  final String location;
  final int spotsLeft;
  final bool isBooked;
  final VoidCallback? onBook;
  final VoidCallback? onDetails;
  final VoidCallback? onAddToCalendar;

  const UpcomingClassCardWidget({
    super.key,
    required this.className,
    required this.instructor,
    required this.instructorImage,
    required this.time,
    required this.date,
    required this.location,
    required this.spotsLeft,
    required this.isBooked,
    this.onBook,
    this.onDetails,
    this.onAddToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 75.w,
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
      child: Slidable(
        key: ValueKey(className),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) => onBook?.call(),
              backgroundColor:
                  isBooked ? AppTheme.successLight : AppTheme.primaryLight,
              foregroundColor: AppTheme.onPrimaryLight,
              icon: isBooked ? Icons.check_circle : Icons.book_online,
              label: isBooked ? 'Prenotato' : 'Prenota',
              borderRadius: BorderRadius.circular(12),
            ),
            SlidableAction(
              onPressed: (context) => onDetails?.call(),
              backgroundColor: AppTheme.secondaryLight,
              foregroundColor: AppTheme.onSecondaryLight,
              icon: Icons.info_outline,
              label: 'Dettagli',
              borderRadius: BorderRadius.circular(12),
            ),
            SlidableAction(
              onPressed: (context) => onAddToCalendar?.call(),
              backgroundColor: AppTheme.warningLight,
              foregroundColor: AppTheme.onPrimaryLight,
              icon: Icons.calendar_today,
              label: 'Calendario',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.lightTheme.colorScheme.surface,
                  AppTheme.lightTheme.colorScheme.surface
                      .withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: CustomImageWidget(
                        imageUrl: instructorImage,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            instructor,
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                              color: AppTheme.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 2.w, vertical: 0.5.h),
                      decoration: BoxDecoration(
                        color: isBooked
                            ? AppTheme.successLight
                            : AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isBooked ? 'Prenotato' : 'Disponibile',
                        style:
                            AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.onPrimaryLight,
                          fontWeight: FontWeight.w500,
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
                      color: AppTheme.textSecondaryLight,
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      '$date • $time',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'location_on',
                      color: AppTheme.textSecondaryLight,
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      location,
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'people',
                          color: spotsLeft <= 2
                              ? AppTheme.errorLight
                              : AppTheme.successLight,
                          size: 16,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          '$spotsLeft posti rimasti',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: spotsLeft <= 2
                                ? AppTheme.errorLight
                                : AppTheme.successLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '← Scorri per azioni',
                      style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textDisabledLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
