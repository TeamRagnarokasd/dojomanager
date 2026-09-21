import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/child_profile_service.dart';
import '../../services/payment_service.dart';
import '../../services/realtime_notification_service.dart';
import '../../services/subscription_service.dart';
import './widgets/subscription_option_card_widget.dart';

class SubscriptionPlanSelection extends StatefulWidget {
  /// Optional: when set to 'satispay', the screen shows the Satispay plan
  /// list (all active custom_subscription_plans, via
  /// SubscriptionService.getAllPlansForSatispay) and taps create a Satispay
  /// payment intent instead of launching the SumUp flow. Defaults to null,
  /// which is today's SumUp behaviour, unchanged.
  final String? provider;

  const SubscriptionPlanSelection({Key? key, this.provider}) : super(key: key);

  @override
  State<SubscriptionPlanSelection> createState() =>
      _SubscriptionPlanSelectionState();
}

class _SubscriptionPlanSelectionState extends State<SubscriptionPlanSelection>
    with WidgetsBindingObserver, RouteAware {
  bool _showSubscriptionOptions = false;
  bool _isLoading = false;
  int? _selectedPlanId;

  // Realtime subscription for admin data changes
  StreamSubscription<RealtimeDataChangeEvent>? _realtimeSubscription;

  // ENROLLMENT CHECK: Track if user has annual registration
  bool _hasAnnualRegistration = false;
  bool _isLoadingEnrollmentStatus = true;

  // Custom plans and principal admin check
  List<Map<String, dynamic>> _customPlans = [];
  bool _isPrincipalAdmin = false;
  bool _isLoadingCustomPlans = true;

  // ID of the "Total Submission Kids Scontato" plan, resolved from Supabase at load time.
  // Using the exact ID avoids false positives on future discounted plans.
  String? _kidsDiscountedPlanId;

  // Child profile context
  bool _isChildProfileActive = false;
  Map<String, dynamic>? _activeChildProfile;
  bool _guardianHasDiscount = false;

  // Standard plans loaded from Supabase (ONLY source of truth — no hardcoded fallback)
  List<Map<String, dynamic>> _standardPlans = [];
  bool _isLoadingStandardPlans = true;

  // 🆕 SATISPAY MODE (widget.provider == 'satispay'): separate plan list and
  // loading/launch state, entirely isolated from the SumUp flow above.
  bool get _isSatispayMode => widget.provider == 'satispay';
  List<Map<String, dynamic>> _satispayPlans = [];
  bool _isLoadingSatispayPlans = false;
  String? _launchingSatispayPlanId;
  // Whether the "Abbonamenti in convenzione" sub-list is shown instead of
  // the main Satispay plan list (same split as SumUp's separate
  // PianiConvenzioneScreen, but kept inside this isolated Satispay view).
  bool _showSatispayConvenzioni = false;

  // Non-convenzione / convenzione split of the raw Satispay plan list.
  List<Map<String, dynamic>> get _satispayMainPlans =>
      _satispayPlans.where((p) => p['is_convenzione'] != true).toList();
  List<Map<String, dynamic>> get _satispayConvenzionePlans =>
      _satispayPlans.where((p) => p['is_convenzione'] == true).toList();

  // Returns the active plan list: always from Supabase
  List<Map<String, dynamic>> get _activePlans {
    return _standardPlans;
  }

  /// Maps a plan name to a discipline color if the name contains a known discipline keyword.
  /// Falls back to a neutral app-theme color.
  int _getColorForPlanName(String name) {
    final lower = name.toLowerCase();
    // Discipline keyword → color mapping (matches _getDisciplineColor in discipline_service.dart)
    if (lower.contains('mma')) return 0xFFFF5722;
    if (lower.contains('bjj') || lower.contains('jiu')) return 0xFF2196F3;
    if (lower.contains('sambo')) return 0xFF4CAF50;
    if (lower.contains('grappling')) return 0xFF9C27B0;
    if (lower.contains('fitness') ||
        lower.contains('atletica') ||
        lower.contains('preparazione')) return 0xFFFFC107;
    if (lower.contains('kickboxing') || lower.contains('kick'))
      return 0xFFE91E63;
    if (lower.contains('muay') || lower.contains('thai')) return 0xFFFF9800;
    if (lower.contains('judo')) return 0xFF00BCD4;
    if (lower.contains('karate')) return 0xFFF44336;
    if (lower.contains('wrestling')) return 0xFF795548;
    if (lower.contains('boxe') || lower.contains('boxing')) return 0xFF607D8B;
    if (lower.contains('iscrizione') || lower.contains('annuale'))
      return 0xFF5D4037;
    // Neutral fallback — use the app's primary/secondary accent
    return 0xFF546E7A;
  }

  /// All plans (standard + custom) merged into a single unified list,
  /// each with the same map structure expected by SubscriptionOptionCardWidget.
  List<Map<String, dynamic>> get _allPlans {
    final List<Map<String, dynamic>> merged = List.from(_activePlans);

    for (final cp in _customPlans) {
      final planName = cp['name'] as String? ?? '';
      final amount = (cp['amount'] as num?)?.toDouble() ?? 0.0;
      final lower = planName.toLowerCase();
      final isAnnual =
          lower.contains('iscrizione') || lower.contains('annuale');

      // Hide "Total Submission Kids Scontato" plan specifically (matched by its exact Supabase ID)
      // if the guardian does NOT have an active non-annual subscription.
      if (_kidsDiscountedPlanId != null &&
          cp['id'] == _kidsDiscountedPlanId &&
          !_guardianHasDiscount) {
        continue;
      }

      final isUnlimited = cp['is_unlimited'] as bool? ?? false;

      // Use stored color from DB if available, otherwise auto-compute
      final storedColor =
          cp['color'] != null ? (cp['color'] as num).toInt() : null;
      final resolvedColor = storedColor ?? _getColorForPlanName(planName);
      final durationMonths = (cp['duration_months'] as num?)?.toInt() ?? 1;
      final entryCount = (cp['entry_count'] as num?)?.toInt();

      String frequency;
      if (isAnnual) {
        frequency = 'Annuale';
      } else if (isUnlimited) {
        frequency =
            entryCount != null ? '$entryCount ingressi' : 'Senza limite';
      } else {
        frequency = durationMonths == 1 ? 'Mensile' : '$durationMonths mesi';
      }

      merged.add({
        'id': cp['id'],
        'dbId': cp['id'],
        'title': planName,
        'name': planName, // keep original key for edit dialog compatibility
        'price': amount,
        'amount': amount, // keep original key for edit dialog compatibility
        'frequency': frequency,
        'disciplines': [''],
        'classesPerWeek': 0,
        'entryBased': isUnlimited && entryCount != null,
        'entryCount': entryCount ?? 0,
        'benefits': <String>[],
        'sumupUrl': cp['external_url'] as String? ?? '',
        'external_url': cp['external_url'] as String? ??
            '', // keep original key for edit dialog
        'color': resolvedColor,
        'isStandardFromDb': false,
        'isCustomPlan': true,
        'planType':
            isAnnual ? 'annual' : (isUnlimited ? 'unlimited' : 'monthly'),
        'duration_months': durationMonths,
        'is_unlimited': isUnlimited,
      });
    }

    return merged;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isSatispayMode) {
      // Satispay entry point: go straight to the plan list, load only the
      // Satispay-specific plan list, skip the SumUp/admin data loads below.
      // Enrollment status IS checked here (same rule as SumUp — see
      // _checkEnrollmentStatus), so _isLoadingEnrollmentStatus is left at
      // its default (true) until that check resolves.
      _showSubscriptionOptions = true;
      _loadSatispayPlans();
      _loadChildProfileContext();
      _checkEnrollmentStatus();
      return;
    }
    _checkEnrollmentStatus();
    _loadCustomPlans();
    _loadStandardPlans();
    _checkPrincipalAdminStatus();
    _subscribeToRealtimeChanges();
    _loadChildProfileContext();
  }

  /// 🆕 SATISPAY MODE: loads the exact same plan set shown today in the
  /// Satispay confirmation dropdown (SubscriptionService.getAllPlansForSatispay
  /// — all active custom_subscription_plans, conventions and annual
  /// registration included), so the list is identical to today's.
  Future<void> _loadSatispayPlans() async {
    if (!mounted) return;
    setState(() => _isLoadingSatispayPlans = true);
    try {
      final plans = await SubscriptionService.getAllPlansForSatispay();
      if (!mounted) return;
      setState(() {
        _satispayPlans = plans;
        _isLoadingSatispayPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _satispayPlans = [];
        _isLoadingSatispayPlans = false;
      });
    }
  }

  /// 🆕 SATISPAY MODE: maps a raw getAllPlansForSatispay() row into the map
  /// shape SubscriptionOptionCardWidget expects.
  Map<String, dynamic> _toSatispayCardPlan(Map<String, dynamic> plan) {
    final name = plan['name'] as String? ?? '';
    final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
    final isUnlimited = plan['is_unlimited'] as bool? ?? false;
    final entryCount = plan['entry_count'] as int?;
    final durationMonths = plan['duration_months'] as int? ?? 1;
    final lower = name.toLowerCase();
    final isAnnual = lower.contains('iscrizione') || lower.contains('annuale');

    String frequency;
    if (isAnnual) {
      frequency = 'Annuale';
    } else if (isUnlimited) {
      frequency = entryCount != null ? '$entryCount ingressi' : 'Senza limite';
    } else {
      frequency = durationMonths == 1 ? 'Mensile' : '$durationMonths mesi';
    }

    return {
      'id': plan['id'],
      'title': name,
      'price': price,
      'frequency': frequency,
      'classesPerWeek': 0,
      'entryBased': isUnlimited && entryCount != null,
      'entryCount': entryCount ?? 0,
      'color': _getColorForPlanName(name),
    };
  }

  /// 🆕 SATISPAY MODE: tapping a plan creates a Satispay payment intent via
  /// the 'satispay/create-payment' Edge Function and opens the redirect URL
  /// in the external browser. isPaymentPending/pendingPaymentMethod are
  /// intentionally NOT set — the old "did you pay?" dialog must not appear
  /// for this flow; activation happens automatically via PaidIntentsService.
  /// On failure, shows a message and offers (asks, doesn't auto-switch)
  /// today's fixed-link Satispay flow as a fallback.
  Future<void> _launchSatispayForPlan(Map<String, dynamic> rawPlan) async {
    final planId = rawPlan['id'] as String?;
    final planName = rawPlan['name'] as String? ?? '';
    if (planId == null || planId.isEmpty) {
      await _offerFixedSatispayLinkFallback();
      return;
    }

    if (!mounted) return;
    setState(() => _launchingSatispayPlanId = planId);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'satispay/create-payment',
        body: {
          'plan_id': planId,
          'beneficiary_profile_id': ChildProfileService.getActiveUserId(),
          'redirect_url':
              'https://teamragnarokasd.github.io/dojomanager/payment-done.html',
        },
      );

      final data = response.data;
      final redirectUrl =
          data is Map ? data['redirect_url'] as String? : null;

      if (redirectUrl == null || redirectUrl.isEmpty) {
        throw Exception('Missing redirect_url in create-payment response');
      }

      final opened = await launchUrl(
        Uri.parse(redirectUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('launchUrl returned false');
      }
    } catch (e) {
      print('❌ Satispay create-payment failed for plan "$planName": $e');
      await _offerFixedSatispayLinkFallback();
    } finally {
      if (mounted) {
        setState(() => _launchingSatispayPlanId = null);
      }
    }
  }

  /// 🆕 SATISPAY MODE fallback: shows a message explaining the new flow
  /// couldn't start, and — only if the user explicitly agrees — reproduces
  /// today's fixed-link Satispay flow (same URL and SharedPreferences flags
  /// as sumup_payment_options_widget._launchSatispayUrl), so nothing is
  /// switched to the old confirm-by-hand flow without the user choosing it.
  Future<void> _offerFixedSatispayLinkFallback() async {
    if (!mounted) return;
    final useOldFlow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkTheme.cardColor,
            title: Text(
              'Pagamento non avviato',
              style: AppTheme.darkTheme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Non è stato possibile avviare il pagamento Satispay per questo '
              'piano. Vuoi provare con il link diretto di Satispay?',
              style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'common.cancel'.tr(),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Usa link diretto'),
              ),
            ],
          ),
        ) ??
        false;

    if (!useOldFlow) return;

    try {
      const satispayUrl =
          'https://www.satispay.com/app/pay/shops/58875f70-d796-4596-a2f6-12fe91a8c202';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', true);
      await prefs.setString('pendingPaymentMethod', 'satispay');
      await launchUrl(
        Uri.parse(satispayUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Nothing more we can do — the user can still open Satispay manually.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register with RouteObserver so didPush/didPopNext fire correctly
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRoutes.routeObserver.subscribe(this, route);
    }
  }

  /// Called when this screen is pushed onto the navigator stack
  @override
  void didPush() {
    _refreshAllPlans();
  }

  /// Called when a screen on top of this one is popped (user navigates back here)
  @override
  void didPopNext() {
    _refreshAllPlans();
  }

  void _refreshAllPlans() {
    if (!mounted) return;
    // Satispay mode has its own isolated plan list/loader — skip the SumUp
    // (standard + custom plans) refresh entirely.
    if (_isSatispayMode) return;
    setState(() {
      _isLoadingStandardPlans = true;
      _isLoadingCustomPlans = true;
    });
    _loadStandardPlans();
    _loadCustomPlans();
    _checkEnrollmentStatus();
  }

  void _subscribeToRealtimeChanges() {
    // Ensure admin-data channels are active
    RealtimeNotificationService.instance.subscribeToAdminDataChanges();

    _realtimeSubscription =
        RealtimeNotificationService.instance.dataChangeStream
            .where(
      (event) =>
          event.type == RealtimeDataChangeType.subscriptionPlans ||
          event.type == RealtimeDataChangeType.customSubscriptionPlans,
    )
            .listen((_) {
      if (mounted) {
        _loadStandardPlans();
        _loadCustomPlans();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppRoutes.routeObserver.unsubscribe(this);
    super.dispose();
  }

  // CHECK ENROLLMENT STATUS
  Future<void> _checkEnrollmentStatus() async {
    try {
      final hasAnnual = await PaymentService.checkHasAnnualRegistration();
      if (mounted) {
        setState(() {
          _hasAnnualRegistration = hasAnnual;
          _isLoadingEnrollmentStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasAnnualRegistration = false;
          _isLoadingEnrollmentStatus = false;
        });
      }
    }
  }

  Future<void> _checkPrincipalAdminStatus() async {
    try {
      final isPrincipal = await AuthService.instance.isPrincipalAdmin();
      if (mounted) {
        setState(() {
          _isPrincipalAdmin = isPrincipal;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  /// Load standard plans from Supabase subscription_plans table.
  Future<void> _loadStandardPlans() async {
    try {
      final response = await Supabase.instance.client
          .from('subscription_plans')
          .select('*')
          .eq('is_active', true)
          .order('price', ascending: true);

      if (!mounted) return;

      final List<Map<String, dynamic>> loaded = [];
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final planType = row['plan_type'] as String? ?? 'monthly';
        final bool isEntryBased =
            planType == 'single_entry' || planType == 'multi_entry';
        final int entryCount = (row['entry_count'] as num?)?.toInt() ?? 1;

        // Use stored color from DB if available, otherwise auto-compute
        int color;
        if (row['color'] != null) {
          color = (row['color'] as num).toInt();
        } else if (planType == 'annual') {
          color = 0xFF5D4037;
        } else if (planType == 'single_entry') {
          color = 0xFF4CAF50;
        } else if (planType == 'multi_entry') {
          color = 0xFF2E7D32;
        } else {
          final price = (row['price'] as num?)?.toDouble() ?? 0;
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
          'price': (row['price'] as num?)?.toDouble() ?? 0,
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
          'sumupUrl': row['sumup_url'] as String? ?? '',
          'color': color,
          'isStandardFromDb': true,
          'planType': planType,
        });
      }

      setState(() {
        _standardPlans = loaded;
        _isLoadingStandardPlans = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStandardPlans = false;
        });
      }
    }
  }

  Future<void> _loadCustomPlans() async {
    try {
      final response = await Supabase.instance.client
          .from('custom_subscription_plans')
          .select('*')
          .eq('is_active', true)
          .eq('is_convenzione', false)
          .order('created_at', ascending: false);

      final plans = List<Map<String, dynamic>>.from(response);

      // Resolve the exact ID of "Total Submission Kids Scontato" once at load time.
      // This avoids any string-based filtering that could affect future discounted plans.
      String? kidsDiscountedId;
      for (final p in plans) {
        final name = (p['name'] as String? ?? '').trim();
        if (name == 'Total Submission Kids Scontato') {
          kidsDiscountedId = p['id'] as String?;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _customPlans = plans;
          _kidsDiscountedPlanId = kidsDiscountedId;
          _isLoadingCustomPlans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCustomPlans = false;
        });
      }
    }
  }

  Future<void> _loadChildProfileContext() async {
    try {
      final isChildActive = ChildProfileService.isChildProfileActive;
      Map<String, dynamic>? childProfile;
      // Always check guardian subscription status — the "Total Submission Kids Scontato"
      // plan must be hidden/shown based on whether the adult has an active subscription,
      // regardless of whether a child profile is currently active.
      bool hasDiscount =
          await ChildProfileService.guardianHasActiveSubscription();
      if (isChildActive) {
        childProfile = await ChildProfileService.getActiveChildProfile();
      }
      if (mounted) {
        setState(() {
          _isChildProfileActive = isChildActive;
          _activeChildProfile = childProfile;
          _guardianHasDiscount = hasDiscount;
        });
      }
    } catch (_) {}
  }

  void _showAddPlanDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final amountController = TextEditingController();
    final entryCountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int _selectedDurationMonths = 1; // default: 1 month
    bool _isAnnualPlan = false;
    bool _isUnlimited = false; // "Senza limite" option
    bool _isConvenzione = false; // "Piano in convenzione"

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_card, color: Colors.amber, size: 24),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Nuovo Piano Abbonamento',
                  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nome Abbonamento',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextFormField(
                    controller: nameController,
                    onChanged: (value) {
                      final lower = value.toLowerCase();
                      final isAnnual = lower.contains('iscrizione') ||
                          lower.contains('annuale');
                      if (isAnnual != _isAnnualPlan) {
                        setDialogState(() {
                          _isAnnualPlan = isAnnual;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Es: Corso BJJ',
                      filled: true,
                      fillColor: AppTheme.darkTheme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.title, color: Colors.amber),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il nome dell\'abbonamento';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Link/URL Esterno',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextFormField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      filled: true,
                      fillColor: AppTheme.darkTheme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.link, color: Colors.amber),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il link esterno';
                      }
                      if (!value.startsWith('http://') &&
                          !value.startsWith('https://')) {
                        return 'Inserisci un URL valido (http:// o https://)';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Importo (€)',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      filled: true,
                      fillColor: AppTheme.darkTheme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.euro, color: Colors.amber),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci l\'importo';
                      }
                      final amount = double.tryParse(
                        value.replaceAll(',', '.'),
                      );
                      if (amount == null || amount <= 0) {
                        return 'Inserisci un importo valido';
                      }
                      return null;
                    },
                  ),
                  // Duration selector — only for non-annual plans
                  if (!_isAnnualPlan) ...[
                    SizedBox(height: 2.h),
                    Text(
                      'Durata Abbonamento',
                      style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    // Row: 1 mese, 2 mesi, 3 mesi
                    Row(
                      children: [1, 2, 3].map((months) {
                        final isSelected =
                            !_isUnlimited && _selectedDurationMonths == months;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                _isUnlimited = false;
                                _selectedDurationMonths = months;
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                right: months < 3 ? 2.w : 0,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 1.2.h),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.amber
                                    : AppTheme.darkTheme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.amber
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$months',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                  Text(
                                    months == 1 ? 'mese' : 'mesi',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.white70,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 1.5.h),
                    // "Senza limite" option
                    GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          _isUnlimited = !_isUnlimited;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: 1.2.h,
                          horizontal: 3.w,
                        ),
                        decoration: BoxDecoration(
                          color: _isUnlimited
                              ? Colors.deepPurple.shade700
                              : AppTheme.darkTheme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isUnlimited
                                ? Colors.deepPurple.shade400
                                : Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isUnlimited
                                  ? Icons.all_inclusive
                                  : Icons.all_inclusive_outlined,
                              color:
                                  _isUnlimited ? Colors.white : Colors.white54,
                              size: 20,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'Senza limite',
                              style: TextStyle(
                                color: _isUnlimited
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Info box when "Senza limite" is selected
                    if (_isUnlimited) ...[
                      SizedBox(height: 1.h),
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.deepPurple.shade300,
                              size: 16,
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                'Nessuna scadenza temporale. L\'abbonamento scade solo quando gli ingressi si esauriscono.',
                                style: TextStyle(
                                  color: Colors.deepPurple.shade200,
                                  fontSize: 11.sp,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      Text(
                        'Numero Ingressi (lascia vuoto per illimitati)',
                        style: AppTheme.darkTheme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 1.h),
                      TextFormField(
                        controller: entryCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Es: 10 (vuoto = illimitati)',
                          filled: true,
                          fillColor: AppTheme.darkTheme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.confirmation_number_outlined,
                            color: Colors.deepPurple.shade300,
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final count = int.tryParse(value.trim());
                            if (count == null || count <= 0) {
                              return 'Inserisci un numero valido di ingressi';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                  // ── Piano in convenzione toggle ───────────────────────
                  SizedBox(height: 2.h),
                  GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        _isConvenzione = !_isConvenzione;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: 1.2.h,
                        horizontal: 3.w,
                      ),
                      decoration: BoxDecoration(
                        color: _isConvenzione
                            ? Colors.teal.shade800
                            : AppTheme.darkTheme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isConvenzione
                              ? Colors.teal.shade400
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isConvenzione
                                ? Icons.handshake
                                : Icons.handshake_outlined,
                            color: _isConvenzione
                                ? Colors.teal.shade200
                                : Colors.white54,
                            size: 20,
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Text(
                              'Piano in convenzione',
                              style: TextStyle(
                                color: _isConvenzione
                                    ? Colors.teal.shade100
                                    : Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          Switch(
                            value: _isConvenzione,
                            onChanged: (val) {
                              setDialogState(() {
                                _isConvenzione = val;
                              });
                            },
                            activeThumbColor: Colors.teal.shade300,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isConvenzione) ...[
                    SizedBox(height: 0.8.h),
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.teal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.teal.shade300,
                            size: 14,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'Questo piano sarà visibile solo nella pagina "Piani in Convenzione".',
                              style: TextStyle(
                                color: Colors.teal.shade200,
                                fontSize: 11.sp,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // ─────────────────────────────────────────────────────
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common.cancel'.tr(),
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final amount = double.parse(
                      amountController.text.replaceAll(',', '.'),
                    );
                    final planName = nameController.text.trim();
                    final lower = planName.toLowerCase();
                    final isAnnual = lower.contains('iscrizione') ||
                        lower.contains('annuale');

                    // Parse entry count for unlimited plans
                    int? entryCount;
                    if (_isUnlimited &&
                        entryCountController.text.trim().isNotEmpty) {
                      entryCount = int.tryParse(
                        entryCountController.text.trim(),
                      );
                    }

                    await Supabase.instance.client
                        .from('custom_subscription_plans')
                        .insert({
                      'name': planName,
                      'external_url': urlController.text.trim(),
                      'amount': amount,
                      'is_active': true,
                      'is_unlimited': _isUnlimited && !isAnnual,
                      'entry_count':
                          (_isUnlimited && !isAnnual) ? entryCount : null,
                      'duration_months': isAnnual
                          ? 0
                          : (_isUnlimited ? 0 : _selectedDurationMonths),
                      'is_convenzione': _isConvenzione,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      Fluttertoast.showToast(
                        msg: 'Piano abbonamento creato con successo',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                      );
                      _loadCustomPlans();
                    }
                  } catch (e) {
                    Fluttertoast.showToast(
                      msg: 'Errore durante la creazione: $e',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Crea Piano',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlanDialog({
    required Map<String, dynamic> plan,
    required bool isCustomPlan,
  }) {
    final nameController = TextEditingController(
      text: isCustomPlan
          ? (plan['name'] as String? ?? '')
          : (plan['title'] as String? ?? ''),
    );
    final urlController = TextEditingController(
      text: isCustomPlan
          ? (plan['external_url'] as String? ?? '')
          : (plan['sumupUrl'] as String? ?? ''),
    );
    final amountController = TextEditingController(
      text: isCustomPlan
          ? ((plan['amount'] as num?)?.toString() ?? '')
          : ((plan['price'] as num?)?.toString() ?? ''),
    );
    final formKey = GlobalKey<FormState>();

    // Color picker state — initialise from current plan color
    int _selectedColor = (plan['color'] as int?) ??
        _getColorForPlanName(
          isCustomPlan
              ? (plan['name'] as String? ?? '')
              : (plan['title'] as String? ?? ''),
        );

    // Predefined palette of colors to choose from
    final List<int> _colorPalette = [
      0xFFFF5722, // Deep Orange (MMA)
      0xFF2196F3, // Blue (BJJ)
      0xFF4CAF50, // Green (Sambo)
      0xFF9C27B0, // Purple (Grappling)
      0xFFE91E63, // Pink (Kickboxing)
      0xFFFF9800, // Orange (Muay Thai)
      0xFF00BCD4, // Cyan (Judo)
      0xFFF44336, // Red (Karate)
      0xFF795548, // Brown (Wrestling)
      0xFF607D8B, // Blue Grey (Boxing)
      0xFF5D4037, // Dark Brown (Annual)
      0xFF546E7A, // Neutral Grey
      0xFF1976D2, // Dark Blue
      0xFF7B1FA2, // Dark Purple
      0xFF2E7D32, // Dark Green
      0xFFD32F2F, // Dark Red
      0xFFFFC107, // Amber
      0xFF009688, // Teal
      0xFF3F51B5, // Indigo
      0xFF8BC34A, // Light Green
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, color: Colors.blue, size: 24),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'Modifica Piano',
                  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nome Abbonamento',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Es: Piano Premium',
                      filled: true,
                      fillColor: AppTheme.darkTheme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.title, color: Colors.blue),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il nome dell\'abbonamento';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Link/URL Esterno',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextFormField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      filled: true,
                      fillColor: AppTheme.darkTheme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.link, color: Colors.blue),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il link esterno';
                      }
                      if (!value.startsWith('http://') &&
                          !value.startsWith('https://')) {
                        return 'Inserisci un URL valido (http:// o https://)';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Importo (€)',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      filled: true,
                      fillColor: AppTheme.darkTheme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.euro, color: Colors.blue),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci l\'importo';
                      }
                      final amount = double.tryParse(
                        value.replaceAll(',', '.'),
                      );
                      if (amount == null || amount <= 0) {
                        return 'Inserisci un importo valido';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 2.h),
                  // ── Color picker section ──────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Colore Piano',
                        style: AppTheme.darkTheme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 3.w),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(_selectedColor),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 1.h,
                    children: _colorPalette.map((colorValue) {
                      final isSelected = _selectedColor == colorValue;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            _selectedColor = colorValue;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : Border.all(
                                    color: Colors.transparent,
                                    width: 3,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(
                                        colorValue,
                                      ).withValues(alpha: 0.6),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  // ─────────────────────────────────────────────────────
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common.cancel'.tr(),
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeletePlanDialog(plan: plan, isCustomPlan: isCustomPlan);
              },
              child: Text(
                'Elimina',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final updatedName = nameController.text.trim();
                  final updatedUrl = urlController.text.trim();
                  final updatedAmount = double.parse(
                    amountController.text.replaceAll(',', '.'),
                  );

                  if (isCustomPlan) {
                    await Supabase.instance.client
                        .from('custom_subscription_plans')
                        .update({
                      'name': updatedName,
                      'external_url': updatedUrl,
                      'amount': updatedAmount,
                      'color': _selectedColor,
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', plan['id']);
                  } else {
                    final dbId = plan['dbId'] ?? plan['id'];
                    await Supabase.instance.client
                        .from('subscription_plans')
                        .update({
                      'name': updatedName,
                      'price': updatedAmount,
                      'sumup_url': updatedUrl,
                      'color': _selectedColor,
                      'updated_at': DateTime.now().toIso8601String(),
                    }).eq('id', dbId.toString());
                  }

                  if (!mounted) return;

                  Navigator.pop(context);
                  Fluttertoast.showToast(
                    msg: 'Piano aggiornato con successo',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                  );

                  if (isCustomPlan) {
                    await _loadCustomPlans();
                  } else {
                    await _loadStandardPlans();
                  }
                } catch (e) {
                  Fluttertoast.showToast(
                    msg: 'Errore durante l\'aggiornamento: $e',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'common.save'.tr(),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeletePlanDialog({
    required Map<String, dynamic> plan,
    required bool isCustomPlan,
  }) {
    final planName = isCustomPlan
        ? (plan['name'] as String? ?? 'Piano')
        : (plan['title'] as String? ?? 'Piano');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_forever, color: Colors.red, size: 24),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                'Elimina Piano',
                style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Sei sicuro di voler eliminare il piano "$planName"? Questa azione non può essere annullata.',
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (isCustomPlan) {
                  await Supabase.instance.client
                      .from('custom_subscription_plans')
                      .update({'is_active': false}).eq('id', plan['id']);
                } else {
                  final dbId = plan['dbId'] ?? plan['id'];
                  await Supabase.instance.client
                      .from('subscription_plans')
                      .update({'is_active': false}).eq('id', dbId.toString());
                }

                if (!mounted) return;

                Navigator.pop(context);
                Fluttertoast.showToast(
                  msg: 'Piano "$planName" eliminato con successo',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                );

                if (isCustomPlan) {
                  await _loadCustomPlans();
                } else {
                  await _loadStandardPlans();
                }
              } catch (e) {
                Navigator.pop(context);
                Fluttertoast.showToast(
                  msg: 'Errore durante l\'eliminazione: $e',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Elimina',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPaymentConfirmation();
      // Fresh fetch every time app comes back to foreground
      _loadStandardPlans();
      _loadCustomPlans();
    }
  }

  Future<void> _checkPaymentConfirmation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPaymentPending = prefs.getBool('isPaymentPending') ?? false;

      if (isPaymentPending && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.paymentHistory);
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _launchSumUpUrl(String url, String planTitle) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Parse the URL
      final String sanitizedUrl = url.trim();
      final Uri uri = Uri.parse(sanitizedUrl);

      // 2. Call launchUrl immediately, before any await on SharedPreferences
      HapticFeedback.lightImpact();
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Launch returned false');
      }

      // 3. Do SharedPreferences writes after launchUrl returns
      final selectedPlan = _allPlans.firstWhere(
        (plan) => plan['title'] == planTitle,
        orElse: () => <String, dynamic>{},
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', true);
      await prefs.setString(
        'pendingPlanId',
        (selectedPlan['id'] ?? '').toString(),
      );
      await prefs.setString('pendingPlanTitle', planTitle);
      await prefs.setDouble(
        'pendingPlanAmount',
        (selectedPlan['price'] as num?)?.toDouble() ?? 0.0,
      );
      await prefs.setString('pendingPaymentMethod', 'sumup');

      // 🆕 Best-effort bookkeeping row for the "click" — no auto-activation
      // for SumUp, this is only used for tracking. Never blocks the flow.
      try {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId != null) {
          final insertedRow = await Supabase.instance.client
              .from('payment_intents')
              .insert({
                'user_id': currentUserId,
                'provider': 'sumup',
                'custom_plan_id': selectedPlan['id'],
                'plan_name': planTitle,
                'amount': (selectedPlan['price'] as num?)?.toDouble() ?? 0.0,
                'beneficiary_profile_id': ChildProfileService.getActiveUserId(),
              })
              .select('id')
              .single();
          final intentId = insertedRow['id'] as String?;
          if (intentId != null) {
            await prefs.setString('pendingIntentId', intentId);
          }
        }
      } catch (_) {
        // Ignore — this is only a best-effort click record.
      }
    } catch (error) {
      print('Error launching SumUp URL: $error');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedPlanId = null;
        });
      }
    }
  }

  // MODIFIED: Add enrollment check logic for SumUp
  Future<void> _handlePlanSelection(Map<String, dynamic> plan) async {
    try {
      if (_isPrincipalAdmin) {
        final isCustomPlan = !(plan['isStandardFromDb'] == true);
        _showEditPlanDialog(plan: plan, isCustomPlan: isCustomPlan);
        return;
      }

      final planTitle = plan['title'] as String? ?? '';
      final planType = plan['planType'] as String? ?? '';
      final isAnnualRegistration = planType == 'annual' ||
          planTitle.toLowerCase().contains('iscrizione annuale');

      // RULE 1: If buying Annual Registration, skip checks and proceed
      if (isAnnualRegistration) {
        setState(() {
          _selectedPlanId = int.tryParse(plan['id'].toString());
          _hasAnnualRegistration = true;
        });
        _launchSumUpUrl(plan['sumupUrl'] as String? ?? '', planTitle);
        return;
      }

      // RULE 2: Use already-loaded _hasAnnualRegistration state (avoids consuming
      // the user-gesture permission on iOS Safari with an async await before launchUrl).
      if (!_hasAnnualRegistration) {
        _showAnnualRegistrationRequiredDialog();
        return;
      }

      // User has annual registration — proceed with payment
      if (mounted) {
        setState(() {
          _selectedPlanId = int.tryParse(plan['id'].toString());
        });
      }
      _launchSumUpUrl(plan['sumupUrl'] as String? ?? '', planTitle);
    } catch (error) {
      print('ERROR _handlePlanSelection: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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

  // DIALOG: Show when annual registration is required
  void _showAnnualRegistrationRequiredDialog() {
    // Find the annual plan — search all plans (standard + custom)
    Map<String, dynamic> annualPlan = _allPlans.firstWhere(
      (plan) =>
          (plan['planType'] as String? ?? '') == 'annual' ||
          (plan['title'] as String? ?? '').toLowerCase().contains(
                'iscrizione annuale',
              ),
      orElse: () => <String, dynamic>{},
    );

    // If not found in standard plans, search custom plans by name
    if (annualPlan.isEmpty) {
      final customAnnual = _customPlans.where(
        (p) => (p['name'] as String? ?? '').toLowerCase().contains(
              'iscrizione annuale',
            ),
      );
      if (customAnnual.isNotEmpty) {
        final cp = customAnnual.first;
        annualPlan = {
          'id': cp['id'],
          'title': cp['name'] as String? ?? 'Iscrizione Annuale',
          'sumupUrl': cp['external_url'] as String? ?? '',
          'planType': 'annual',
          'isCustomPlan': true,
        };
      }
    }

    // Fallback: use last plan if still empty
    if (annualPlan.isEmpty && _allPlans.isNotEmpty) {
      annualPlan = _allPlans.last;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.colorScheme.surface,
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'warning',
              color: const Color(0xFFF39C12),
              size: 28,
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                'Non sei ancora iscritto!',
                style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF39C12),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Procedi prima all\'acquisto dell\'iscrizione annuale, dopo potrai scegliere il tuo piano di abbonamento.',
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'class_schedule.close_modal'.tr(),
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (annualPlan.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _handlePlanSelection(annualPlan);
              },
              icon: CustomIconWidget(
                iconName: 'credit_card',
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Acquista Iscrizione',
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkTheme.colorScheme.secondary,
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              ),
            ),
        ],
      ),
    );
  }

  void _showSubscriptionPlans() {
    // Always open the plan list immediately — the gate fires only when a plan is tapped.
    setState(() {
      _showSubscriptionOptions = true;
    });

    // Refresh enrollment status in background so the lock UI stays up-to-date.
    PaymentService.checkHasAnnualRegistration().then((hasAnnual) {
      if (!mounted) return;
      setState(() {
        _hasAnnualRegistration = hasAnnual;
        _isLoadingEnrollmentStatus = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _hasAnnualRegistration = false;
        _isLoadingEnrollmentStatus = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkTheme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.darkTheme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.darkTheme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (_isSatispayMode) {
              if (_showSatispayConvenzioni) {
                // Leave the convenzioni sub-list, back to the main Satispay
                // plan list — a single back tap should not leave the screen.
                setState(() => _showSatispayConvenzioni = false);
              } else {
                // Satispay entry point always starts on the plan list — a
                // single back tap should just leave the screen.
                Navigator.pop(context);
              }
            } else if (_showSubscriptionOptions) {
              setState(() {
                _showSubscriptionOptions = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isSatispayMode && _showSatispayConvenzioni
              ? 'Piani in Convenzione'
              : (_showSubscriptionOptions ? 'Selezione Piano' : 'Team Ragnarok'),
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkTheme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingEnrollmentStatus
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.darkTheme.colorScheme.secondary,
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isSatispayMode
                  ? _buildSatispayPlansView()
                  : (_showSubscriptionOptions
                      ? _buildSubscriptionOptionsView()
                      : _buildInitialView()),
            ),
    );
  }

  /// 🆕 SATISPAY MODE — same rule as SumUp's _handlePlanSelection: a plan
  /// counts as the annual registration if its (derived) planType is
  /// 'annual' or its title contains "iscrizione annuale". Satispay plans
  /// have no explicit plan_type field, so it is derived the same way the
  /// rest of this screen derives it for custom plans (name-based match).
  bool _isSatispayAnnualRegistrationPlan(Map<String, dynamic> rawPlan) {
    final name = (rawPlan['name'] as String? ?? '').toLowerCase();
    final planType =
        (name.contains('iscrizione') || name.contains('annuale'))
            ? 'annual'
            : 'monthly';
    return planType == 'annual' || name.contains('iscrizione annuale');
  }

  /// 🆕 SATISPAY MODE: finds the annual registration plan across the full
  /// Satispay plan list (main + convenzioni), for the "Acquista Iscrizione"
  /// CTA in _showSatispayAnnualRegistrationRequiredDialog.
  Map<String, dynamic>? _findSatispayAnnualPlan() {
    for (final p in _satispayPlans) {
      if (_isSatispayAnnualRegistrationPlan(p)) return p;
    }
    return null;
  }

  /// 🆕 SATISPAY MODE: same enrollment gate as SumUp — any plan that isn't
  /// the annual registration requires _hasAnnualRegistration; otherwise
  /// shows the "Non sei ancora iscritto!" dialog and starts no payment.
  /// The annual registration itself is always purchasable. Applies to both
  /// the main list and the convenzioni sub-list.
  void _handleSatispayPlanTap(Map<String, dynamic> rawPlan) {
    if (!_isSatispayAnnualRegistrationPlan(rawPlan) &&
        !_hasAnnualRegistration) {
      _showSatispayAnnualRegistrationRequiredDialog();
      return;
    }
    _launchSatispayForPlan(rawPlan);
  }

  /// 🆕 SATISPAY MODE — mirrors _showAnnualRegistrationRequiredDialog
  /// (SumUp) exactly in appearance/text, but its CTA launches the Satispay
  /// payment for the annual plan instead of the SumUp flow.
  void _showSatispayAnnualRegistrationRequiredDialog() {
    final annualPlan = _findSatispayAnnualPlan();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.colorScheme.surface,
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'warning',
              color: const Color(0xFFF39C12),
              size: 28,
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                'Non sei ancora iscritto!',
                style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF39C12),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Procedi prima all\'acquisto dell\'iscrizione annuale, dopo potrai scegliere il tuo piano di abbonamento.',
          style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'class_schedule.close_modal'.tr(),
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (annualPlan != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchSatispayForPlan(annualPlan);
              },
              icon: CustomIconWidget(
                iconName: 'credit_card',
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Acquista Iscrizione',
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkTheme.colorScheme.secondary,
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              ),
            ),
        ],
      ),
    );
  }

  /// 🆕 SATISPAY MODE view: the main Satispay plan list (is_convenzione ==
  /// false) or, when _showSatispayConvenzioni is true, the convenzioni-only
  /// sub-list (is_convenzione == true) — same split as SumUp's separate
  /// PianiConvenzioneScreen, same enrollment gate/banner, same Satispay
  /// payment (_launchSatispayForPlan) for both. Isolated from
  /// _buildSubscriptionOptionsView (SumUp/admin) so that view is untouched.
  Widget _buildSatispayPlansView() {
    if (_isLoadingSatispayPlans) {
      return Center(
        key: const ValueKey('satispay-loading'),
        child: CircularProgressIndicator(
          color: AppTheme.darkTheme.colorScheme.secondary,
        ),
      );
    }

    final plans =
        _showSatispayConvenzioni ? _satispayConvenzionePlans : _satispayMainPlans;

    return Column(
      key: ValueKey(
        _showSatispayConvenzioni ? 'satispay-convenzioni' : 'satispay-main',
      ),
      children: [
        // 🔒 ENROLLMENT GATE BANNER — same as SumUp's, shown on both the
        // main list and the convenzioni sub-list.
        if (!_isLoadingEnrollmentStatus && !_hasAnnualRegistration)
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
            child: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.red, size: 20),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'Iscrizione Annuale Richiesta',
                          style:
                              AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.8.h),
                  Text(
                    'Prima di acquistare un abbonamento devi acquistare l\'Iscrizione Annuale. Cerca il piano "Iscrizione Annuale" qui sotto.',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade200,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Clickable "Abbonamenti in convenzione" banner — only on the main
        // list, same text/style as SumUp's.
        if (!_showSatispayConvenzioni)
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
            child: GestureDetector(
              onTap: () => setState(() => _showSatispayConvenzioni = true),
              child: Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      color: Colors.teal.shade300,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Abbonamenti in convenzione - Clicca qui per scoprirli',
                        style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                          color: Colors.teal.shade300,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.teal.shade300,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),

        Expanded(
          child: plans.isEmpty
              ? Center(
                  key: const ValueKey('satispay-empty'),
                  child: Padding(
                    padding: EdgeInsets.all(6.w),
                    child: Text(
                      'Nessun piano disponibile al momento.',
                      textAlign: TextAlign.center,
                      style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : GridView.builder(
                  key: const ValueKey('satispay-plans'),
                  padding: EdgeInsets.all(4.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 3.w,
                    mainAxisSpacing: 3.w,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final rawPlan = plans[index];
                    final cardPlan = _toSatispayCardPlan(rawPlan);
                    final planId = rawPlan['id'] as String?;
                    final isLaunching = _launchingSatispayPlanId == planId;
                    return SubscriptionOptionCardWidget(
                      plan: cardPlan,
                      isLoading: isLaunching,
                      onTap: (_launchingSatispayPlanId != null)
                          ? () {}
                          : () => _handleSatispayPlanTap(rawPlan),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInitialView() {
    return Container(
      key: const ValueKey('initial'),
      padding: EdgeInsets.all(6.w),
      child: Column(
        children: [
          // Header with Team Logo
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.darkTheme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.darkTheme.colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/149054-1756525854643.jpg',
                      width: 25.w,
                      height: 25.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Team Ragnarok',
                  style: AppTheme.darkTheme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkTheme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Scegli il tuo piano di allenamento\ne inizia il tuo percorso',
                  textAlign: TextAlign.center,
                  style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Choose Plan Button
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: 7.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.darkTheme.colorScheme.secondary,
                        AppTheme.darkTheme.colorScheme.secondary.withValues(
                          alpha: 0.8,
                        ),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.darkTheme.colorScheme.secondary
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showSubscriptionPlans,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomIconWidget(
                              iconName: 'payment',
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Scegli Piano',
                              style: AppTheme.darkTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            CustomIconWidget(
                              iconName: 'arrow_forward',
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: AppTheme.darkTheme.colorScheme.primaryContainer
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.darkTheme.colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'security',
                        color: AppTheme.darkTheme.colorScheme.primary,
                        size: 24,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          'Pagamenti sicuri tramite SumUp con crittografia SSL',
                          style:
                              AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkTheme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOptionsView() {
    return CustomScrollView(
      key: const ValueKey('options'),
      slivers: [
        // Compact Header
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/149054-1756525854643.jpg',
                    width: 15.w,
                    height: 15.w,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Team Ragnarok',
                  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkTheme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 🔥 CHILD PROFILE CONTEXT BANNER
        if (_isChildProfileActive && _activeChildProfile != null)
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.h),
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.child_care,
                        color: Color(0xFFFF0000),
                        size: 18,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'Stai acquistando per: ${_activeChildProfile!['full_name'] ?? '${_activeChildProfile!['first_name'] ?? ''} ${_activeChildProfile!['last_name'] ?? ''}'.trim()}',
                          style:
                              AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'L\'abbonamento sarà associato al profilo del minore. La ricevuta sarà intestata a te.',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                      height: 1.3,
                    ),
                  ),
                  if (_guardianHasDiscount) ...[
                    SizedBox(height: 0.8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.5.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_offer,
                            color: Colors.green,
                            size: 14,
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            '🎉 Sconto attivo: Total Submission Kids €45 invece di €50',
                            style: AppTheme.darkTheme.textTheme.bodySmall
                                ?.copyWith(
                              color: Colors.green[300],
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
          ),

        // 🔒 ENROLLMENT GATE BANNER — shown when user has no annual registration
        // This is a hard UI lock: non-annual plans are visually disabled.
        if (!_isPrincipalAdmin &&
            !_isLoadingEnrollmentStatus &&
            !_hasAnnualRegistration)
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.h),
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.red, size: 20),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'Iscrizione Annuale Richiesta',
                          style:
                              AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.8.h),
                  Text(
                    'Prima di acquistare un abbonamento devi acquistare l\'Iscrizione Annuale. Cerca il piano "Iscrizione Annuale" qui sotto.',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.red.shade200,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Entry-based plans notice
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'new_releases',
                  color: Colors.green.shade400,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'NUOVO: Piani ad ingresso singolo o multiplo - non scadono mai!',
                    style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade300,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Clickable "Abbonamenti in convenzione" banner
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.pianiConvenzione);
            },
            child: Container(
              margin: EdgeInsets.fromLTRB(4.w, 0.h, 4.w, 1.h),
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.teal.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    color: Colors.teal.shade300,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'Abbonamenti in convenzione - Clicca qui per scoprirli',
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: Colors.teal.shade300,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.teal.shade300,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Subscription Plans Grid
        if (_isLoadingStandardPlans)
          SliverToBoxAdapter(
            child: Container(
              height: 30.h,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.darkTheme.colorScheme.secondary,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Caricamento piani...',
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_allPlans.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              height: 30.h,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'cloud_off',
                    color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                    size: 48,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Impossibile caricare i piani',
                    style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoadingStandardPlans = true;
                      });
                      _loadStandardPlans();
                      _loadCustomPlans();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Riprova'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkTheme.colorScheme.primary,
                      foregroundColor: AppTheme.darkTheme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.58,
                crossAxisSpacing: 3.w,
                mainAxisSpacing: 2.h,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final plan = _allPlans[index];
                final isLoading = _isLoading && _selectedPlanId == plan['id'];
                final planType = plan['planType'] as String? ?? '';
                final planTitle =
                    (plan['title'] as String? ?? '').toLowerCase();
                final isAnnualPlan = planType == 'annual' ||
                    planTitle.contains('iscrizione annuale');
                // Lock non-annual plans when user has no annual registration
                // (admin is never locked)
                final isLocked = !_isPrincipalAdmin &&
                    !_isLoadingEnrollmentStatus &&
                    !_hasAnnualRegistration &&
                    !isAnnualPlan;

                return SubscriptionOptionCardWidget(
                  plan: plan,
                  onTap: () => _handlePlanSelection(plan),
                  isLoading: isLoading,
                  isLocked: false,
                );
              }, childCount: _allPlans.length),
            ),
          ),

        // Add plan button for principal admin
        if (_isPrincipalAdmin)
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 2.h),
              child: GestureDetector(
                onTap: _showAddPlanDialog,
                child: Container(
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: AppTheme.darkTheme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, color: Colors.amber, size: 40),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Aggiungi Piano',
                        style:
                            AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Bottom spacing
        SliverToBoxAdapter(child: SizedBox(height: 2.h)),
      ],
    );
  }
}
