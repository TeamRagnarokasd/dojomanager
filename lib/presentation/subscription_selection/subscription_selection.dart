import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../services/realtime_notification_service.dart';
import './widgets/payment_method_section_widget.dart';
import './widgets/subscription_card_widget.dart';

class SubscriptionSelection extends StatefulWidget {
  const SubscriptionSelection({super.key});

  @override
  State<SubscriptionSelection> createState() => _SubscriptionSelectionState();
}

class _SubscriptionSelectionState extends State<SubscriptionSelection>
    with WidgetsBindingObserver, RouteAware {
  int? _selectedSubscriptionId;
  bool _isLoading = false;
  bool _isLoadingPlans = true;
  String? _selectedPaymentMethod;
  String? _previouslySelectedPaymentMethod;
  StreamSubscription<RealtimeDataChangeEvent>? _realtimeSubscription;

  // Plans loaded from Supabase
  List<Map<String, dynamic>> _subscriptionPlans = [];

  // Satispay URL for all subscriptions
  final String _satispayUrl =
      "https://www.satispay.com/app/pay/shops/58875f70-d796-4596-a2f6-12fe91a8c202";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPlans();
    _subscribeToRealtimeChanges();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRoutes.routeObserver.subscribe(this, route);
    }

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is String && _previouslySelectedPaymentMethod == null) {
      _previouslySelectedPaymentMethod = arguments;
      _selectedPaymentMethod = arguments;
    }
  }

  @override
  void didPush() {
    _loadPlans();
  }

  @override
  void didPopNext() {
    _loadPlans();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadPlans();
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppRoutes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _subscribeToRealtimeChanges() {
    RealtimeNotificationService.instance.subscribeToAdminDataChanges();
    _realtimeSubscription = RealtimeNotificationService
        .instance
        .dataChangeStream
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
      final customResponse = await Supabase.instance.client
          .from('custom_subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      if (!mounted) return;

      final List<Map<String, dynamic>> loaded = [];

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
          'planType': planType,
        });
      }

      setState(() {
        _subscriptionPlans = loaded;
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlans = false;
        });
      }
    }
  }

  void _selectSubscription(dynamic subscriptionId) {
    setState(() {
      _selectedSubscriptionId = subscriptionId is int ? subscriptionId : null;
      // For UUID-based ids store as string comparison key
    });

    if (_previouslySelectedPaymentMethod != null) {
      _proceedToPayment();
    }
  }

  void _selectPaymentMethod(String method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
  }

  bool get _canProceedToPayment =>
      _selectedSubscriptionId != null && _selectedPaymentMethod != null;

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('subscription_ui.payment_link_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _proceedToPayment() async {
    if (!_canProceedToPayment) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedPlan = _subscriptionPlans.firstWhere(
        (plan) => plan['id'] == _selectedSubscriptionId,
        orElse: () => <String, dynamic>{},
      );

      if (selectedPlan.isEmpty) {
        throw Exception('Piano non trovato');
      }

      String redirectUrl;

      if (_selectedPaymentMethod == 'sumup') {
        redirectUrl = selectedPlan['sumupUrl'] as String;
      } else if (_selectedPaymentMethod == 'satispay') {
        redirectUrl = _satispayUrl;
      } else {
        throw Exception('Metodo di pagamento non supportato');
      }

      await Future.delayed(const Duration(milliseconds: 800));
      await _launchUrl(redirectUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reindirizzamento al pagamento per ${selectedPlan['title']}',
            ),
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'payment.redirect_error'.tr(namedArgs: {'detail': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Selezione Abbonamento',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header with Team Logo
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary.withValues(
                alpha: 0.1,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                CustomImageWidget(
                  imageUrl: AppConstants.teamLogo,
                  width: 20.w,
                  height: 20.w,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Team Ragnarok',
                  style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
                Text(
                  _previouslySelectedPaymentMethod != null
                      ? 'subscription_ui.select_and_pay'.tr()
                      : 'Scegli il tuo piano di allenamento',
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_previouslySelectedPaymentMethod != null) ...[
                  SizedBox(height: 1.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.lightTheme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: _previouslySelectedPaymentMethod == 'sumup'
                              ? 'payment'
                              : 'smartphone',
                          color: AppTheme.lightTheme.colorScheme.primary,
                          size: 18,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'payment.payment_via'.tr(
                            namedArgs: {
                              'method':
                                  _previouslySelectedPaymentMethod == 'sumup'
                                  ? 'payment.sumup'.tr()
                                  : 'payment.satispay'.tr(),
                            },
                          ),
                          style: AppTheme.lightTheme.textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.lightTheme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Subscription Plans
          Expanded(
            child: _isLoadingPlans
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.lightTheme.colorScheme.primary,
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    itemCount: _subscriptionPlans.length,
                    itemBuilder: (context, index) {
                      final plan = _subscriptionPlans[index];
                      return SubscriptionCardWidget(
                        plan: plan,
                        isSelected: _selectedSubscriptionId == plan['id'],
                        isMonthly: true,
                        onTap: () => _selectSubscription(plan['id']),
                        preselectedPaymentMethod:
                            _previouslySelectedPaymentMethod,
                        isLoading:
                            _isLoading && _selectedSubscriptionId == plan['id'],
                      );
                    },
                  ),
          ),

          // Payment Method Section
          if (_selectedSubscriptionId != null &&
              _previouslySelectedPaymentMethod == null)
            PaymentMethodSectionWidget(
              selectedMethod: _selectedPaymentMethod,
              onMethodSelected: _selectPaymentMethod,
              isFromPreviousSelection: false,
            ),

          // Proceed to Payment Button
          if (_previouslySelectedPaymentMethod == null)
            Container(
              padding: EdgeInsets.all(4.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceedToPayment && !_isLoading
                      ? _proceedToPayment
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 3.h,
                          width: 3.h,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Procedi al Pagamento',
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
