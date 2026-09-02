import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_export.dart';
import '../../../services/realtime_notification_service.dart';

class SubscriptionPlansWidget extends StatefulWidget {
  final Function(int)? onTabChanged;
  final Function(Map<String, dynamic>)? onPlanSelected;

  const SubscriptionPlansWidget({
    Key? key,
    this.onTabChanged,
    this.onPlanSelected,
  }) : super(key: key);

  @override
  State<SubscriptionPlansWidget> createState() =>
      _SubscriptionPlansWidgetState();
}

class _SubscriptionPlansWidgetState extends State<SubscriptionPlansWidget> {
  List<Map<String, dynamic>> _plans = [];
  bool _isLoading = true;
  StreamSubscription<RealtimeDataChangeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _subscribeToRealtimeChanges();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToRealtimeChanges() {
    RealtimeNotificationService.instance.subscribeToAdminDataChanges();
    _realtimeSubscription =
        RealtimeNotificationService.instance.dataChangeStream
            .where(
      (event) =>
          event.type == RealtimeDataChangeType.subscriptionPlans ||
          event.type == RealtimeDataChangeType.customSubscriptionPlans,
    )
            .listen((_) {
      if (mounted) _loadPlans();
    });
  }

  Future<void> _loadPlans() async {
    try {
      // Load only from custom_subscription_plans (admin-managed)
      final customResponse = await Supabase.instance.client
          .from('custom_subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final List<Map<String, dynamic>> loaded = [];

      // Map custom plans
      for (final row in List<Map<String, dynamic>>.from(customResponse)) {
        final planType = row['plan_type'] as String? ?? 'monthly';
        final bool isEntryBased =
            planType == 'single_entry' || planType == 'multi_entry';
        final int entryCount = (row['entry_count'] as num?)?.toInt() ?? 1;

        int color;
        if (planType == 'annual') {
          color = 0xFF5D4037;
        } else if (planType == 'single_entry') {
          color = 0xFF4CAF50;
        } else if (planType == 'multi_entry') {
          color = 0xFF2E7D32;
        } else {
          final price = (row['amount'] as num?)?.toDouble() ?? 0;
          if (price <= 50) {
            color = 0xFFFF6B35;
          } else if (price <= 65) {
            color = 0xFFD32F2F;
          } else if (price <= 80) {
            color = 0xFF4A90E2;
          } else if (price <= 100) {
            color = 0xFF1976D2;
          } else if (price <= 110) {
            color = 0xFF9C27B0;
          } else {
            color = 0xFF7B1FA2;
          }
        }

        loaded.add({
          'id': row['id'],
          'dbId': row['id'],
          'title': row['name'] as String? ?? '',
          'price': (row['amount'] as num?)?.toDouble() ?? 0,
          'frequency': planType == 'annual'
              ? 'Annuale'
              : isEntryBased
                  ? (entryCount == 1 ? 'Per ingresso' : '$entryCount ingressi')
                  : 'Mensile',
          'disciplines': [''],
          'classesPerWeek': 0,
          'entryBased': isEntryBased,
          'entryCount': entryCount,
          'benefits': (row['description'] as String? ?? '')
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          'sumupUrl': row['external_url'] as String? ?? '',
          'color': color,
          'isCustom': true,
        });
      }

      setState(() {
        _plans = loaded;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSubscriptionSelect(BuildContext context, Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Come procedere all\'acquisto',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Per procedere con l\'acquisto di questo abbonamento, recati nella sezione "Paga" dove potrai completare la transazione in modo sicuro e veloce.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Ho capito',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.all(4.w),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'subscriptions',
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'payment.subscriptions_title'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              SizedBox(height: 0.5.h),
                              Text(
                                'payment.subscriptions_subtitle'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),

                  // Entry plans banner
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'new_releases',
                          color: Colors.green,
                          size: 24,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            'payment.entry_plans_banner'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),

          // Loading or Plans Grid
          if (_isLoading)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Wrap(
                  spacing: 3.w,
                  runSpacing: 2.h,
                  children: List.generate(_plans.length, (index) {
                    final itemWidth =
                        (MediaQuery.of(context).size.width - 8.w - 3.w) / 2;
                    return SizedBox(
                      width: itemWidth,
                      child: Builder(
                        builder: (context) {
                          final plan = _plans[index];
                          final color = Color(plan['color'] as int);
                          final isEntryBased = plan['entryBased'] ?? false;
                          final entryCount = plan['entryCount'] ?? 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    _onSubscriptionSelect(context, plan),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: EdgeInsets.all(3.w),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Header with price
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(2.w),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: CustomIconWidget(
                                              iconName: isEntryBased
                                                  ? 'confirmation_number'
                                                  : 'fitness_center',
                                              color: color,
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
                                              color: color,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '€${plan['price']}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 1.5.h),

                                      // NEW badge for entry-based plans
                                      if (isEntryBased) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 2.w,
                                            vertical: 0.4.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'payment.new_badge'.tr(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ),
                                        SizedBox(height: 0.8.h),
                                      ],

                                      // Title
                                      Text(
                                        plan['title'] as String,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 0.8.h),

                                      // Frequency or entries
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2.w,
                                          vertical: 0.5.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          isEntryBased
                                              ? (entryCount > 1
                                                  ? 'payment.entry_count_many'
                                                      .tr(
                                                      namedArgs: {
                                                        'count': '$entryCount',
                                                      },
                                                    )
                                                  : 'payment.entry_count_one'
                                                      .tr())
                                              : plan['frequency'] as String,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      SizedBox(height: 0.8.h),

                                      // Entry info
                                      if (isEntryBased) ...[
                                        Row(
                                          children: [
                                            CustomIconWidget(
                                              iconName: 'schedule',
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              size: 14,
                                            ),
                                            SizedBox(width: 1.w),
                                            Expanded(
                                              child: Text(
                                                'payment.no_expiry'.tr(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else if ((plan['classesPerWeek']
                                              as int) >
                                          0) ...[
                                        Row(
                                          children: [
                                            CustomIconWidget(
                                              iconName: 'calendar_today',
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              size: 14,
                                            ),
                                            SizedBox(width: 1.w),
                                            Text(
                                              'payment.lessons_per_week'.tr(
                                                namedArgs: {
                                                  'count':
                                                      '${plan['classesPerWeek']}',
                                                },
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      SizedBox(height: 1.h),

                                      // Action button
                                      SizedBox(
                                        width: double.infinity,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _onSubscriptionSelect(
                                              context,
                                              plan,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 1.5.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                  alpha: 0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: color.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    isEntryBased
                                                        ? 'payment.buy'.tr()
                                                        : 'payment.subscribe'
                                                            .tr(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          color: color,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  SizedBox(width: 1.w),
                                                  CustomIconWidget(
                                                    iconName: 'arrow_forward',
                                                    color: color,
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
                          );
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: EdgeInsets.all(4.w),
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'security',
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'payment.sumup_security_footer'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        ],
      ),
    );
  }
}
