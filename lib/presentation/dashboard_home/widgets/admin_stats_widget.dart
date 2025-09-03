import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AdminStatsWidget extends StatelessWidget {
  final int totalStudents;
  final int activeInstructors;
  final int todayClasses;
  final String monthlyRevenue;
  final int pendingPayments;
  final int certificateExpirations;
  final VoidCallback? onViewStudents;
  final VoidCallback? onViewPayments;
  final VoidCallback? onViewCertificates;

  const AdminStatsWidget({
    super.key,
    required this.totalStudents,
    required this.activeInstructors,
    required this.todayClasses,
    required this.monthlyRevenue,
    required this.pendingPayments,
    required this.certificateExpirations,
    this.onViewStudents,
    this.onViewPayments,
    this.onViewCertificates,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main Stats Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 3.w,
          mainAxisSpacing: 2.h,
          childAspectRatio: 1.5,
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          children: [
            _buildStatCard(
              title: 'Studenti Totali',
              value: totalStudents.toString(),
              icon: 'school',
              color: AppTheme.primaryLight,
              onTap: onViewStudents,
            ),
            _buildStatCard(
              title: 'Istruttori Attivi',
              value: activeInstructors.toString(),
              icon: 'person',
              color: AppTheme.successLight,
            ),
            _buildStatCard(
              title: 'Lezioni Oggi',
              value: todayClasses.toString(),
              icon: 'today',
              color: AppTheme.warningLight,
            ),
            _buildStatCard(
              title: 'Ricavi Mensili',
              value: monthlyRevenue,
              icon: 'euro',
              color: AppTheme.secondaryLight,
            ),
          ],
        ),
        SizedBox(height: 3.h),
        // Alert Cards
        if (pendingPayments > 0 || certificateExpirations > 0) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              'Richiede Attenzione',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryLight,
              ),
            ),
          ),
          SizedBox(height: 1.h),
        ],
        if (pendingPayments > 0)
          _buildAlertCard(
            title: 'Pagamenti in Sospeso',
            value: pendingPayments.toString(),
            description: 'studenti con pagamenti scaduti',
            icon: 'payment',
            color: AppTheme.errorLight,
            onTap: onViewPayments,
          ),
        if (certificateExpirations > 0)
          _buildAlertCard(
            title: 'Certificati in Scadenza',
            value: certificateExpirations.toString(),
            description: 'certificati medici da rinnovare',
            icon: 'medical_services',
            color: AppTheme.warningLight,
            onTap: onViewCertificates,
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
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
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomIconWidget(
                      iconName: icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  if (onTap != null)
                    CustomIconWidget(
                      iconName: 'arrow_forward_ios',
                      color: AppTheme.textSecondaryLight,
                      size: 16,
                    ),
                ],
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                title,
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String value,
    required String description,
    required String icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(4.w),
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
                        children: [
                          Text(
                            value,
                            style: AppTheme.lightTheme.textTheme.titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            title,
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        description,
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomIconWidget(
                  iconName: 'arrow_forward_ios',
                  color: AppTheme.textSecondaryLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
