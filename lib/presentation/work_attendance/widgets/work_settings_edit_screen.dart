import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/work_attendance_service.dart';

String _formatNumberForInput(num value) =>
    NumberFormat('#,##0.####', 'it_IT').format(value).replaceAll('.', '');

double? _parseItalianNumber(String text) {
  final cleaned = text.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

/// Edit form for the `work_settings` values other than the rate periods and
/// `work_instructor_user_id` (never shown or editable here). Reached only
/// from [WorkSettingsScreen], principal admin only — RLS also enforces this
/// on the server for the underlying writes.
class WorkSettingsEditScreen extends StatefulWidget {
  const WorkSettingsEditScreen({Key? key, required this.settings}) : super(key: key);

  final WorkSettings settings;

  @override
  State<WorkSettingsEditScreen> createState() => _WorkSettingsEditScreenState();
}

class _WorkSettingsEditScreenState extends State<WorkSettingsEditScreen> {
  final _service = WorkAttendanceService.instance;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _annualLimitController;
  late final TextEditingController _incomeBeforeContractController;
  late final TextEditingController _incomeBeforeContractYearController;
  late final TextEditingController _mealVoucherValueController;
  late final TextEditingController _kmRoundTripController;
  late final TextEditingController _kmRateController;
  late final TextEditingController _aciUrlController;
  late final TextEditingController _vehicleController;
  late final TextEditingController _routeFromController;
  late final TextEditingController _routeToController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _annualLimitController = TextEditingController(text: _formatNumberForInput(s.annualLimit));
    _incomeBeforeContractController =
        TextEditingController(text: _formatNumberForInput(s.incomeBeforeContract));
    _incomeBeforeContractYearController =
        TextEditingController(text: s.incomeBeforeContractYear.toString());
    _mealVoucherValueController =
        TextEditingController(text: _formatNumberForInput(s.mealVoucherValue));
    _kmRoundTripController = TextEditingController(text: _formatNumberForInput(s.kmRoundTrip));
    _kmRateController = TextEditingController(text: _formatNumberForInput(s.kmRate));
    _aciUrlController = TextEditingController(text: s.aciUrl ?? '');
    _vehicleController = TextEditingController(text: s.vehicle ?? '');
    _routeFromController = TextEditingController(text: s.routeFrom ?? '');
    _routeToController = TextEditingController(text: s.routeTo ?? '');
  }

  @override
  void dispose() {
    _annualLimitController.dispose();
    _incomeBeforeContractController.dispose();
    _incomeBeforeContractYearController.dispose();
    _mealVoucherValueController.dispose();
    _kmRoundTripController.dispose();
    _kmRateController.dispose();
    _aciUrlController.dispose();
    _vehicleController.dispose();
    _routeFromController.dispose();
    _routeToController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _service.updateSettings({
        'work_annual_limit': _parseItalianNumber(_annualLimitController.text)!.toString(),
        'work_income_before_contract':
            _parseItalianNumber(_incomeBeforeContractController.text)!.toString(),
        'work_income_before_contract_year': _incomeBeforeContractYearController.text.trim(),
        'work_meal_voucher_value':
            _parseItalianNumber(_mealVoucherValueController.text)!.toString(),
        'work_km_round_trip': _parseItalianNumber(_kmRoundTripController.text)!.toString(),
        'work_km_rate': _parseItalianNumber(_kmRateController.text)!.toString(),
        'work_aci_url': _aciUrlController.text.trim(),
        'work_vehicle': _vehicleController.text.trim(),
        'work_route_from': _routeFromController.text.trim(),
        'work_route_to': _routeToController.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  String? _numberValidator(String? v) =>
      _parseItalianNumber(v ?? '') == null ? 'Valore non valido' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifica altri valori'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewPadding.bottom + 24,
          ),
          children: [
            TextFormField(
              controller: _annualLimitController,
              decoration: const InputDecoration(labelText: 'Limite annuo (€) *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _numberValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _incomeBeforeContractController,
              decoration:
                  const InputDecoration(labelText: 'Già percepito prima del contratto (€) *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _numberValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _incomeBeforeContractYearController,
              decoration: const InputDecoration(labelText: 'Anno del già percepito *'),
              keyboardType: TextInputType.number,
              validator: (v) => int.tryParse(v?.trim() ?? '') == null ? 'Valore non valido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mealVoucherValueController,
              decoration: const InputDecoration(labelText: 'Valore buono pasto (€) *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _numberValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kmRoundTripController,
              decoration: const InputDecoration(labelText: 'Km andata e ritorno *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _numberValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _kmRateController,
              decoration: const InputDecoration(labelText: 'Tariffa km ACI (€) *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _numberValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _aciUrlController,
              decoration: const InputDecoration(labelText: 'Link tabella ACI (facoltativo)'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleController,
              decoration: const InputDecoration(labelText: 'Veicolo (facoltativo)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _routeFromController,
              decoration: const InputDecoration(labelText: 'Percorso da (facoltativo)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _routeToController,
              decoration: const InputDecoration(labelText: 'Percorso a (facoltativo)'),
            ),
          ],
        ),
      ),
    );
  }
}
