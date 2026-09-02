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
      final registeredResponse = await client
          .from('user_profiles')
          .select('id')
          .neq(
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

      // Collect all child tax codes (normalized uppercase)
      final childTaxCodes = <String>{};
      for (final child in childProfiles) {
        final tc = (child['tax_code'] ?? child['codice_fiscale'])
            ?.toString()
            .trim()
            .toUpperCase();
        if (tc != null && tc.isNotEmpty) {
          childTaxCodes.add(tc);
        }
      }

      // MEMBRI ISCRITTI: unique tax codes with 'Iscrizione Annuale' receipt from most recent Aug 28
      final mostRecentAugust28 = _getMostRecentAugust28();
      final annualReceipts = await client
          .from('non_fiscal_receipts')
          .select('customer_tax_code')
          .ilike('description', '%Iscrizione Annuale%')
          .gte(
            'issue_date',
            mostRecentAugust28.toIso8601String().split('T')[0],
          );

      // Collect all tax codes from annual receipts (adults + children together)
      final allAnnualTaxCodes = <String>{};
      for (final receipt in annualReceipts) {
        final taxCode = receipt['customer_tax_code'];
        if (taxCode != null && taxCode.toString().trim().isNotEmpty) {
          allAnnualTaxCodes.add(taxCode.toString().trim().toUpperCase());
        }
      }

      // Count adults with annual subscription (tax codes NOT belonging to children)
      int adultSubscribedCount = 0;
      int childSubscribedCount = 0;
      for (final tc in allAnnualTaxCodes) {
        if (childTaxCodes.contains(tc)) {
          childSubscribedCount++;
        } else {
          adultSubscribedCount++;
        }
      }

      final subscribedMembersCount =
          adultSubscribedCount + childSubscribedCount;

      // MEMBRI ABBONATI: unique tax codes with course receipts (NOT Iscrizione Annuale) from most recent Aug 28
      final courseReceipts = await client
          .from('non_fiscal_receipts')
          .select('customer_tax_code')
          .not('description', 'ilike', '%Iscrizione Annuale%')
          .gte(
            'issue_date',
            mostRecentAugust28.toIso8601String().split('T')[0],
          );

      final allCourseTaxCodes = <String>{};
      for (final receipt in courseReceipts) {
        final taxCode = receipt['customer_tax_code'];
        if (taxCode != null && taxCode.toString().trim().isNotEmpty) {
          allCourseTaxCodes.add(taxCode.toString().trim().toUpperCase());
        }
      }

      // Count adults and children with course subscriptions
      int adultCourseCount = 0;
      int childCourseCount = 0;
      for (final tc in allCourseTaxCodes) {
        if (childTaxCodes.contains(tc)) {
          childCourseCount++;
        } else {
          adultCourseCount++;
        }
      }

      final courseSubscribersCount = adultCourseCount + childCourseCount;

      if (mounted) {
        setState(() {
          _statistics = {
            'monthly_revenue': (receiptStats['total_revenue'] ?? 0.0)
                .toDouble(),
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
