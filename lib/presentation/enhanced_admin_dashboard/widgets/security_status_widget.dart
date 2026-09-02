import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class SecurityStatusWidget extends StatefulWidget {
  final double systemHealth;

  const SecurityStatusWidget({
    Key? key,
    required this.systemHealth,
  }) : super(key: key);

  @override
  State<SecurityStatusWidget> createState() => _SecurityStatusWidgetState();
}

class _SecurityStatusWidgetState extends State<SecurityStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> securityMetrics = [
      {
        'title': 'Salute Sistema',
        'value': '${widget.systemHealth.toStringAsFixed(1)}%',
        'status': widget.systemHealth >= 95
            ? 'excellent'
            : widget.systemHealth >= 80
                ? 'good'
                : 'warning',
        'icon': Icons.health_and_safety,
        'description': 'Prestazioni complessive ottimali',
      },
      {
        'title': 'Stato Backup',
        'value': 'Attivo',
        'status': 'excellent',
        'icon': Icons.backup,
        'description': 'Ultimo backup: 2 ore fa',
      },
      {
        'title': 'Log di Accesso',
        'value': '156 oggi',
        'status': 'good',
        'icon': Icons.login,
        'description': 'Accessi monitorati in tempo reale',
      },
      {
        'title': 'Connessioni Sicure',
        'value': '100%',
        'status': 'excellent',
        'icon': Icons.security,
        'description': 'Tutte le connessioni crittografate',
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stato Sicurezza',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Monitoraggio sistema e log accessi con indicatori tema scuro',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: 3.h),

          // System Health Overview
          Container(
            padding: EdgeInsets.all(4.w),
            margin: EdgeInsets.only(bottom: 3.h),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getStatusColor('excellent').withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor('excellent').withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: _getStatusColor('excellent')
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: _getStatusColor('excellent'),
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SISTEMA SICURO',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        'Tutti i sistemi di sicurezza operativi',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      SizedBox(height: 1.h),
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            color: _getStatusColor('excellent'),
                            size: 16,
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            'Certificazione SSL Attiva',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _getStatusColor('excellent'),
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Security Metrics Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 2.h,
              childAspectRatio: 0.98,
            ),
            itemCount: securityMetrics.length,
            itemBuilder: (context, index) {
              final metric = securityMetrics[index];
              return Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).shadowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with Status
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: _getStatusColor(metric['status'])
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            metric['icon'],
                            color: _getStatusColor(metric['status']),
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 2.w,
                          height: 2.w,
                          decoration: BoxDecoration(
                            color: _getStatusColor(metric['status']),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),

                    // Value
                    Text(
                      metric['value'],
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 0.3.h),

                    // Title
                    Text(
                      metric['title'],
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 0.5.h),

                    // Description - flexible to avoid overflow
                    Expanded(
                      child: Text(
                        metric['description'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 10,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return const Color(0xFFFF0000); // Team Ragnarok red
      default:
        return Colors.grey;
    }
  }
}
