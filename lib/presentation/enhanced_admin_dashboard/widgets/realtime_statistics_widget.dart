import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

class RealtimeStatisticsWidget extends StatefulWidget {
  final Map<String, dynamic> stats;

  const RealtimeStatisticsWidget({
    Key? key,
    required this.stats,
  }) : super(key: key);

  @override
  State<RealtimeStatisticsWidget> createState() =>
      _RealtimeStatisticsWidgetState();
}

class _RealtimeStatisticsWidgetState extends State<RealtimeStatisticsWidget> {
  bool _isLoading = true;

  // 🔧 FIX 3: Real data instead of fake data
  double _monthlyRevenue = 0.0;
  int _totalStudents = 0;
  int _activeSubscriptions = 0;
  int _totalReceipts = 0;

  @override
  void initState() {
    super.initState();
    _loadRealStatistics();
  }

  // 🎯 FIX 3: Load real statistics from non_fiscal_receipts table
  Future<void> _loadRealStatistics() async {
    try {
      setState(() => _isLoading = true);

      // Get current month's revenue from non_fiscal_receipts
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final receiptsResponse = await Supabase.instance.client
          .from('non_fiscal_receipts')
          .select('amount')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      // Calculate monthly revenue
      double monthlyRevenue = 0.0;
      for (final receipt in receiptsResponse) {
        monthlyRevenue += (receipt['amount'] as num).toDouble();
      }

      // Get total students (approved users with student role)
      final studentsResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('id')
          .eq('role', 'student')
          .eq('status', 'approved')
          .count();

      final totalStudents = studentsResponse.count;

      // Get active subscriptions
      final subsResponse = await Supabase.instance.client
          .from('user_subscriptions')
          .select('id')
          .eq('is_active', true)
          .count();

      final activeSubscriptions = subsResponse.count;

      // Get total receipts count
      final totalReceiptsResponse = await Supabase.instance.client
          .from('non_fiscal_receipts')
          .select('id')
          .count();

      final totalReceipts = totalReceiptsResponse.count;

      if (mounted) {
        setState(() {
          _monthlyRevenue = monthlyRevenue;
          _totalStudents = totalStudents;
          _activeSubscriptions = activeSubscriptions;
          _totalReceipts = totalReceipts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'analytics',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              SizedBox(width: 2.w),
              Text(
                'Statistiche in Tempo Reale',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Monthly Revenue Card
          _buildStatCard(
            context,
            icon: 'euro',
            label: 'Entrate Mese',
            value: '€${_monthlyRevenue.toStringAsFixed(2)}',
            color: Colors.green,
          ),
          SizedBox(height: 2.h),

          // Students Card
          _buildStatCard(
            context,
            icon: 'people',
            label: 'Studenti Attivi',
            value: _totalStudents.toString(),
            color: Colors.blue,
          ),
          SizedBox(height: 2.h),

          // Active Subscriptions Card
          _buildStatCard(
            context,
            icon: 'card_membership',
            label: 'Abbonamenti Attivi',
            value: _activeSubscriptions.toString(),
            color: Colors.orange,
          ),
          SizedBox(height: 2.h),

          // Total Receipts Card
          _buildStatCard(
            context,
            icon: 'receipt_long',
            label: 'Ricevute Totali',
            value: _totalReceipts.toString(),
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
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
              size: 24,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}