import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/italian_receipt_service.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';

class RealtimeStatisticsWidget extends StatefulWidget {
  const RealtimeStatisticsWidget({Key? key}) : super(key: key);

  @override
  State<RealtimeStatisticsWidget> createState() =>
      _RealtimeStatisticsWidgetState();
}

class _RealtimeStatisticsWidgetState extends State<RealtimeStatisticsWidget> {
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  /// Calculate the most recent August 28th date relative to today
  DateTime _getMostRecentAugust28() {
    final now = DateTime.now();
    DateTime august28 = DateTime(now.year, 8, 28);
    if (now.isBefore(august28)) {
      august28 = DateTime(now.year - 1, 8, 28);
    }
    return august28;
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      final client = SupabaseService.instance.client;
      final now = DateTime.now();

      // Monthly revenue and receipt count
      final receiptStats = await ItalianReceiptService().getMonthlyStatistics(
        year: now.year,
        month: now.month,
      );

      // MEMBRI REGISTRATI: ALL users in user_profiles (all roles: student, instructor, staff, etc.) + active child profiles
      final registeredResponse =
          await client.from('user_profiles').select('id').neq(
                'role',
                'principal_admin',
              ); // exclude only the main admin account
      final adultUsersCount = (registeredResponse as List).length;

      // Count active child profiles
      final childProfilesResponse = await client
          .from('child_profiles')
          .select('id, tax_code, codice_fiscale')
          .eq('is_active', true);
      final childProfiles = childProfilesResponse as List;
      final childProfilesCount = childProfiles.length;

      final registeredMembersCount = adultUsersCount + childProfilesCount;

      // MEMBRI ISCRITTI / ABBONATI: da pagamenti confermati
      // (payment_confirmations), non dalle ricevute — quando un genitore
      // paga per un figlio, la ricevuta riporta il codice fiscale del
      // genitore, quindi contare per codice fiscale sulle ricevute
      // sottostima (o azzera) i figli.
      final mostRecentAugust28 = _getMostRecentAugust28();
      final confirmedPayments = await client
          .from('payment_confirmations')
          .select(
            'user_id, subscription_plan_id, custom_plan_id, '
            'beneficiary_profile_id, confirmed_at, created_at',
          )
          .eq('status', 'confirmed');

      final relevantPayments = (confirmedPayments as List).where((row) {
        final dateValue = row['confirmed_at'] ?? row['created_at'];
        final date = dateValue == null
            ? null
            : DateTime.tryParse(dateValue.toString());
        return date != null && !date.isBefore(mostRecentAugust28);
      }).toList();

      final planIds = <String>{};
      final customPlanIds = <String>{};
      for (final row in relevantPayments) {
        final planId = row['subscription_plan_id'] as String?;
        final customPlanId = row['custom_plan_id'] as String?;
        if (planId != null) planIds.add(planId);
        if (customPlanId != null) customPlanIds.add(customPlanId);
      }

      final planNamesById = <String, String>{};
      if (planIds.isNotEmpty) {
        final plansResponse = await client
            .from('subscription_plans')
            .select('id, name')
            .inFilter('id', planIds.toList());
        for (final plan in (plansResponse as List)) {
          planNamesById[plan['id'] as String] =
              (plan['name'] ?? '').toString();
        }
      }
      if (customPlanIds.isNotEmpty) {
        final customPlansResponse = await client
            .from('custom_subscription_plans')
            .select('id, name')
            .inFilter('id', customPlanIds.toList());
        for (final plan in (customPlansResponse as List)) {
          planNamesById[plan['id'] as String] =
              (plan['name'] ?? '').toString();
        }
      }

      // Una persona (adulto o figlio) conta una volta sola per riquadro,
      // anche con più pagamenti dello stesso tipo.
      final annualSubscriptionPersonIds = <String>{};
      final courseSubscriptionPersonIds = <String>{};
      for (final row in relevantPayments) {
        final personId = (row['beneficiary_profile_id'] as String?) ??
            row['user_id'] as String?;
        if (personId == null) continue;

        final planId = row['subscription_plan_id'] as String?;
        final customPlanId = row['custom_plan_id'] as String?;
        final planName = (planId != null ? planNamesById[planId] : null) ??
            (customPlanId != null ? planNamesById[customPlanId] : null);
        final isAnnualSubscription =
            planName != null && planName.toLowerCase().contains('iscrizione');

        if (isAnnualSubscription) {
          annualSubscriptionPersonIds.add(personId);
        } else {
          courseSubscriptionPersonIds.add(personId);
        }
      }

      final subscribedMembersCount = annualSubscriptionPersonIds.length;
      final courseSubscribersCount = courseSubscriptionPersonIds.length;

      if (mounted) {
        setState(() {
          _statistics = {
            'monthly_revenue':
                (receiptStats['total_revenue'] ?? 0.0).toDouble(),
            'registered_members': registeredMembersCount,
            'subscribed_members': subscribedMembersCount,
            'course_subscribers': courseSubscribersCount,
            'total_receipts': receiptStats['total_receipts'] ?? 0,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statistics = {
            'monthly_revenue': 0.0,
            'registered_members': 0,
            'subscribed_members': 0,
            'course_subscribers': 0,
            'total_receipts': 0,
          };
        });
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 3.h),

          // Monthly Revenue Card
          _buildStatCard(
            context,
            icon: 'euro',
            label: 'Entrate Mese',
            value: '€${_statistics['monthly_revenue'].toStringAsFixed(2)}',
            color: Colors.green,
          ),
          SizedBox(height: 2.h),

          // Membri Registrati
          _buildStatCard(
            context,
            icon: 'how_to_reg',
            label: 'Membri Registrati',
            value: _statistics['registered_members'].toString(),
            color: Colors.blue,
          ),
          SizedBox(height: 2.h),

          // Membri Iscritti (Iscrizione Annuale)
          _buildStatCard(
            context,
            icon: 'card_membership',
            label: 'Membri Iscritti',
            value: _statistics['subscribed_members'].toString(),
            color: Colors.teal,
          ),
          SizedBox(height: 2.h),

          // Membri Abbonati (corsi, not annual)
          _buildStatCard(
            context,
            icon: 'fitness_center',
            label: 'Membri Abbonati',
            value: _statistics['course_subscribers'].toString(),
            color: Colors.orange,
          ),
          SizedBox(height: 2.h),

          // Total Receipts Card
          _buildStatCard(
            context,
            icon: 'receipt_long',
            label: 'Ricevute Totali',
            value: _statistics['total_receipts'].toString(),
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
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
