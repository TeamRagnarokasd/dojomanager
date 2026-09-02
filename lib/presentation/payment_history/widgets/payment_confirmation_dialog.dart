import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/subscription_service.dart';

class PaymentConfirmationDialog extends StatefulWidget {
  final Map<String, dynamic> planData;
  final VoidCallback? onConfirmed;

  const PaymentConfirmationDialog({
    Key? key,
    required this.planData,
    this.onConfirmed,
  }) : super(key: key);

  @override
  State<PaymentConfirmationDialog> createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  bool _isProcessing = false;
  bool _isSubmitting = false;
  String? _selectedPlanName;
  bool _showDetailsForm = false;
  bool _isPlanLocked = false;

  // For SumUp with known plan: store price directly from SharedPreferences
  double? _lockedPlanPrice;

  // Dynamic plans loaded from Supabase for Satispay dropdown
  List<Map<String, dynamic>> _allPlans = [];
  bool _isLoadingPlans = false;

  @override
  void initState() {
    super.initState();
    _initializePlanSelection();
  }

  Future<void> _loadPlans() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPlans = true;
    });
    try {
      final plans = await SubscriptionService.getAllPlansForSatispay();
      if (!mounted) return;
      setState(() {
        _allPlans = plans;
        _isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allPlans = [];
        _isLoadingPlans = false;
      });
    }
  }

  void _initializePlanSelection() {
    final paymentMethod = widget.planData['payment_method'] ?? 'sumup';
    final planTitle = widget.planData['plan_title'] as String?;
    final planAmount = widget.planData['amount'] as double?;

    if (paymentMethod.toLowerCase() == 'sumup' &&
        planTitle != null &&
        planTitle.trim().isNotEmpty) {
      // SumUp with known plan: lock the plan and skip selection step entirely
      setState(() {
        _selectedPlanName = planTitle.trim();
        _isPlanLocked = true;
        _lockedPlanPrice = planAmount;
        // Skip the "Did you complete payment?" question — go straight to details
        _showDetailsForm = true;
      });
    } else {
      // Satispay or unknown plan: show full flow with plan selection
      setState(() {
        _selectedPlanName = null;
        _isPlanLocked = false;
        _lockedPlanPrice = null;
        _showDetailsForm = false;
      });
      // Load all plans dynamically from Supabase
      _loadPlans();
    }
  }

  Future<void> _handleConfirmation() async {
    if (_selectedPlanName == null) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: 'payment.select_plan_type'.tr(),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final cleanPlanName = _selectedPlanName!.split(' - €')[0].trim();
      final paymentMethod = widget.planData['payment_method'] ?? 'sumup';

      double price;

      if (_isPlanLocked && _lockedPlanPrice != null && _lockedPlanPrice! > 0) {
        // SumUp: use the price stored in SharedPreferences (from plan selection)
        price = _lockedPlanPrice!;
      } else {
        // Satispay: look up price from dynamically loaded plans
        final selectedPlan = _allPlans.firstWhere(
          (p) => p['name'] == cleanPlanName,
          orElse: () => <String, dynamic>{},
        );
        if (selectedPlan.isEmpty) {
          throw Exception('payment.invalid_plan'.tr());
        }
        price = (selectedPlan['price'] as num).toDouble();
      }

      final items = [
        {'name': cleanPlanName, 'price': price},
      ];

      await SubscriptionService.createBatchPaymentAndReceipts(
        items: items,
        paymentMethod: paymentMethod,
        amount: price,
        description: cleanPlanName,
        discipline: null,
        discipline2: null,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      Fluttertoast.showToast(
        msg: 'payment.subscription_activated'.tr(),
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      widget.onConfirmed?.call();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      Fluttertoast.showToast(
        msg: '${'common.error'.tr()}: ${e.toString()}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 70.h),
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showDetailsForm) ...[
              CustomIconWidget(
                iconName: 'help_outline',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 48,
              ),
              SizedBox(height: 3.h),
              Text(
                'payment.confirm_payment_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              Text(
                'payment_confirm.payment_completed_question'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      child: Text(
                        'common.no'.tr(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showDetailsForm = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        backgroundColor:
                            AppTheme.lightTheme.colorScheme.primary,
                      ),
                      child: Text(
                        'common.yes'.tr(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  // Show back button only for Satispay (non-locked) flow
                  if (!_isPlanLocked)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showDetailsForm = false;
                        });
                      },
                      icon: CustomIconWidget(
                        iconName: 'arrow_back',
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 24,
                      ),
                    )
                  else
                    SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'profile.subscription_details'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 48),
                ],
              ),
              SizedBox(height: 3.h),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isPlanLocked) ...[
                        // SumUp: show the pre-selected plan as read-only info
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'payment_confirm.subscription_type'.tr(),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomIconWidget(
                                    iconName: 'lock',
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 14,
                                  ),
                                  SizedBox(width: 1.w),
                                  Text(
                                    'payment.preselected'.tr(),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'check_circle',
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Text(
                                  _selectedPlanName ?? '',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              if (_lockedPlanPrice != null &&
                                  _lockedPlanPrice! > 0)
                                Text(
                                  '€${_lockedPlanPrice!.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Satispay: show dropdown for plan selection (loaded from Supabase)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'payment_confirm.subscription_type'.tr(),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: _isLoadingPlans
                              ? Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2.h),
                                  child: Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                )
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedPlanName,
                                    hint: Text(
                                      'subscription_ui.select_plan'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    items: _allPlans.map((plan) {
                                      final name = plan['name'] as String;
                                      final price = (plan['price'] as num)
                                          .toDouble();
                                      final priceStr = price
                                          .toStringAsFixed(2)
                                          .replaceAll('.', ',');
                                      return DropdownMenuItem<String>(
                                        value: name,
                                        child: Text(
                                          '$name - €$priceStr',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPlanName = value;
                                      });
                                    },
                                  ),
                                ),
                        ),
                      ],
                      SizedBox(height: 3.h),
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: AppTheme
                              .lightTheme
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.lightTheme.colorScheme.primary
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            CustomIconWidget(
                              iconName: 'info',
                              color: AppTheme.lightTheme.colorScheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Text(
                                'payment.non_fiscal_invoice_note'.tr(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme
                                          .lightTheme
                                          .colorScheme
                                          .primary,
                                      height: 1.3,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleConfirmation,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                    disabledBackgroundColor: AppTheme
                        .lightTheme
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.6),
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'payment_confirm.confirm_subscription'.tr(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                ),
              ),
              SizedBox(height: 1.5.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          // Clear pending payment flag from SharedPreferences
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('isPaymentPending', false);
                            await prefs.remove('pendingPlanId');
                            await prefs.remove('pendingPlanTitle');
                            await prefs.remove('pendingPlanAmount');
                            await prefs.remove('pendingPaymentMethod');
                          } catch (_) {}
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    'Non ho completato il pagamento',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red.shade300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
