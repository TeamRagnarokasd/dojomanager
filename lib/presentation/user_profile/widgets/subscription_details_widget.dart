import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/profile_typography.dart';
import '../../../services/supabase_service.dart';

class SubscriptionDetailsWidget extends StatefulWidget {
  final String? userId;
  final bool autoRenewal;
  final Function(bool) onAutoRenewalChanged;
  final bool isAdminView;

  const SubscriptionDetailsWidget({
    Key? key,
    this.userId,
    required this.autoRenewal,
    required this.onAutoRenewalChanged,
    this.isAdminView = false,
  }) : super(key: key);

  @override
  State<SubscriptionDetailsWidget> createState() =>
      _SubscriptionDetailsWidgetState();
}

class _SubscriptionDetailsWidgetState extends State<SubscriptionDetailsWidget> {
  List<Map<String, dynamic>> _activeSubscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  /// Single source of truth: payment_confirmations joined with custom_subscription_plans
  /// via custom_plan_id. No fallback to old subscription_plans table.
  Future<void> _loadSubscriptionDetails() async {
    try {
      final client = SupabaseService.instance.client;
      final targetUserId = widget.userId ?? client.auth.currentUser?.id ?? '';

      if (targetUserId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // PRIMARY SOURCE: payment_confirmations with custom_plan_id join
      // This is the definitive record of what was purchased and confirmed.
      final paymentsResponse = await client
          .from('payment_confirmations')
          .select('''
            id,
            user_id,
            custom_plan_id,
            amount,
            payment_method,
            status,
            confirmed_at,
            created_at,
            custom_subscription_plans!payment_confirmations_custom_plan_id_fkey(
              id, name, amount, duration_months, entry_count, is_unlimited
            )
          ''')
          .eq('user_id', targetUserId)
          .eq('status', 'confirmed')
          .not('custom_plan_id', 'is', null)
          .order('confirmed_at', ascending: false);

      final payments = List<Map<String, dynamic>>.from(paymentsResponse ?? []);

      if (payments.isEmpty) {
        if (mounted)
          setState(() {
            _activeSubscriptions = [];
            _isLoading = false;
          });
        return;
      }

      // Also fetch user_subscriptions to get expiry dates and entry counts
      // (these are populated by createBatchPaymentAndReceipts)
      final userSubsResponse = await client
          .from('user_subscriptions')
          .select(
            'id, custom_plan_id, entries_remaining, entries_total, expires_at, is_active, purchased_at',
          )
          .eq('user_id', targetUserId)
          .eq('is_active', true)
          .not('custom_plan_id', 'is', null);

      final userSubs = List<Map<String, dynamic>>.from(userSubsResponse ?? []);

      // Build a map: custom_plan_id → user_subscription data
      final Map<String, Map<String, dynamic>> subByPlanId = {};
      for (final sub in userSubs) {
        final planId = sub['custom_plan_id'] as String?;
        if (planId != null) {
          subByPlanId[planId] = sub;
        }
      }

      final List<Map<String, dynamic>> subscriptions = [];
      // Deduplicate by custom_plan_id — show one entry per plan
      final Set<String> seenPlanIds = {};

      for (final payment in payments) {
        final customPlanId = payment['custom_plan_id'] as String?;
        if (customPlanId == null) continue;

        // Skip duplicates (same plan purchased multiple times — show most recent)
        if (seenPlanIds.contains(customPlanId)) continue;
        seenPlanIds.add(customPlanId);

        final customPlan =
            payment['custom_subscription_plans'] as Map<String, dynamic>?;
        if (customPlan == null) continue;

        final planName = customPlan['name'] as String? ?? 'Abbonamento';
        final planAmount = customPlan['amount'];
        final durationMonths =
            (customPlan['duration_months'] as num?)?.toInt() ?? 1;
        final entryCount = (customPlan['entry_count'] as num?)?.toInt() ?? 0;
        final isUnlimited = customPlan['is_unlimited'] as bool? ?? false;

        // Determine plan type from name and properties
        final planType = _inferPlanType(
          planName,
          durationMonths,
          entryCount,
          isUnlimited,
        );

        // Get expiry and entry data from user_subscriptions if available
        final userSub = subByPlanId[customPlanId];
        final expiresAt = userSub?['expires_at'] as String?;
        final entriesTotal =
            (userSub?['entries_total'] as num?)?.toInt() ?? entryCount;
        final entriesRemaining =
            (userSub?['entries_remaining'] as num?)?.toInt() ?? entryCount;

        // For annual plans, compute expiry if not in user_subscriptions
        String? computedExpiry = expiresAt;
        if (planType == 'annual') {
          // Annual always uses 28/08 logic regardless of user_subscriptions
          final now = DateTime.now();
          final august28ThisYear = DateTime(now.year, 8, 28);
          final expiryYear =
              now.isBefore(august28ThisYear) ||
                  now.isAtSameMomentAs(august28ThisYear)
              ? now.year
              : now.year + 1;
          computedExpiry = DateTime(expiryYear, 8, 28).toIso8601String();
        } else if (computedExpiry == null && planType == 'monthly') {
          // Monthly: compute from confirmed_at + duration_months
          final confirmedAtStr = payment['confirmed_at'] as String?;
          if (confirmedAtStr != null) {
            try {
              final confirmedDate = DateTime.parse(confirmedAtStr);
              computedExpiry = confirmedDate
                  .add(Duration(days: 30 * durationMonths))
                  .toIso8601String();
            } catch (_) {}
          }
        }

        subscriptions.add({
          'id': payment['id'],
          'user_subscription_id': userSub?['id'],
          'custom_plan_id': customPlanId,
          'is_active': true,
          'confirmed_at': payment['confirmed_at'],
          'created_at': payment['created_at'],
          'expires_at': computedExpiry,
          'entries_total': entriesTotal,
          'entries_remaining': entriesRemaining,
          'amount': planAmount ?? payment['amount'],
          'payment_method': payment['payment_method'],
          'plan_name': planName,
          'plan_type': planType,
          'plan_price': planAmount ?? payment['amount'],
          'source': 'payment_confirmation',
        });
      }

      if (mounted) {
        setState(() {
          _activeSubscriptions = subscriptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading subscription details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _inferPlanType(
    String planName,
    int durationMonths,
    int entryCount,
    bool isUnlimited,
  ) {
    final lower = planName.toLowerCase();
    if (lower.contains('iscrizione') || lower.contains('annuale'))
      return 'annual';
    if (lower.contains('singolo') || lower.contains('single'))
      return 'single_entry';
    if (lower.contains('pacchetto') ||
        lower.contains('ingressi') ||
        entryCount > 1)
      return 'multi_entry';
    if (durationMonths >= 12) return 'annual';
    return 'monthly';
  }

  String _formatPlanType(String planType) {
    switch (planType) {
      case 'monthly':
        return 'payment.monthly_plan'.tr();
      case 'single_entry':
        return 'admin_discipline.single_entry'.tr();
      case 'multi_entry':
        return 'admin_discipline.entry_package'.tr();
      case 'annual':
        return 'payment.annual_plan'.tr();
      default:
        return planType;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Non specificato';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Data non valida';
    }
  }

  // ─── Admin: show delete dialog ───────────────────────────────────────────
  Future<void> _showDeleteDialog(Map<String, dynamic> subscription) async {
    final planName = subscription['plan_name'] as String? ?? 'Abbonamento';
    final subscriptionId = subscription['id'] as String?;
    if (subscriptionId == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 6.w),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Elimina Abbonamento',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stai per eliminare l\'abbonamento:',
              style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13),
            ),
            SizedBox(height: 1.h),
            Text(
              planName,
              style: GoogleFonts.inter(
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Vuoi eliminare anche le ricevute non fiscali già create per questo abbonamento?',
              style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 13),
            ),
          ],
        ),
        actionsPadding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 2.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Annulla',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.withAlpha(180)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteSubscription(
                paymentConfirmationId: subscriptionId,
                userSubscriptionId:
                    subscription['user_subscription_id'] as String?,
                deleteReceipts: false,
              );
            },
            child: Text(
              'Solo abbonamento',
              style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteSubscription(
                paymentConfirmationId: subscriptionId,
                userSubscriptionId:
                    subscription['user_subscription_id'] as String?,
                deleteReceipts: true,
              );
            },
            child: Text(
              'Abbonamento + Ricevute',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubscription({
    required String paymentConfirmationId,
    String? userSubscriptionId,
    required bool deleteReceipts,
  }) async {
    try {
      final client = SupabaseService.instance.client;

      if (deleteReceipts) {
        // Delete non_fiscal_receipts linked via batch_transaction_id
        final payment = await client
            .from('payment_confirmations')
            .select('batch_transaction_id')
            .eq('id', paymentConfirmationId)
            .maybeSingle();

        final batchId = payment?['batch_transaction_id'] as String?;
        if (batchId != null && batchId.isNotEmpty) {
          await client
              .from('non_fiscal_receipts')
              .delete()
              .eq('batch_transaction_id', batchId);
        }
      }

      // Delete user_subscription if present
      if (userSubscriptionId != null) {
        await client
            .from('user_subscriptions')
            .delete()
            .eq('id', userSubscriptionId);
      }

      // Delete payment_confirmation
      await client
          .from('payment_confirmations')
          .delete()
          .eq('id', paymentConfirmationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleteReceipts
                  ? 'Abbonamento e ricevute eliminati con successo.'
                  : 'Abbonamento eliminato con successo.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isLoading = true);
        await _loadSubscriptionDetails();
      }
    } catch (e) {
      print('Error deleting subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore durante l\'eliminazione: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
          border: Border.all(color: Colors.red.withAlpha(77)),
        ),
        child: Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.subscription_details'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: ProfileTypography.sectionTitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          _activeSubscriptions.isNotEmpty
              ? Column(
                  children: _activeSubscriptions
                      .map(
                        (sub) => Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: _buildSubscriptionCard(sub),
                        ),
                      )
                      .toList(),
                )
              : _buildNoSubscriptionCard(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> subscription) {
    final planName =
        subscription['plan_name'] as String? ?? 'payment.unknown_plan'.tr();
    final planType = subscription['plan_type'] as String? ?? 'monthly';
    final planPrice = subscription['plan_price'];
    final entriesTotal = (subscription['entries_total'] ?? 0) as int;
    final entriesRemaining = (subscription['entries_remaining'] ?? 0) as int;
    final expiresAt = subscription['expires_at'] as String?;
    final confirmedAt = subscription['confirmed_at'] as String?;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withAlpha(51), Colors.red.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: GoogleFonts.inter(
                    color: Colors.red,
                    fontSize: ProfileTypography.emphasis,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withAlpha(128)),
                    ),
                    child: Text(
                      'common.active'.tr(),
                      style: GoogleFonts.inter(
                        color: Colors.green,
                        fontSize: ProfileTypography.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.isAdminView) ...[
                    SizedBox(width: 2.w),
                    GestureDetector(
                      onTap: () => _showDeleteDialog(subscription),
                      child: Container(
                        padding: EdgeInsets.all(1.w),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.withAlpha(120)),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 5.w,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              if (planPrice != null)
                Expanded(
                  child: _buildPlanDetail(
                    'payment.price'.tr(),
                    '€$planPrice/${_formatPlanType(planType)}',
                  ),
                ),
              // For annual plans: show expiry date (purchase date shown below)
              // For other plans: show purchase date if no expiry, else expiry
              if (planType == 'annual')
                Expanded(
                  child: _buildPlanDetail(
                    'profile.expiry_date'.tr(),
                    _formatDate(expiresAt),
                  ),
                )
              else
                Expanded(
                  child: _buildPlanDetail(
                    confirmedAt != null
                        ? 'payment.purchased_on'.tr()
                        : 'profile.expiry_date'.tr(),
                    confirmedAt != null
                        ? _formatDate(confirmedAt)
                        : _formatDate(expiresAt),
                  ),
                ),
            ],
          ),
          // For non-annual plans with expiry: show expiry date in second row
          if (planType != 'annual' && expiresAt != null) ...[
            SizedBox(height: 1.h),
            Row(
              children: [
                if (planPrice != null) Expanded(child: SizedBox()),
                Expanded(
                  child: _buildPlanDetail(
                    'profile.expiry_date'.tr(),
                    _formatDate(expiresAt),
                  ),
                ),
              ],
            ),
          ],
          // For annual plans: show purchase date in second row
          if (planType == 'annual' && confirmedAt != null) ...[
            SizedBox(height: 1.h),
            Row(
              children: [
                if (planPrice != null) Expanded(child: SizedBox()),
                Expanded(
                  child: _buildPlanDetail(
                    'payment.purchased_on'.tr(),
                    _formatDate(confirmedAt),
                  ),
                ),
              ],
            ),
          ],
          if (entriesTotal > 0) ...[
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: _buildPlanDetail(
                    'payment.entries_total'.tr(),
                    entriesTotal.toString(),
                  ),
                ),
                Expanded(
                  child: _buildPlanDetail(
                    'payment.entries_remaining'.tr(),
                    entriesRemaining.toString(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[400], size: 5.w),
              SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  'payment.no_active_subscription'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: ProfileTypography.rowLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'payment.no_subscription_contact'.tr(),
            style: GoogleFonts.inter(
              color: Colors.grey[300],
              fontSize: ProfileTypography.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: ProfileTypography.caption,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: ProfileTypography.rowLabel,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
