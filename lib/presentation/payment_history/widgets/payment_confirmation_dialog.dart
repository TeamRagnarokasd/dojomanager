import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/subscription_service.dart';

class PaymentConfirmationDialog extends StatefulWidget {
  final Map<String, dynamic> planData;
  final VoidCallback onConfirmed;

  const PaymentConfirmationDialog({
    Key? key,
    required this.planData,
    required this.onConfirmed,
  }) : super(key: key);

  @override
  State<PaymentConfirmationDialog> createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  bool _showDetailsForm = false;
  bool _isSubmitting = false;
  String? _selectedPlanName;
  String? _selectedDiscipline;

  bool _needsDisciplineSelection = false;

  void _checkDisciplineNeed(String? planName) {
    if (planName == null) {
      setState(() {
        _needsDisciplineSelection = false;
      });
      return;
    }

    final isSingleCourse =
        planName.toLowerCase().contains('corso singolo') &&
        !planName.toLowerCase().contains('doppio') &&
        !planName.toLowerCase().contains('preparazione');

    setState(() {
      _needsDisciplineSelection = isSingleCourse;
      if (!isSingleCourse) {
        _selectedDiscipline = null;
      }
    });
  }

  double _getPriceForPlan(String planName) {
    final plan = SubscriptionService.officialPlans.firstWhere(
      (p) => p['name'] == planName,
      orElse: () => {'price': 0.0},
    );
    return (plan['price'] as num).toDouble();
  }

  Future<void> _handleConfirmation() async {
    if (_selectedPlanName == null) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: "Seleziona un tipo di abbonamento",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (_needsDisciplineSelection && _selectedDiscipline == null) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: "Seleziona una disciplina",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // FIX 1: Parse clean plan name (remove price if present)
      final cleanPlanName = _selectedPlanName!.split(' - €')[0].trim();

      // Get price from officialPlans (SINGLE SOURCE OF TRUTH)
      final officialPlan = SubscriptionService.officialPlans.firstWhere(
        (p) => p['name'] == cleanPlanName,
        orElse: () => throw Exception('Piano non valido'),
      );

      final price = (officialPlan['price'] as num).toDouble();

      // FIX 2: Get subscription plan ID from database using clean name
      // Only fetch from database to get the ID, but validate against officialPlans
      final plans = await SubscriptionService.getSubscriptionPlans();
      final matchingPlan = plans.firstWhere(
        (p) => p['name'] == cleanPlanName,
        orElse:
            () => {
              // If not found in database, create a minimal plan structure
              // This ensures the flow continues even if database is not synced
              'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
              'name': cleanPlanName,
            },
      );

      // Create payment confirmation
      final confirmationId =
          await SubscriptionService.createPaymentConfirmation(
            subscriptionPlanId: matchingPlan['id'],
            paymentMethod: widget.planData['payment_method'] ?? 'sumup',
            amount: price,
          );

      if (confirmationId == null) {
        throw Exception('Failed to create payment confirmation');
      }

      // Confirm payment
      final success = await SubscriptionService.confirmPayment(
        confirmationId: confirmationId,
      );

      if (!success) {
        throw Exception('Payment confirmation failed');
      }

      // Create receipt
      await SubscriptionService.createReceiptForPayment(
        amount: price,
        description: cleanPlanName,
        discipline: _selectedDiscipline,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      // FIX 3: Success toast is GREEN (already correct)
      Fluttertoast.showToast(
        msg: "Abbonamento Attivato",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      widget.onConfirmed();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      // FIX 3: Error toast is RED (already correct)
      Fluttertoast.showToast(
        msg: "Errore: ${e.toString()}",
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
                'Conferma Pagamento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              Text(
                'Hai completato il pagamento?',
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
                        'No',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
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
                        'Sì',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
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
                  ),
                  Expanded(
                    child: Text(
                      'Dettagli Abbonamento',
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
                      Text(
                        'Tipo Abbonamento',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
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
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedPlanName,
                            hint: Text(
                              'Seleziona un piano',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            items:
                                SubscriptionService.officialPlans.map((plan) {
                                  final name = plan['name'] as String;
                                  final price = plan['price'];
                                  return DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(
                                      '$name - €$price',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPlanName = value;
                                _checkDisciplineNeed(value);
                              });
                            },
                          ),
                        ),
                      ),
                      if (_needsDisciplineSelection) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'Scegli Disciplina',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedDiscipline,
                              hint: Text(
                                'Seleziona disciplina',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'MMA',
                                  child: Text(
                                    'MMA',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'BJJ',
                                  child: Text(
                                    'BJJ',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedDiscipline = value;
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
                                'Verrà creata automaticamente una fattura non fiscale con la data odierna',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      AppTheme.lightTheme.colorScheme.primary,
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
                  onPressed: _isSubmitting ? null : _handleConfirmation,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                    disabledBackgroundColor: AppTheme
                        .lightTheme
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.6),
                  ),
                  child:
                      _isSubmitting
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
                            'Conferma Abbonamento',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
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