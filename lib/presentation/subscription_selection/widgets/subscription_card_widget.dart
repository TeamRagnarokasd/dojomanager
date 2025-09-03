import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SubscriptionCardWidget extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isSelected;
  final bool isMonthly;
  final VoidCallback onTap;
  final String? preselectedPaymentMethod;
  final bool isLoading;

  const SubscriptionCardWidget({
    Key? key,
    required this.plan,
    required this.isSelected,
    required this.isMonthly,
    required this.onTap,
    this.preselectedPaymentMethod,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final planColor = Color(plan['color'] as int);
    final disciplines = plan['disciplines'] as List<String>;
    final benefits = plan['benefits'] as List<String>;
    final basePrice = plan['price'] as int;

    // Check if this card should show direct payment indicator
    final bool hasDirectPayment = preselectedPaymentMethod != null;

    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.primary
                    : planColor.withValues(alpha: 0.3),
                width: isSelected ? 3 : 2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  planColor.withValues(alpha: isSelected ? 0.15 : 0.08),
                  planColor.withValues(alpha: isSelected ? 0.08 : 0.02),
                ],
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : hasDirectPayment
                      ? [
                          BoxShadow(
                            color: planColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and selection indicator
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                plan['title'] as String,
                                style: AppTheme
                                    .lightTheme.textTheme.headlineSmall
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: planColor,
                                ),
                              ),
                              // Show direct payment indicator when payment method is pre-selected
                              if (hasDirectPayment) ...[
                                SizedBox(width: 2.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 2.w,
                                    vertical: 0.5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.lightTheme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomIconWidget(
                                        iconName: 'flash_on',
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 1.w),
                                      Text(
                                        'Pagamento Diretto',
                                        style: AppTheme
                                            .lightTheme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            plan['frequency'] as String,
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: AppTheme
                                  .lightTheme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isSelected)
                          Container(
                            padding: EdgeInsets.all(1.w),
                            decoration: BoxDecoration(
                              color: AppTheme.lightTheme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: isLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : CustomIconWidget(
                                    iconName: 'check',
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        SizedBox(height: 1.h),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '€$basePrice',
                              style: AppTheme.lightTheme.textTheme.displaySmall
                                  ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: planColor,
                              ),
                            ),
                            Text(
                              '/mese',
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                color: AppTheme
                                    .lightTheme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                // Show direct payment info when payment method is pre-selected
                if (hasDirectPayment) ...[
                  SizedBox(height: 2.h),
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: AppTheme.lightTheme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: preselectedPaymentMethod == 'sumup'
                              ? 'payment'
                              : 'smartphone',
                          color: AppTheme.lightTheme.colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            'Tocca per andare direttamente al pagamento ${preselectedPaymentMethod == 'sumup' ? 'SumUp' : 'Satispay'}',
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: AppTheme.lightTheme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 3.h),

                // Disciplines
                if (disciplines.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: planColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: planColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'sports_martial_arts',
                              color: planColor,
                              size: 20,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'Discipline Incluse',
                              style: AppTheme.lightTheme.textTheme.titleSmall
                                  ?.copyWith(
                                color: planColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Wrap(
                          spacing: 2.w,
                          runSpacing: 1.h,
                          children: disciplines
                              .map(
                                (discipline) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 3.w,
                                    vertical: 0.8.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: planColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    discipline,
                                    style: AppTheme
                                        .lightTheme.textTheme.labelMedium
                                        ?.copyWith(
                                      color: planColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 2.h),

                // Classes per week
                if (plan['classesPerWeek'] > 0)
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'schedule',
                        color: planColor,
                        size: 20,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${plan['classesPerWeek']} lezioni/settimana',
                        style:
                            AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                          color: planColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                if (plan['classesPerWeek'] > 0) SizedBox(height: 2.h),

                // Benefits
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: benefits
                      .map(
                        (benefit) => Padding(
                          padding: EdgeInsets.only(bottom: 1.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 0.5.h),
                                child: CustomIconWidget(
                                  iconName: 'check_circle',
                                  color: planColor,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Text(
                                  benefit,
                                  style: AppTheme
                                      .lightTheme.textTheme.bodyMedium
                                      ?.copyWith(
                                    color: AppTheme.lightTheme.colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
