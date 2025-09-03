import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class InstructorClassWidget extends StatelessWidget {
  final String className;
  final String time;
  final int studentCount;
  final int maxStudents;
  final String location;
  final bool attendanceMarked;
  final VoidCallback? onMarkAttendance;
  final VoidCallback? onViewStudents;

  const InstructorClassWidget({
    super.key,
    required this.className,
    required this.time,
    required this.studentCount,
    required this.maxStudents,
    required this.location,
    required this.attendanceMarked,
    this.onMarkAttendance,
    this.onViewStudents,
  });

  @override
  Widget build(BuildContext context) {
    final double occupancyRate = studentCount / maxStudents;

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style:
                            AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 0.5.h),
                      Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'access_time',
                            color: AppTheme.textSecondaryLight,
                            size: 16,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            time,
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: attendanceMarked
                        ? AppTheme.successLight
                        : AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    attendanceMarked ? 'Presenze Segnate' : 'In Attesa',
                    style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Studenti',
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                          Text(
                            '$studentCount/$maxStudents',
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: AppTheme.textPrimaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      LinearProgressIndicator(
                        value: occupancyRate,
                        backgroundColor: AppTheme.dividerLight,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          occupancyRate >= 0.8
                              ? AppTheme.errorLight
                              : occupancyRate >= 0.6
                                  ? AppTheme.warningLight
                                  : AppTheme.successLight,
                        ),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewStudents,
                    icon: CustomIconWidget(
                      iconName: 'people',
                      color: AppTheme.primaryLight,
                      size: 18,
                    ),
                    label: Text(
                      'Vedi Studenti',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.primaryLight,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: attendanceMarked ? null : onMarkAttendance,
                    icon: CustomIconWidget(
                      iconName:
                          attendanceMarked ? 'check_circle' : 'how_to_reg',
                      color: attendanceMarked
                          ? AppTheme.textDisabledLight
                          : AppTheme.onPrimaryLight,
                      size: 18,
                    ),
                    label: Text(
                      attendanceMarked ? 'Completato' : 'Segna Presenze',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: attendanceMarked
                            ? AppTheme.textDisabledLight
                            : AppTheme.onPrimaryLight,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: attendanceMarked
                          ? AppTheme.dividerLight
                          : AppTheme.primaryLight,
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
