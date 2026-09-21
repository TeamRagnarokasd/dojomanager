import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../services/feature_flags_service.dart';
import '../../services/payment_service.dart';
import '../subscription_plan_selection/widgets/subscription_option_card_widget.dart';

class PianiConvenzioneScreen extends StatefulWidget {
  const PianiConvenzioneScreen({Key? key}) : super(key: key);

  @override
  State<PianiConvenzioneScreen> createState() => _PianiConvenzioneScreenState();
}

class _PianiConvenzioneScreenState extends State<PianiConvenzioneScreen> {
  bool _isPrincipalAdmin = false;
  bool _isLoading = false;
  int? _selectedPlanId;

  List<Map<String, dynamic>> _convenzionePlans = [];
  bool _isLoadingPlans = true;

  // ENROLLMENT CHECK: same logic as subscription_plan_selection
  bool _hasAnnualRegistration = false;
  bool _isLoadingEnrollmentStatus = true;

  // 🆕 Read ahead of time (never awaited right before launchUrl) so that
  // with the flag off, tapping a plan launches the fixed SumUp link
  // synchronously — exactly like today. See _startSumUpPayment.
  bool _sumupAutoConfirm = false;

  void _loadSumUpAutoConfirmFlag() {
    FeatureFlagsService.instance.isEnabled('sumup_auto_confirm').then((v) {
      if (mounted) setState(() => _sumupAutoConfirm = v);
    });
  }

  int _getColorForPlanName(String name) {
    final lower = name.toLowerCase();
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
    return 0xFF546E7A;
  }

  @override
  void initState() {
    super.initState();
    _loadSumUpAutoConfirmFlag();
    _checkPrincipalAdminStatus();
    _loadConvenzionePlans();
    _checkEnrollmentStatus();
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

  Future<void> _loadConvenzionePlans() async {
    try {
      final response = await Supabase.instance.client
          .from('custom_subscription_plans')
          .select('*')
          .eq('is_active', true)
          .eq('is_convenzione', true)
          .order('created_at', ascending: false);

      final plans = List<Map<String, dynamic>>.from(response);
      final List<Map<String, dynamic>> mapped = [];

      for (final cp in plans) {
        final planName = cp['name'] as String? ?? '';
        final amount = (cp['amount'] as num?)?.toDouble() ?? 0.0;
        final lower = planName.toLowerCase();
        final isAnnual =
            lower.contains('iscrizione') || lower.contains('annuale');
        final isUnlimited = cp['is_unlimited'] as bool? ?? false;
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

        mapped.add({
          'id': cp['id'],
          'dbId': cp['id'],
          'title': planName,
          'name': planName,
          'price': amount,
          'amount': amount,
          'frequency': frequency,
          'disciplines': [''],
          'classesPerWeek': 0,
          'entryBased': isUnlimited && entryCount != null,
          'entryCount': entryCount ?? 0,
          'benefits': <String>[],
          'sumupUrl': cp['external_url'] as String? ?? '',
          'external_url': cp['external_url'] as String? ?? '',
          'color': resolvedColor,
          'isStandardFromDb': false,
          'isCustomPlan': true,
          'planType':
              isAnnual ? 'annual' : (isUnlimited ? 'unlimited' : 'monthly'),
          'duration_months': durationMonths,
          'is_unlimited': isUnlimited,
          'is_convenzione': true,
        });
      }

      if (mounted) {
        setState(() {
          _convenzionePlans = mapped;
          _isLoadingPlans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlans = false;
        });
      }
    }
  }

  Future<void> _launchSumUpUrl(
    String url,
    String planTitle, {
    String? planId,
    double? planAmount,
  }) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', true);
      await prefs.setString('pendingPlanTitle', planTitle);
      if (planId != null && planId.isNotEmpty) {
        await prefs.setString('pendingPlanId', planId);
      }
      if (planAmount != null && planAmount > 0) {
        await prefs.setDouble('pendingPlanAmount', planAmount);
      }
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
                'custom_plan_id': (planId != null && planId.isNotEmpty)
                    ? planId
                    : null,
                'plan_name': planTitle,
                'amount': planAmount ?? 0.0,
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

      HapticFeedback.lightImpact();

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await prefs.setBool('isPaymentPending', false);
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'common.link_open_error'.tr(),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    } catch (error) {
      print('Error launching SumUp URL: $error');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', false);
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'common.link_open_failed'.tr(),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
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

  void _handlePlanSelection(Map<String, dynamic> plan) {
    if (_isPrincipalAdmin) {
      _showEditPlanDialog(plan: plan);
      return;
    }
    // Same logic as /selezione-piano: check annual registration
    if (!_hasAnnualRegistration) {
      _showAnnualRegistrationRequiredDialog();
      return;
    }
    // User has annual registration — start the payment
    _startSumUpPayment(plan);
  }

  /// Opens a payment redirect page created via 'sumup/create-payment'. On
  /// mobile this is the usual external-browser hand-off; on web (kIsWeb) it
  /// navigates the SAME tab (webOnlyWindowName: '_self') instead of a new
  /// one — by the time create-payment returns, the network wait has used up
  /// the browser's "user gesture" allowance and Safari on iPhone silently
  /// blocks a new-tab window.open() in that case.
  Future<bool> _launchPaymentRedirectUrl(Uri uri) {
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_self');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 🆕 SumUp, 'sumup_auto_confirm' on: creates the payment intent via the
  /// 'sumup/create-payment' Edge Function (the server creates the
  /// payment_intents click, with provider_payment_id set) and opens the
  /// redirect page. isPaymentPending/pendingIntentId ARE set, same as
  /// today's fixed-link flow, so SumUpWaitingSheet (opened by whichever
  /// screen reads isPaymentPending on resume) can watch this specific
  /// click by id instead of showing the old "did you pay?" dialog. On
  /// failure, shows a message and offers (only if the user agrees) today's
  /// fixed-link SumUp flow, unchanged.
  Future<void> _launchSumUpForPlan(Map<String, dynamic> plan) async {
    final planId = (plan['id'] ?? plan['dbId'])?.toString();
    final planTitle = plan['title'] as String? ?? plan['name'] as String? ?? '';
    final planAmount = (plan['price'] as num?)?.toDouble() ??
        (plan['amount'] as num?)?.toDouble() ??
        0.0;
    if (planId == null || planId.isEmpty) {
      await _offerFixedSumUpLinkFallback(plan);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'sumup/create-payment',
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
      final intentId = data is Map ? data['intent_id'] as String? : null;

      if (redirectUrl == null ||
          redirectUrl.isEmpty ||
          intentId == null ||
          intentId.isEmpty) {
        throw Exception(
          'Missing redirect_url/intent_id in sumup create-payment response',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', true);
      await prefs.setString('pendingPaymentMethod', 'sumup');
      await prefs.setString('pendingPlanTitle', planTitle);
      await prefs.setString('pendingPlanId', planId);
      if (planAmount > 0) {
        await prefs.setDouble('pendingPlanAmount', planAmount);
      }
      await prefs.setString('pendingIntentId', intentId);

      final opened = await _launchPaymentRedirectUrl(Uri.parse(redirectUrl));
      if (!opened) {
        throw Exception('launchUrl returned false');
      }
    } catch (e) {
      print('Error creating SumUp payment: $e');
      await _offerFixedSumUpLinkFallback(plan);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedPlanId = null;
        });
      }
    }
  }

  /// 🆕 SumUp create-payment fallback: shows a message explaining the new
  /// flow couldn't start, and — only if the user explicitly agrees —
  /// reproduces today's fixed-link SumUp flow (_launchSumUpUrl, unchanged).
  Future<void> _offerFixedSumUpLinkFallback(Map<String, dynamic> plan) async {
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
              'Non è stato possibile avviare il pagamento SumUp per questo '
              'piano. Vuoi provare con il link diretto di SumUp?',
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
    _launchFixedSumUpUrl(plan);
  }

  /// Dispatches a SumUp payment: uses the new create-payment flow when
  /// 'sumup_auto_confirm' is on and the plan has a valid id, otherwise
  /// falls back to today's fixed-link flow unchanged — with the flag off
  /// this always takes the fixed-link branch, so nothing changes.
  ///
  /// _sumupAutoConfirm is read synchronously (no await before deciding):
  /// with the flag off (or not loaded yet), _launchFixedSumUpUrl fires
  /// immediately after the tap exactly like today, with no extra wait
  /// before its own launchUrl.
  void _startSumUpPayment(Map<String, dynamic> plan) {
    final planId = (plan['id'] ?? plan['dbId'])?.toString();
    if (_sumupAutoConfirm && planId != null && planId.isNotEmpty) {
      _launchSumUpForPlan(plan);
      return;
    }
    _launchFixedSumUpUrl(plan);
  }

  /// Today's fixed-link SumUp flow, unchanged — used both when the flag is
  /// off and as the fallback when the create-payment flow fails.
  void _launchFixedSumUpUrl(Map<String, dynamic> plan) {
    final url =
        plan['sumupUrl'] as String? ?? plan['external_url'] as String? ?? '';
    final title = plan['title'] as String? ?? plan['name'] as String? ?? '';
    final planId = (plan['id'] ?? plan['dbId'] ?? '').toString();
    final planAmount = (plan['price'] as num?)?.toDouble() ??
        (plan['amount'] as num?)?.toDouble() ??
        0.0;
    if (url.isNotEmpty) {
      _launchSumUpUrl(url, title, planId: planId, planAmount: planAmount);
    } else {
      Fluttertoast.showToast(
        msg: 'Nessun link di pagamento disponibile per questo piano.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // DIALOG: "Non sei ancora iscritto!" — identical to subscription_plan_selection
  void _showAnnualRegistrationRequiredDialog() {
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
              'Chiudi',
              style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // go back to selezione-piano
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

  void _showEditPlanDialog({required Map<String, dynamic> plan}) {
    final nameController = TextEditingController(
      text: plan['name'] as String? ?? '',
    );
    final urlController = TextEditingController(
      text: plan['external_url'] as String? ?? '',
    );
    final amountController = TextEditingController(
      text: (plan['amount'] as num?)?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Modifica Piano',
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    filled: true,
                    fillColor: AppTheme.darkTheme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.title, color: Colors.amber),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Campo obbligatorio'
                      : null,
                ),
                SizedBox(height: 2.h),
                TextFormField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    filled: true,
                    fillColor: AppTheme.darkTheme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.link, color: Colors.amber),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Campo obbligatorio'
                      : null,
                ),
                SizedBox(height: 2.h),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Importo (€)',
                    filled: true,
                    fillColor: AppTheme.darkTheme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.euro, color: Colors.amber),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Campo obbligatorio';
                    if (double.tryParse(v.replaceAll(',', '.')) == null)
                      return 'Importo non valido';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await Supabase.instance.client
                    .from('custom_subscription_plans')
                    .update({
                  'name': nameController.text.trim(),
                  'external_url': urlController.text.trim(),
                  'amount': double.parse(
                    amountController.text.replaceAll(',', '.'),
                  ),
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', plan['id']);
                if (mounted) {
                  Navigator.pop(context);
                  Fluttertoast.showToast(
                    msg: 'Piano aggiornato con successo',
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                  );
                  _loadConvenzionePlans();
                }
              } catch (e) {
                Fluttertoast.showToast(
                  msg: 'Errore: $e',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Salva', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Piani in Convenzione',
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.darkTheme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          // Header
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

          // Convenzione banner
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.h),
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
                      'Abbonamenti riservati ai soci in convenzione',
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: Colors.teal.shade300,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Lock banner — shown when user has no annual registration (same as selezione-piano)
          if (!_isPrincipalAdmin &&
              !_isLoadingEnrollmentStatus &&
              !_hasAnnualRegistration)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.h),
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF39C12).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'lock',
                      color: const Color(0xFFF39C12),
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Acquista prima l\'iscrizione annuale per sbloccare i piani',
                        style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFF39C12),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Plans grid
          if (_isLoadingPlans)
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
          else if (_convenzionePlans.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 30.h,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Nessun piano in convenzione disponibile',
                      style: AppTheme.darkTheme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'I piani in convenzione verranno aggiunti dall\'amministratore',
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.darkTheme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
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
                  final plan = _convenzionePlans[index];
                  final isLoading = _isLoading && _selectedPlanId == plan['id'];

                  // Lock non-annual plans when user has no annual registration
                  // (admin is never locked)
                  final planTitle = plan['title'] as String? ?? '';
                  final planType = plan['planType'] as String? ?? '';
                  final isAnnualPlan = planType == 'annual' ||
                      planTitle.toLowerCase().contains('iscrizione annuale');
                  final isLocked = !_isPrincipalAdmin &&
                      !_isLoadingEnrollmentStatus &&
                      !_hasAnnualRegistration &&
                      !isAnnualPlan;

                  return SubscriptionOptionCardWidget(
                    plan: plan,
                    onTap: isLocked
                        ? () => _showAnnualRegistrationRequiredDialog()
                        : () => _handlePlanSelection(plan),
                    isLoading: isLoading,
                    isLocked: isLocked,
                  );
                }, childCount: _convenzionePlans.length),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).viewPadding.bottom + 2.h,
            ),
          ),
        ],
      ),
    );
  }
}
