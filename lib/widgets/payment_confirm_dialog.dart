import 'package:flutter/material.dart';

import '../services/child_profile_service.dart';

/// Shown right before starting ANY SumUp/Satispay payment (piani,
/// convenzioni, nuovi pagamenti) when the guardian has at least one
/// registered child — lets them confirm (or change, for THIS purchase
/// only) who is actually being paid for. Never changes which profile is
/// active ([ChildProfileService.setActiveProfile] is never called from
/// here): the choice only decides the beneficiary sent for this one
/// payment.
///
/// Returns the chosen [PaymentBeneficiaryOption], or null if the student
/// dismissed the dialog or tapped "Annulla" — either way the payment must
/// not start at all.
Future<PaymentBeneficiaryOption?> showPaymentConfirmDialog(
  BuildContext context, {
  required List<PaymentBeneficiaryOption> options,
  required String? initialSelectedId,
  required String planTitle,
  required double amount,
}) async {
  final amountText = '€${amount.toStringAsFixed(2).replaceAll('.', ',')}';
  return showDialog<PaymentBeneficiaryOption>(
    context: context,
    builder: (dialogContext) => _PaymentConfirmDialog(
      options: options,
      initialSelectedId: initialSelectedId,
      planTitle: planTitle,
      amountText: amountText,
    ),
  );
}

class _PaymentConfirmDialog extends StatefulWidget {
  const _PaymentConfirmDialog({
    required this.options,
    required this.initialSelectedId,
    required this.planTitle,
    required this.amountText,
  });

  final List<PaymentBeneficiaryOption> options;
  final String? initialSelectedId;
  final String planTitle;
  final String amountText;

  @override
  State<_PaymentConfirmDialog> createState() => _PaymentConfirmDialogState();
}

class _PaymentConfirmDialogState extends State<_PaymentConfirmDialog> {
  late String? _selectedId;

  @override
  void initState() {
    super.initState();
    // Falls back to the first option (the guardian themselves) if the
    // active profile somehow isn't among the choices anymore.
    _selectedId = widget.options.any((o) => o.id == widget.initialSelectedId)
        ? widget.initialSelectedId
        : widget.options.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text(
        'Confermi il pagamento?',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.planTitle} — ${widget.amountText}',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Stai pagando per:',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            for (final option in widget.options)
              RadioListTile<String?>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: option.id,
                groupValue: _selectedId,
                onChanged: (value) => setState(() => _selectedId = value),
                title: Text(option.name),
                subtitle: Text(option.isChild ? 'Minore' : 'Adulto'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: () {
            final chosen = widget.options.firstWhere(
              (o) => o.id == _selectedId,
              orElse: () => widget.options.first,
            );
            Navigator.pop(context, chosen);
          },
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}
