import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class SponsorStatsWidget extends StatelessWidget {
  final Map<String, int> stats;

  const SponsorStatsWidget({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        children: [
          Row(
            children: [
              // Total Sponsors
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Totale',
                  value: stats['total']?.toString() ?? '0',
                  icon: Icons.store,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              SizedBox(width: 3.w),

              // Active Sponsors
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Attivi',
                  value: stats['active']?.toString() ?? '0',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),

              SizedBox(width: 3.w),

              // Inactive Sponsors
              Expanded(
                child: _buildStatCard(
                  context,
                  title: 'Inattivi',
                  value: stats['inactive']?.toString() ?? '0',
                  icon: Icons.pause_circle,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),

          // Affiliazioni counter (full width row)
          _buildStatCard(
            context,
            title: 'Affiliazioni',
            value: stats['affiliazioni']?.toString() ?? '0',
            icon: Icons.verified_outlined,
            color: Colors.teal,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    final card = Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: fullWidth
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(width: 4.w),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                SizedBox(width: 2.w),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(height: 1.h),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );

    if (fullWidth) {
      return card;
    }
    return card;
  }
}
