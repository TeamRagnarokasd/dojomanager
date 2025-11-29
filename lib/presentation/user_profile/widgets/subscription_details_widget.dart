import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/app_constants.dart';
import '../../../services/supabase_service.dart';

class SubscriptionDetailsWidget extends StatefulWidget {
  final bool autoRenewal;
  final ValueChanged<bool> onAutoRenewalChanged;

  const SubscriptionDetailsWidget({
    Key? key,
    required this.autoRenewal,
    required this.onAutoRenewalChanged,
  }) : super(key: key);

  @override
  State<SubscriptionDetailsWidget> createState() =>
      _SubscriptionDetailsWidgetState();
}

class _SubscriptionDetailsWidgetState extends State<SubscriptionDetailsWidget> {
  Map<String, dynamic>? _subscriptionData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;

      if (user == null) return;

      // Get active subscription
      final response = await client
          .from('user_subscriptions')
          .select('''
            *,
            subscription_plans(
              name,
              description,
              price,
              plan_type,
              entry_count
            )
          ''')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);

      setState(() {
        _subscriptionData = response.isNotEmpty ? response.first : null;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading subscription data: $e');
      setState(() {
        _subscriptionData = null;
        _isLoading = false;
      });
    }
  }

  String _formatPlanType(String planType) {
    switch (planType) {
      case 'monthly':
        return 'Mensile';
      case 'single_entry':
        return 'Ingresso Singolo';
      case 'multi_entry':
        return 'Pacchetto Ingressi';
      case 'annual':
        return 'Annuale';
      default:
        return planType;
    }
  }

  String _formatExpiryDate(String? expiresAt) {
    if (expiresAt == null) return 'Non specificato';
    try {
      final date = DateTime.parse(expiresAt);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return 'Data non valida';
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
        child: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
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
            'Dettagli Abbonamento',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 3.h),
          _subscriptionData != null
              ? _buildSubscriptionCard()
              : _buildNoSubscriptionCard(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final subscription = _subscriptionData!;
    final plan = subscription['subscription_plans'];
    final isActive = subscription['is_active'] ?? false;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [Colors.red.withAlpha(51), Colors.red.withAlpha(13)]
              : [Colors.grey.withAlpha(51), Colors.grey.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isActive
                ? Colors.red.withAlpha(77)
                : Colors.grey.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plan['name'] ?? 'Piano Sconosciuto',
                  style: GoogleFonts.inter(
                    color: isActive ? Colors.red : Colors.grey[400],
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withAlpha(51)
                      : Colors.orange.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isActive
                          ? Colors.green.withAlpha(128)
                          : Colors.orange.withAlpha(128)),
                ),
                child: Text(
                  isActive ? 'ATTIVO' : 'SCADUTO',
                  style: GoogleFonts.inter(
                    color: isActive ? Colors.green : Colors.orange,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildPlanDetail('Prezzo',
                    '€${plan['price']}/${_formatPlanType(plan['plan_type'])}'),
              ),
              Expanded(
                child: _buildPlanDetail(
                    'Scadenza', _formatExpiryDate(subscription['expires_at'])),
              ),
            ],
          ),
          if (subscription['entries_total'] != null) ...[
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: _buildPlanDetail('Ingressi Totali',
                      subscription['entries_total'].toString()),
                ),
                Expanded(
                  child: _buildPlanDetail('Ingressi Rimanenti',
                      subscription['entries_remaining'].toString()),
                ),
              ],
            ),
          ],
          SizedBox(height: 2.h),
          Text(
            plan['description'] ??
                'Include accesso alle discipline previste dal piano',
            style: GoogleFonts.inter(
              color: Colors.grey[300],
              fontSize: 9.sp,
              fontStyle: FontStyle.italic,
            ),
          ),
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
                  'Nessun Abbonamento Attivo',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Non hai abbonamenti attivi al momento. Contatta la palestra per attivare un piano.',
            style: GoogleFonts.inter(
              color: Colors.grey[300],
              fontSize: 10.sp,
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
            fontSize: 9.sp,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
