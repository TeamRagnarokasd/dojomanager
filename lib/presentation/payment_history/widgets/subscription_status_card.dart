import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SubscriptionStatusCard extends StatefulWidget {
  final Map<String, dynamic> subscriptionData;
  final Function(bool)? onAutoPaymentToggle;

  const SubscriptionStatusCard({
    Key? key,
    required this.subscriptionData,
    this.onAutoPaymentToggle,
  }) : super(key: key);

  @override
  State<SubscriptionStatusCard> createState() => _SubscriptionStatusCardState();
}

class _SubscriptionStatusCardState extends State<SubscriptionStatusCard> {
  bool _autoPaymentEnabled = true;

  @override
  void initState() {
    super.initState();
    _autoPaymentEnabled =
        widget.subscriptionData['autoPayment'] as bool? ?? true;
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CRITICAL: Update badge color based on subscription status
    final isActive = widget.subscriptionData['status'] == 'active' ||
        widget.subscriptionData['hasAnnualRegistration'] == true ||
        widget.subscriptionData['hasActiveSubscription'] == true;

    final badgeColor = isActive
        ? Colors.green // Active status - Green badge
        : Theme.of(context).colorScheme.tertiary; // Inactive status

    final badgeText = isActive ? 'common.active'.tr() : 'common.inactive'.tr();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(5.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'card_membership',
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'payment.subscription_status'.tr(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    // 🔥 LOGICA ISCRIZIONE: Update badge based on annual registration status
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    // Piano Attuale Column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'payment.current_plan'.tr(),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          SizedBox(height: 0.5.h),
                          // 🔥 LOGICA PIANO ATTUALE: Show active plan excluding Iscrizione Annuale
                          Text(
                            widget.subscriptionData['currentPlanName']
                                    as String? ??
                                widget.subscriptionData['planName']
                                    as String? ??
                                'payment.no_active_subscription'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 3.w),
                    // Iscrizione Column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'payment.registration_label'.tr(),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          SizedBox(height: 0.5.h),
                          // 🔥 LOGICA ISCRIZIONE: Display status from database
                          Text(
                            widget.subscriptionData['annualRegistrationStatus']
                                    as String? ??
                                'payment.to_purchase'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          // 🔥 LOGICA ISCRIZIONE: Show expiry if registration is active
                          if (widget.subscriptionData[
                                      'annualRegistrationStatus'] ==
                                  'Effettuata' &&
                              widget.subscriptionData[
                                      'annualRegistrationExpiry'] !=
                                  null &&
                              (widget.subscriptionData[
                                      'annualRegistrationExpiry'] as String)
                                  .isNotEmpty) ...[
                            SizedBox(height: 0.3.h),
                            Text(
                              widget.subscriptionData[
                                  'annualRegistrationExpiry'] as String,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 3.w),
                    // Rinnovo Column
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'payment.renewal'.tr(),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          SizedBox(height: 0.5.h),
                          // 🔥 LOGICA PIANO ATTUALE: Show renewal date for current plan
                          Text(
                            widget.subscriptionData['renewalDate'] as String? ??
                                '',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
