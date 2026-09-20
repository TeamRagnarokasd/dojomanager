import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/work_attendance_service.dart';
import 'work_settings_edit_screen.dart';

String _formatNumberForInput(num value) =>
    NumberFormat('#,##0.##', 'it_IT').format(value).replaceAll('.', '');

double? _parseItalianNumber(String text) {
  final cleaned = text.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

String _formatEuro(num value) => '€ ${NumberFormat('#,##0.00', 'it_IT').format(value)}';

/// "Impostazioni" (gear icon): two blocks — the rate-period history
/// (`work_rate_periods`, add/edit/delete, at least one must always remain)
/// and the other `work_settings` values (read here, edited via
/// [WorkSettingsEditScreen]). Editing is principal-admin only; everyone
/// else sees a read-only screen (enforced here in the UI and, for writes,
/// by RLS on the server).
class WorkSettingsScreen extends StatefulWidget {
  const WorkSettingsScreen({Key? key, required this.isPrincipalAdmin}) : super(key: key);

  final bool isPrincipalAdmin;

  @override
  State<WorkSettingsScreen> createState() => _WorkSettingsScreenState();
}

class _WorkSettingsScreenState extends State<WorkSettingsScreen> {
  final _service = WorkAttendanceService.instance;

  bool _isLoading = true;
  String? _loadError;
  List<WorkRatePeriod> _periods = [];
  WorkSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final periods = await _service.getRatePeriods();
      final settings = await _service.getSettings();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Errore nel caricamento: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showPeriodDialog({WorkRatePeriod? period}) async {
    final formKey = GlobalKey<FormState>();
    var selectedDate = period?.validFrom ?? DateTime.now();
    final rateController = TextEditingController(
      text: period != null ? _formatNumberForInput(period.hourlyRate) : '',
    );
    final lessonsController = TextEditingController(
      text: period != null ? period.paidLessonsPerWeek.toString() : '',
    );
    final hoursController = TextEditingController(
      text: period != null ? _formatNumberForInput(period.hoursPerLesson) : '',
    );
    final noteController = TextEditingController(text: period?.note ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(period == null ? 'Nuovo periodo' : 'Modifica periodo'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Valido dal'),
                    subtitle: Text(DateFormat('dd/MM/yyyy', 'it_IT').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(DateTime.now().year - 20),
                        lastDate: DateTime(DateTime.now().year + 10),
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rateController,
                    decoration: const InputDecoration(labelText: 'Tariffa oraria (€) *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        _parseItalianNumber(v ?? '') == null ? 'Valore non valido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lessonsController,
                    decoration: const InputDecoration(labelText: 'Lezioni pagate a settimana *'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        int.tryParse(v?.trim() ?? '') == null ? 'Valore non valido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: hoursController,
                    decoration: const InputDecoration(labelText: 'Ore per lezione *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                        _parseItalianNumber(v ?? '') == null ? 'Valore non valido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Nota (facoltativa)'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Un nuovo periodo vale dalla sua data e non cambia i mesi passati. '
                    'Aggiungilo quando cambia il contratto o la tariffa.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final hourlyRate = _parseItalianNumber(rateController.text)!;
    final paidLessonsPerWeek = int.parse(lessonsController.text.trim());
    final hoursPerLesson = _parseItalianNumber(hoursController.text)!;
    final note = noteController.text.trim();

    try {
      if (period == null) {
        await _service.addRatePeriod(
          validFrom: selectedDate,
          hourlyRate: hourlyRate,
          paidLessonsPerWeek: paidLessonsPerWeek,
          hoursPerLesson: hoursPerLesson,
          note: note,
        );
      } else {
        await _service.updateRatePeriod(
          originalValidFrom: period.validFrom,
          validFrom: selectedDate,
          hourlyRate: hourlyRate,
          paidLessonsPerWeek: paidLessonsPerWeek,
          hoursPerLesson: hoursPerLesson,
          note: note,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    }
  }

  Future<void> _confirmDeletePeriod(WorkRatePeriod period) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questo periodo?'),
        content: Text(
          'Eliminare il periodo dal ${DateFormat('dd/MM/yyyy', 'it_IT').format(period.validFrom)}? '
          'Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteRatePeriod(period.validFrom);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _openEditSettings() async {
    final settings = _settings;
    if (settings == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => WorkSettingsEditScreen(settings: settings)),
    );
    if (saved == true) await _load();
  }

  Widget _buildSettingsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodsSection() {
    final dayFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Periodi di compenso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.isPrincipalAdmin)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Nuovo periodo',
                    onPressed: () => _showPeriodDialog(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Un nuovo periodo vale dalla sua data e non cambia i mesi passati. '
              'Aggiungilo quando cambia il contratto o la tariffa.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_periods.isEmpty) const Text('Nessun periodo registrato.'),
            for (final period in _periods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Dal ${dayFormat.format(period.validFrom)}'),
                subtitle: Text(
                  '${_formatEuro(period.hourlyRate)}/h · '
                  '${period.paidLessonsPerWeek} lezioni/settimana · '
                  '${NumberFormat('#,##0.##', 'it_IT').format(period.hoursPerLesson)} h/lezione'
                  '${(period.note != null && period.note!.isNotEmpty) ? ' · ${period.note}' : ''}',
                ),
                trailing: widget.isPrincipalAdmin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Modifica',
                            onPressed: () => _showPeriodDialog(period: period),
                          ),
                          if (_periods.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: 'Elimina',
                              onPressed: () => _confirmDeletePeriod(period),
                            ),
                        ],
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherValuesSection() {
    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Altri valori',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.isPrincipalAdmin)
                  TextButton(onPressed: _openEditSettings, child: const Text('Modifica')),
              ],
            ),
            const SizedBox(height: 8),
            _buildSettingsRow('Limite annuo', _formatEuro(settings.annualLimit)),
            _buildSettingsRow(
              'Già percepito prima del contratto',
              _formatEuro(settings.incomeBeforeContract),
            ),
            _buildSettingsRow(
              'Anno del già percepito',
              settings.incomeBeforeContractYear.toString(),
            ),
            _buildSettingsRow('Valore buono pasto', _formatEuro(settings.mealVoucherValue)),
            _buildSettingsRow(
              'Km andata e ritorno',
              '${NumberFormat('#,##0.##', 'it_IT').format(settings.kmRoundTrip)} km',
            ),
            _buildSettingsRow(
              'Tariffa km (ACI)',
              '€ ${NumberFormat('#,##0.####', 'it_IT').format(settings.kmRate)}',
            ),
            _buildSettingsRow('Link tabella ACI', settings.aciUrl?.isNotEmpty == true ? settings.aciUrl! : '—'),
            _buildSettingsRow('Veicolo', settings.vehicle?.isNotEmpty == true ? settings.vehicle! : '—'),
            _buildSettingsRow('Percorso da', settings.routeFrom?.isNotEmpty == true ? settings.routeFrom! : '—'),
            _buildSettingsRow('Percorso a', settings.routeTo?.isNotEmpty == true ? settings.routeTo! : '—'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Riprova')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      MediaQuery.of(context).viewPadding.bottom + 24,
                    ),
                    children: [
                      _buildPeriodsSection(),
                      const SizedBox(height: 16),
                      _buildOtherValuesSection(),
                    ],
                  ),
                ),
    );
  }
}
