import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class PlanComparisonWidget extends StatelessWidget {
  final List<Map<String, dynamic>> plans;

  const PlanComparisonWidget({
    Key? key,
    required this.plans,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85.h,
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 15.w,
            height: 0.5.h,
            margin: EdgeInsets.only(top: 2.h, bottom: 3.h),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'compare_arrows',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 28,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'Confronto Piani',
                    style:
                        AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightTheme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: CustomIconWidget(
                    iconName: 'close',
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 3.h,
            color:
                AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
          ),

          // Comparison table
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Column(
                children: [
                  // Features comparison
                  _buildComparisonSection(
                    'Caratteristiche Principali',
                    'sports_martial_arts',
                    [
                      _buildFeatureRow('Prezzo', (plan) => '€${plan['price']}'),
                      _buildFeatureRow(
                          'Frequenza', (plan) => plan['frequency']),
                      _buildFeatureRow(
                        'Lezioni/settimana',
                        (plan) => plan['classesPerWeek'] > 0
                            ? '${plan['classesPerWeek']}'
                            : 'N/A',
                      ),
                    ],
                  ),

                  SizedBox(height: 3.h),

                  // Disciplines comparison
                  _buildComparisonSection(
                    'Discipline Incluse',
                    'fitness_center',
                    [
                      _buildFeatureRow(
                          'BJJ', (plan) => _hasDiscipline(plan, 'BJJ')),
                      _buildFeatureRow(
                          'MMA', (plan) => _hasDiscipline(plan, 'MMA')),
                      _buildFeatureRow(
                          'SAMBO', (plan) => _hasDiscipline(plan, 'SAMBO')),
                      _buildFeatureRow('Grappling',
                          (plan) => _hasDiscipline(plan, 'Grappling')),
                      _buildFeatureRow(
                        'Prep. Atletica',
                        (plan) =>
                            _hasDiscipline(plan, 'Preparazione Atletica') ||
                            _hasDiscipline(plan, 'Prep. Atletica'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(
    String title,
    String iconName,
    List<Widget> rows,
  ) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: iconName,
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: 3.w),
              Text(
                title,
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
      String feature, dynamic Function(Map<String, dynamic>) getValue) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 25.w,
                child: Text(
                  feature,
                  style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: plans.map((plan) {
                      final value = getValue(plan);
                      final planColor = Color(plan['color'] as int);
                      final isBoolean = value is bool;

                      return Container(
                        width: 18.w,
                        margin: EdgeInsets.only(right: 2.w),
                        child: Column(
                          children: [
                            Text(
                              plan['title'].toString().length > 12
                                  ? '${plan['title'].toString().substring(0, 12)}...'
                                  : plan['title'].toString(),
                              style: AppTheme.lightTheme.textTheme.labelSmall
                                  ?.copyWith(
                                color: planColor,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 0.5.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 0.5.h,
                                horizontal: 1.w,
                              ),
                              decoration: BoxDecoration(
                                color: planColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: planColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: isBoolean
                                    ? CustomIconWidget(
                                        iconName: value ? 'check' : 'close',
                                        color: value
                                            ? Colors.green[600]!
                                            : Colors.red[600]!,
                                        size: 16,
                                      )
                                    : Text(
                                        value.toString(),
                                        style: AppTheme
                                            .lightTheme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: planColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          if (plans.indexOf(plans.last) != plans.length - 1)
            Divider(
              color: AppTheme.lightTheme.colorScheme.outline
                  .withValues(alpha: 0.1),
            ),
        ],
      ),
    );
  }

  bool _hasDiscipline(Map<String, dynamic> plan, String discipline) {
    final disciplines = plan['disciplines'] as List<String>;
    return disciplines
        .any((d) => d.toLowerCase().contains(discipline.toLowerCase()));
  }

  bool _hasBenefit(Map<String, dynamic> plan, String benefit) {
    final benefits = plan['benefits'] as List<String>;
    return benefits.any((b) => b.toLowerCase().contains(benefit.toLowerCase()));
  }
}
