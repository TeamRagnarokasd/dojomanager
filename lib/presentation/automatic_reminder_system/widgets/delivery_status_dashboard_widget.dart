import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class DeliveryStatusDashboardWidget extends StatelessWidget {
  final Map<String, dynamic> deliveryStats;
  final VoidCallback onRefresh;

  const DeliveryStatusDashboardWidget({
    super.key,
    required this.deliveryStats,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Status Invio',
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
          ),
          SizedBox(height: 3.h),
          _buildDeliveryStatsGrid(context),
          SizedBox(height: 3.h),
          _buildDeliveryChart(context),
          SizedBox(height: 3.h),
          _buildRecentDeliveries(context),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatsGrid(BuildContext context) {
    final totalSent = deliveryStats['totalSent'] ?? 0;
    final successful = deliveryStats['successful'] ?? 0;
    final failed = deliveryStats['failed'] ?? 0;
    final deliveryRate = deliveryStats['deliveryRate'] ?? 0.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 3.w,
      mainAxisSpacing: 2.h,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          context,
          title: 'Totale Inviati',
          value: totalSent.toString(),
          icon: Icons.send,
          color: Colors.blue,
        ),
        _buildStatCard(
          context,
          title: 'Consegnati',
          value: successful.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _buildStatCard(
          context,
          title: 'Falliti',
          value: failed.toString(),
          icon: Icons.error,
          color: Colors.red,
        ),
        _buildStatCard(
          context,
          title: 'Tasso Successo',
          value: '${deliveryRate.toStringAsFixed(1)}%',
          icon: Icons.trending_up,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 6.w),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Colors.grey[600],
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryChart(BuildContext context) {
    final successful = deliveryStats['successful'] ?? 0;
    final failed = deliveryStats['failed'] ?? 0;
    final total = successful + failed;

    if (total == 0) {
      return Container(
        height: 25.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(26),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 15.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 2.h),
            Text(
              'reminders.no_delivery_data'.tr(),
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    final successPercentage = (successful / total) * 100;
    final failedPercentage = (failed / total) * 100;

    return Container(
      height: 25.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Consegne',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onRefresh,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          value: successful.toDouble(),
                          title: '${successPercentage.toStringAsFixed(0)}%',
                          color: Colors.green,
                          radius: 50,
                          titleStyle:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        if (failed > 0)
                          PieChartSectionData(
                            value: failed.toDouble(),
                            title: '${failedPercentage.toStringAsFixed(0)}%',
                            color: Colors.red,
                            radius: 40,
                            titleStyle:
                                Theme.of(context).textTheme.bodySmall!.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                        context, 'Consegnati', Colors.green, successful),
                    SizedBox(height: 1.h),
                    _buildLegendItem(context, 'Falliti', Colors.red, failed),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
      BuildContext context, String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 3.w,
          height: 3.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 2.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentDeliveries(BuildContext context) {
    // Mock data for recent deliveries
    final recentDeliveries = [
      {
        'user': 'Mario Rossi',
        'type': 'Push',
        'status': 'success',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      },
      {
        'user': 'Giulia Bianchi',
        'type': 'common.email'.tr(),
        'status': 'success',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
      },
      {
        'user': 'Luca Verde',
        'type': 'reminders.sms'.tr(),
        'status': 'failed',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
      },
    ];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consegne Recenti',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Navigate to full delivery history
                },
                icon: const Icon(Icons.history),
                label: Text('reminders.see_all'.tr()),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ...recentDeliveries
              .map((delivery) => _buildDeliveryItem(context, delivery)),
        ],
      ),
    );
  }

  Widget _buildDeliveryItem(
      BuildContext context, Map<String, dynamic> delivery) {
    final isSuccess = delivery['status'] == 'success';
    final timestamp = delivery['timestamp'] as DateTime;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: (isSuccess ? Colors.green : Colors.red).withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check : Icons.close,
              color: isSuccess ? Colors.green : Colors.red,
              size: 4.w,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery['user'],
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${delivery['type']} • ${_formatTimestamp(timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: (isSuccess ? Colors.green : Colors.red).withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isSuccess ? 'Consegnato' : 'Fallito',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: isSuccess ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m fa';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h fa';
    } else {
      return '${difference.inDays}g fa';
    }
  }
}
