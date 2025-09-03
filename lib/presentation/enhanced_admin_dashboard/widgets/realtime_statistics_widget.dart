import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

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

class _RealtimeStatisticsWidgetState extends State<RealtimeStatisticsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.stats['capacityMetrics'] / 100.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistiche in Tempo Reale',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Dati aggiornati e metriche di capacità con tema scuro',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: 3.h),

          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatisticCard(
                  context,
                  'Iscrizioni Attive',
                  '${widget.stats['activeMemberships']}',
                  Icons.people_alt,
                  Theme.of(context).colorScheme.secondary,
                  '+12% vs mese scorso',
                  true,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildStatisticCard(
                  context,
                  'Entrate Mensili',
                  '€${(widget.stats['monthlyRevenue'] as double).toStringAsFixed(0)}',
                  Icons.euro_symbol,
                  Colors.green,
                  '+8% crescita',
                  true,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          Row(
            children: [
              Expanded(
                child: _buildStatisticCard(
                  context,
                  'Approvazioni',
                  '${widget.stats['pendingApprovals']}',
                  Icons.pending_actions,
                  Colors.orange,
                  'In attesa',
                  false,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildCapacityMetricCard(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
    bool isPositive,
  ) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.grey)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.remove,
                      size: 12,
                      color: isPositive ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      trend,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isPositive ? Colors.green : Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityMetricCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.stats['capacityMetrics']}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Animated Progress Bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 0.8.h,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Metriche Capacità',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
