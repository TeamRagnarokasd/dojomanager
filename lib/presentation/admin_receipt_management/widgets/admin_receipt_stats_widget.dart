import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AdminReceiptStatsWidget extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String selectedPeriod;

  const AdminReceiptStatsWidget({
    Key? key,
    required this.stats,
    required this.selectedPeriod,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiche - $selectedPeriod',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),

          // Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Ricevute Totali',
                  value: stats['total_receipts'].toString(),
                  icon: 'receipt_long',
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _buildStatCard(
                  title: 'Incasso Totale',
                  value:
                      '€${stats['total_amount'].toStringAsFixed(2).replaceAll('.', ',')}',
                  icon: 'euro',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 4.h),

          // Subscription Types
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Abbonamenti Mensili',
                  value: stats['monthly_receipts'].toString(),
                  icon: 'calendar_month',
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _buildStatCard(
                  title: 'Iscrizioni Annuali',
                  value: stats['annual_receipts'].toString(),
                  icon: 'calendar_view_year',
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          SizedBox(height: 4.h),

          // Payment Methods
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Pagamenti SumUp',
                  value: stats['sumup_payments'].toString(),
                  icon: 'credit_card',
                  color: const Color(0xFF2196F3),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _buildStatCard(
                  title: 'Pagamenti Satispay',
                  value: stats['satispay_payments'].toString(),
                  icon: 'phone_android',
                  color: const Color(0xFFFF5722),
                ),
              ),
            ],
          ),

          SizedBox(height: 4.h),

          // This Month Stats
          if (stats['this_month_count'] != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.lightTheme.colorScheme.primaryContainer,
                    AppTheme.lightTheme.colorScheme.primaryContainer
                        .withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: AppTheme.lightTheme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CustomIconWidget(
                          iconName: 'trending_up',
                          color: AppTheme.lightTheme.colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Performance Questo Mese',
                        style:
                            AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lightTheme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ricevute',
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                color: AppTheme
                                    .lightTheme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              stats['this_month_count'].toString(),
                              style: AppTheme
                                  .lightTheme.textTheme.headlineMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.lightTheme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Incasso',
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                color: AppTheme
                                    .lightTheme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              '€${stats['this_month_amount'].toStringAsFixed(2).replaceAll('.', ',')}',
                              style: AppTheme
                                  .lightTheme.textTheme.headlineMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.lightTheme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
          ],

          // Charts Section
          if (stats['total_receipts'] > 0) ...[
            Text(
              'Distribuzione Pagamenti',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              height: 30.h,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.3),
                ),
              ),
              child: _buildPaymentMethodChart(),
            ),
            SizedBox(height: 4.h),
            Text(
              'Tipi di Abbonamento',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              height: 30.h,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.3),
                ),
              ),
              child: _buildSubscriptionTypeChart(),
            ),
          ],

          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomIconWidget(
                  iconName: icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Spacer(),
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
          SizedBox(height: 0.5.h),
          Text(
            title,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChart() {
    final sumupPayments = stats['sumup_payments'] as int;
    final satispayPayments = stats['satispay_payments'] as int;
    final totalPayments = sumupPayments + satispayPayments;

    if (totalPayments == 0) {
      return const Center(
        child: Text('Nessun dato disponibile'),
      );
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: sumupPayments.toDouble(),
            title: 'SumUp\n$sumupPayments',
            color: const Color(0xFF2196F3),
            radius: 80,
            titleStyle: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          PieChartSectionData(
            value: satispayPayments.toDouble(),
            title: 'Satispay\n$satispayPayments',
            color: const Color(0xFFFF5722),
            radius: 80,
            titleStyle: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        sectionsSpace: 4,
        centerSpaceRadius: 60,
      ),
    );
  }

  Widget _buildSubscriptionTypeChart() {
    final monthlyReceipts = stats['monthly_receipts'] as int;
    final annualReceipts = stats['annual_receipts'] as int;
    final totalReceipts = monthlyReceipts + annualReceipts;

    if (totalReceipts == 0) {
      return const Center(
        child: Text('Nessun dato disponibile'),
      );
    }

    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: monthlyReceipts.toDouble(),
            title: 'Mensile\n$monthlyReceipts',
            color: Colors.blue,
            radius: 80,
            titleStyle: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          PieChartSectionData(
            value: annualReceipts.toDouble(),
            title: 'Annuale\n$annualReceipts',
            color: Colors.purple,
            radius: 80,
            titleStyle: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        sectionsSpace: 4,
        centerSpaceRadius: 60,
      ),
    );
  }
}
