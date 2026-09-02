import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_export.dart';
import '../../../services/payment_service.dart';

class SumUpPaymentOptionsWidget extends StatefulWidget {
  const SumUpPaymentOptionsWidget({Key? key}) : super(key: key);

  @override
  _SumUpPaymentOptionsWidgetState createState() =>
      _SumUpPaymentOptionsWidgetState();
}

class _SumUpPaymentOptionsWidgetState extends State<SumUpPaymentOptionsWidget> {
  bool _isLoading = false;

  // 🆕 ENROLLMENT CHECK: Track if user has annual registration
  bool _hasAnnualRegistration = false;
  bool _isLoadingEnrollmentStatus = true;

  @override
  void initState() {
    super.initState();
    _checkEnrollmentStatus(); // 🆕 CHECK ENROLLMENT ON INIT
  }

  // 🆕 CHECK ENROLLMENT STATUS
  Future<void> _checkEnrollmentStatus() async {
    try {
      final dashboardData = await PaymentService.getSubscriptionDashboardData();
      if (!mounted) return;
      setState(() {
        _hasAnnualRegistration =
            dashboardData['hasAnnualRegistration'] ?? false;
        _isLoadingEnrollmentStatus = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasAnnualRegistration = false;
        _isLoadingEnrollmentStatus = false;
      });
    }
  }

  // 🔥 MODIFIED: Add enrollment warning for Satispay
  Future<void> _launchSatispayUrl() async {
    // 🎯 RULE: For Satispay, show warning popup if no annual registration
    if (!_hasAnnualRegistration) {
      // 🔔 SATISPAY BEHAVIOR: Show warning but allow continuation
      final shouldContinue = await _showAnnualRegistrationWarningDialog();
      if (!mounted) return;
      if (!shouldContinue) {
        return; // User cancelled
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      const satispayUrl =
          'https://www.satispay.com/app/pay/shops/58875f70-d796-4596-a2f6-12fe91a8c202';
      final Uri uri = Uri.parse(satispayUrl);

      // Set payment pending flag before launching
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', true);
      await prefs.setString('pendingPaymentMethod', 'satispay');

      // Show loading for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // Clear pending flag if launch failed
        await prefs.setBool('isPaymentPending', false);

        if (mounted) {
          Fluttertoast.showToast(
            msg: 'payment.satispay_open_error'.tr(),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        if (mounted) {
          Fluttertoast.showToast(
            msg: 'payment.satispay_redirect'.tr(),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      // Clear pending flag on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPaymentPending', false);

      if (mounted) {
        Fluttertoast.showToast(
          msg: 'payment.redirect_error'.tr(namedArgs: {'detail': e.toString()}),
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
        });
      }
    }
  }

  // 🆕 DIALOG: Show warning for Satispay (allows continuation)
  Future<bool> _showAnnualRegistrationWarningDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: const Color(0xFFF39C12),
                  size: 28,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'admin_discipline.attention_title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF39C12),
                        ),
                  ),
                ),
              ],
            ),
            content: Text(
              'payment.annual_registration_reminder'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'common.cancel'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'payment.proceed'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 1.5.h,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false; // Return false if dialog dismissed without choice
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEnrollmentStatus) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(5.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'account_balance_wallet',
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'payment.payment_methods'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                'payment.payment_methods_intro'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(height: 3.h),

              // SumUp Payment Button - Updated to use new route
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2E7D32).withValues(alpha: 0.08),
                      const Color(0xFF2E7D32).withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.subscriptionPlanSelection,
                      );

                      Fluttertoast.showToast(
                        msg: 'payment.sumup_redirect'.tr(),
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 15.w,
                                height: 15.w,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2E7D32,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: CustomIconWidget(
                                    iconName: 'payment',
                                    color: const Color(0xFF2E7D32),
                                    size: 28,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 3.w,
                                      runSpacing: 0.8.h,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'payment.sumup'.tr(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF2E7D32),
                                              ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 3.w,
                                            vertical: 0.8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2E7D32),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'payment.choose_plan'.tr(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              SizedBox(width: 1.5.w),
                                              CustomIconWidget(
                                                iconName: 'arrow_forward',
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      'payment.secure_online'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
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
                          SizedBox(height: 2.h),
                          Text(
                            'payment.sumup_description'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 2.h),

              // Modified Satispay Payment Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFD32F2F).withValues(alpha: 0.08),
                      const Color(0xFFD32F2F).withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _launchSatispayUrl,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 15.w,
                                height: 15.w,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD32F2F,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFD32F2F,
                                    ).withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: CustomIconWidget(
                                    iconName: 'smartphone',
                                    color: const Color(0xFFD32F2F),
                                    size: 28,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 3.w,
                                      runSpacing: 0.8.h,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'payment.satispay'.tr(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFFD32F2F),
                                              ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 3.w,
                                            vertical: 0.8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD32F2F),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'payment.pay_now'.tr(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              SizedBox(width: 1.5.w),
                                              CustomIconWidget(
                                                iconName: 'arrow_forward',
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      'payment.mobile_payment'.tr(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
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
                          SizedBox(height: 2.h),
                          Text(
                            'payment.satispay_description'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
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
                        'payment.security_footer'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
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
      ),
    );
  }
}
