import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ManualAmountDialog extends StatefulWidget {
  final String paymentMethod;
  final Function(double amount, String subscriptionType) onConfirm;
  final VoidCallback onCancel;

  const ManualAmountDialog({
    Key? key,
    required this.paymentMethod,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<ManualAmountDialog> createState() => _ManualAmountDialogState();
}

class _ManualAmountDialogState extends State<ManualAmountDialog> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedSubscriptionType = 'monthly';
  bool _isValid = false;

  final List<Map<String, dynamic>> _subscriptionOptions = [
    {
      'type': 'monthly',
      'label': 'Abbonamento Mensile',
      'price': 30.00,
      'description':
          'Validità dal 10 del mese corrente al 10 del mese successivo',
    },
    {
      'type': 'annual',
      'label': 'Iscrizione Annuale',
      'price': 150.00,
      'description': 'Validità fino al 28 agosto dell\'anno in corso',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Set default amount for monthly subscription
    _amountController.text = '30,00';
    _validateInput();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final amountText = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    setState(() {
      _isValid = amount != null && amount > 0;
    });
  }

  void _onSubscriptionTypeChanged(String type) {
    setState(() {
      _selectedSubscriptionType = type;
      final selectedOption =
          _subscriptionOptions.firstWhere((option) => option['type'] == type);
      _amountController.text =
          selectedOption['price'].toStringAsFixed(2).replaceAll('.', ',');
      _validateInput();
    });
  }

  void _onConfirm() {
    if (!_isValid) return;

    final amountText = _amountController.text.replaceAll(',', '.');
    final amount = double.parse(amountText);
    widget.onConfirm(amount, _selectedSubscriptionType);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: 'edit',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'Inserisci Dati Pagamento',
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
            Text(
              'Seleziona il tipo di abbonamento e inserisci l\'importo pagato tramite ${_getPaymentMethodText(widget.paymentMethod)}.',
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
            SizedBox(height: 3.h),

            // Subscription type selection
            Text(
              'Tipo di Abbonamento',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),

            Column(
              children: _subscriptionOptions.map((option) {
                final isSelected = option['type'] == _selectedSubscriptionType;
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 0.5.h),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.lightTheme.colorScheme.primary
                          : AppTheme.lightTheme.colorScheme.outline
                              .withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? AppTheme.lightTheme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                  child: RadioListTile<String>(
                    value: option['type'],
                    groupValue: _selectedSubscriptionType,
                    onChanged: (value) => _onSubscriptionTypeChanged(value!),
                    title: Text(
                      option['label'],
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option['description'],
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme
                                .lightTheme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          'Prezzo consigliato: €${option['price'].toStringAsFixed(2).replaceAll('.', ',')}',
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.lightTheme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    activeColor: AppTheme.lightTheme.colorScheme.primary,
                    contentPadding: EdgeInsets.symmetric(horizontal: 2.w),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 3.h),

            // Amount input
            Text(
              'Importo Pagato',
              style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              onChanged: (_) => _validateInput(),
              decoration: InputDecoration(
                hintText: '0,00',
                prefixText: '€ ',
                prefixStyle: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.lightTheme.colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppTheme.lightTheme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: 2.h,
                ),
                errorText: !_isValid && _amountController.text.isNotEmpty
                    ? 'Inserisci un importo valido'
                    : null,
              ),
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'info',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      'L\'importo verrà registrato sulla ricevuta non fiscale con IVA al 0%.',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            'Annulla',
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isValid ? _onConfirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
            disabledBackgroundColor:
                AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
            disabledForegroundColor:
                AppTheme.lightTheme.colorScheme.onSurfaceVariant,
          ),
          child: Text(
            'Genera Ricevuta',
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              color: _isValid
                  ? AppTheme.lightTheme.colorScheme.onPrimary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'sumup':
        return 'SumUp';
      case 'satispay':
        return 'Satispay';
      case 'cash':
        return 'Contanti';
      case 'bank_transfer':
        return 'Bonifico Bancario';
      default:
        return method;
    }
  }
}
