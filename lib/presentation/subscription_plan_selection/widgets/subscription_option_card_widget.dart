import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SubscriptionOptionCardWidget extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isLocked;

  const SubscriptionOptionCardWidget({
    Key? key,
    required this.plan,
    required this.onTap,
    this.isLoading = false,
    this.isLocked = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final planColor =
        isLocked ? Colors.grey.shade700 : Color(plan['color'] as int);
    final isEntryBased = plan['entryBased'] ?? false;
    final entryCount = plan['entryCount'] ?? 0;

    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? Colors.grey.shade700.withValues(alpha: 0.4)
                : planColor.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: isLocked
              ? []
              : [
                  BoxShadow(
                    color: planColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Header with price and special badge
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: planColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isLocked
                            ? Icon(
                                Icons.lock,
                                color: Colors.grey.shade500,
                                size: 20,
                              )
                            : CustomIconWidget(
                                iconName: isEntryBased
                                    ? 'confirmation_number'
                                    : 'fitness_center',
                                color: planColor,
                                size: 20,
                              ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.w,
                          vertical: 0.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: planColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '€${plan['price']}',
                          style: AppTheme.darkTheme.textTheme.titleMedium
                              ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // NEW badge for entry-based plans
                  if (isEntryBased && !isLocked) ...[
                    SizedBox(height: 0.6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'NUOVO',
                        style:
                            AppTheme.darkTheme.textTheme.labelSmall?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 1.h),

                  // Title
                  Text(
                    plan['title'] as String,
                    style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isLocked
                          ? Colors.grey.shade500
                          : AppTheme.darkTheme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.6.h),

                  // Frequency or entry count
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: planColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isEntryBased
                          ? (entryCount > 1
                              ? '$entryCount ingressi'
                              : '1 ingresso')
                          : plan['frequency'] as String,
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: planColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 0.6.h),

                  // Entry details for entry-based plans
                  if (isEntryBased) ...[
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'schedule',
                          color: planColor,
                          size: 14,
                        ),
                        SizedBox(width: 1.w),
                        Expanded(
                          child: Text(
                            'Nessuna scadenza',
                            style: AppTheme.darkTheme.textTheme.bodySmall
                                ?.copyWith(
                              color: AppTheme
                                  .darkTheme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Classes per week (for monthly plans)
                    if ((plan['classesPerWeek'] as int) > 0)
                      Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'calendar_today',
                            color:
                                AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                            size: 14,
                          ),
                          SizedBox(width: 1.w),
                          Expanded(
                            child: Text(
                              '${plan['classesPerWeek']} lezioni/settimana',
                              style: AppTheme.darkTheme.textTheme.bodySmall
                                  ?.copyWith(
                                color: AppTheme
                                    .darkTheme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],

                  const Spacer(),

                  // Action button
                  Container(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 1.h),
                          decoration: BoxDecoration(
                            color: isLoading
                                ? planColor.withValues(alpha: 0.3)
                                : planColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: planColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: isLoading
                              ? Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: planColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : isLocked
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          color: Colors.grey.shade500,
                                          size: 14,
                                        ),
                                        SizedBox(width: 1.w),
                                        Text(
                                          'Bloccato',
                                          style: AppTheme
                                              .darkTheme.textTheme.titleSmall
                                              ?.copyWith(
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          isEntryBased
                                              ? 'Acquista'
                                              : 'Sottoscrivi',
                                          style: AppTheme
                                              .darkTheme.textTheme.titleSmall
                                              ?.copyWith(
                                            color: planColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 1.w),
                                        CustomIconWidget(
                                          iconName: 'arrow_forward',
                                          color: planColor,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
