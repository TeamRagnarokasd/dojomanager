import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/cash_register_service.dart';

/// Gear-icon dialog: edit the opening balance / opening date
/// (cash_register_set_opening). Returns true via Navigator.pop when the
/// change was saved successfully.
class OpeningBalanceDialog extends StatefulWidget {
  const OpeningBalanceDialog({
    Key? key,
    required this.currentBalance,
    required this.currentDate,
  }) : super(key: key);

  final double currentBalance;
  final DateTime currentDate;

  @override
  State<OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<OpeningBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _balanceController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
      text: widget.currentBalance.toStringAsFixed(2).replaceAll('.', ','),
    );
    _selectedDate = widget.currentDate;
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final balance = double.parse(
        _balanceController.text.trim().replaceAll(',', '.'),
      );
      await CashRegisterService.instance.setOpening(
        balance: balance,
        date: _selectedDate,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = CashRegisterService.isCashNegativeError(e)
          ? 'Il saldo di cassa scenderebbe sotto zero: operazione non consentita.'
          : 'Errore durante il salvataggio: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Saldo iniziale di cassa'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Saldo iniziale (€)',
                prefixIcon: Icon(Icons.euro),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci il saldo iniziale';
                }
                final balance = double.tryParse(value.trim().replaceAll(',', '.'));
                if (balance == null || balance < 0) {
                  return 'Inserisci un valore valido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data di apertura',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }
}
