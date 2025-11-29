import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/subscription_service.dart';

class PaymentConfirmationDialog extends StatefulWidget {
  final String paymentMethod;
  final VoidCallback onCancel;

  const PaymentConfirmationDialog({
    Key? key,
    required this.paymentMethod,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<PaymentConfirmationDialog> createState() =>
      _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  bool _isSubmitting = false;
  String? _selectedPlanName;
  String? _selectedDiscipline;
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: 'payment',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'Conferma Pagamento',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_showDetails) ...[
              Text(
                'Hai completato il pagamento?',
                style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              // Plan selection dropdown
              Text(
                'Tipo Abbonamento',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              DropdownButtonFormField<String>(
                value: _selectedPlanName,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 1.5.h,
                  ),
                ),
                hint: const Text('Seleziona un piano'),
                items:
                    SubscriptionService.officialPlans.map((plan) {
                      return DropdownMenuItem<String>(
                        value: plan['name'] as String,
                        child: Text(
                          '${plan['name']} - €${(plan['price'] as double).toStringAsFixed(2).replaceAll('.', ',')}',
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlanName = value;
                    // Reset discipline if plan changed
                    _selectedDiscipline = null;
                  });
                },
              ),
              SizedBox(height: 2.h),

              // Conditional discipline selector
              if (_selectedPlanName != null &&
                  _selectedPlanName == 'Corso Singolo') ...[
                Text(
                  'Scegli Disciplina',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                DropdownButtonFormField<String>(
                  value: _selectedDiscipline,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 1.5.h,
                    ),
                  ),
                  hint: const Text('Seleziona disciplina'),
                  items:
                      ['MMA', 'BJJ'].map((discipline) {
                        return DropdownMenuItem<String>(
                          value: discipline,
                          child: Text(discipline),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDiscipline = value;
                    });
                  },
                ),
                SizedBox(height: 2.h),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (!_showDetails) ...[
          TextButton(
            onPressed: widget.onCancel,
            child: Text(
              'No',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showDetails = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightTheme.colorScheme.primary,
              foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
            ),
            child: Text(
              'Sì',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ] else ...[
          TextButton(
            onPressed:
                _isSubmitting
                    ? null
                    : () {
                      setState(() {
                        _showDetails = false;
                        _selectedPlanName = null;
                        _selectedDiscipline = null;
                      });
                    },
            child: Text(
              'Indietro',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed:
                _isSubmitting ||
                        _selectedPlanName == null ||
                        (_selectedPlanName == 'Corso Singolo' &&
                            _selectedDiscipline == null)
                    ? null
                    : _handleConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightTheme.colorScheme.primary,
              foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
            ),
            child:
                _isSubmitting
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.lightTheme.colorScheme.onPrimary,
                        ),
                      ),
                    )
                    : Text(
                      'Conferma',
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleConfirmation() async {
    if (_selectedPlanName == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Find the selected plan to get correct price
      final selectedPlan = SubscriptionService.officialPlans.firstWhere(
        (plan) => plan['name'] == _selectedPlanName,
      );

      final double correctPrice = selectedPlan['price'] as double;

      // Save subscription with correct price
      await SubscriptionService.createReceiptForPayment(
        amount: correctPrice,
        description: _selectedPlanName!,
        discipline: _selectedDiscipline,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Abbonamento Attivato'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    }
  }
}