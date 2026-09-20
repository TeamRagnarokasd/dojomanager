import 'package:flutter/material.dart';

import '../../../services/asd_deadlines_service.dart';
import '../../../services/asd_governance_service.dart';

/// Add/edit form for one `asd_deadlines` row. Pops `true` when a save
/// succeeded so the caller can refresh, `false`/null otherwise.
class AsdDeadlineFormScreen extends StatefulWidget {
  const AsdDeadlineFormScreen({Key? key, this.deadline}) : super(key: key);

  final AsdDeadline? deadline;

  @override
  State<AsdDeadlineFormScreen> createState() => _AsdDeadlineFormScreenState();
}

enum _RepeatMode { yearly, everyNMonths, once }

class _AsdDeadlineFormScreenState extends State<AsdDeadlineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AsdDeadlinesService.instance;
  final _governanceService = AsdGovernanceService.instance;

  late final TextEditingController _titleController;
  late final TextEditingController _noticeDaysController;
  late final TextEditingController _notesController;
  late final TextEditingController _howToController;
  late final TextEditingController _conditionNoteController;
  late final TextEditingController _documentAgendaController;
  late final TextEditingController _driveUrlController;

  late String _category;
  late int _dueDay;
  late int _dueMonth;
  late _RepeatMode _repeatMode;
  late int _everyNMonths;
  late int _oneTimeYear;
  late bool _needsConfirmation;
  late bool _isActive;
  late List<AsdLegalRef> _legalRefs;
  late List<String> _selectedTemplateKeys;

  bool _isSaving = false;
  bool _isLoadingTemplates = true;
  List<AsdDocumentTemplate> _availableTemplates = [];

  static const List<String> _monthNames = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  bool get _isEditing => widget.deadline != null;

  @override
  void initState() {
    super.initState();
    final d = widget.deadline;
    _titleController = TextEditingController(text: d?.title ?? '');
    _noticeDaysController =
        TextEditingController(text: (d?.noticeDays ?? 30).toString());
    _notesController = TextEditingController(text: d?.notes ?? '');
    _howToController = TextEditingController(text: d?.howTo ?? '');
    _conditionNoteController = TextEditingController(text: d?.conditionNote ?? '');
    _documentAgendaController = TextEditingController(text: d?.documentAgenda ?? '');
    _driveUrlController = TextEditingController(text: d?.driveUrl ?? '');

    _category = d?.category ?? kAsdDeadlineCategoryKeys.first;
    _dueDay = d?.dueDay ?? 1;
    _dueMonth = d?.dueMonth ?? 1;
    _needsConfirmation = d?.needsConfirmation ?? false;
    _isActive = d?.isActive ?? true;
    _legalRefs = List.of(d?.legalRefs ?? const []);
    _selectedTemplateKeys = List.of(d?.documentTemplates ?? const []);

    if (d == null) {
      _repeatMode = _RepeatMode.yearly;
      _everyNMonths = 2;
      _oneTimeYear = DateTime.now().year;
    } else if (d.isOneTime) {
      _repeatMode = _RepeatMode.once;
      _everyNMonths = 2;
      _oneTimeYear = d.dueYear!;
    } else if (d.repeatMonths == 12) {
      _repeatMode = _RepeatMode.yearly;
      _everyNMonths = 2;
      _oneTimeYear = DateTime.now().year;
    } else {
      _repeatMode = _RepeatMode.everyNMonths;
      _everyNMonths = d.repeatMonths.clamp(1, 11);
      _oneTimeYear = DateTime.now().year;
    }

    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _governanceService.getDocumentTemplates();
      if (!mounted) return;
      setState(() {
        _availableTemplates = templates;
        _isLoadingTemplates = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingTemplates = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noticeDaysController.dispose();
    _notesController.dispose();
    _howToController.dispose();
    _conditionNoteController.dispose();
    _documentAgendaController.dispose();
    _driveUrlController.dispose();
    super.dispose();
  }

  int _daysInMonth(int month, int year) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      return isLeap ? 29 : 28;
    }
    const days31 = {1, 3, 5, 7, 8, 10, 12};
    return days31.contains(month) ? 31 : 30;
  }

  void _onMonthChanged(int month) {
    setState(() {
      _dueMonth = month;
      final maxDay = _daysInMonth(_dueMonth, _oneTimeYear);
      if (_dueDay > maxDay) _dueDay = maxDay;
    });
  }

  Future<void> _addLegalRef() async {
    final labelController = TextEditingController();
    final urlController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo riferimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Etichetta'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'Link'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
    if (added != true) return;
    if (labelController.text.trim().isEmpty || urlController.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _legalRefs = [
        ..._legalRefs,
        AsdLegalRef(label: labelController.text.trim(), url: urlController.text.trim()),
      ];
    });
  }

  void _removeLegalRef(int index) {
    setState(() {
      _legalRefs = List.of(_legalRefs)..removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final maxDay = _daysInMonth(
      _dueMonth,
      _repeatMode == _RepeatMode.once ? _oneTimeYear : DateTime.now().year,
    );
    if (_dueDay > maxDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Il giorno $_dueDay non esiste per il mese selezionato.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final values = <String, dynamic>{
      'title': _titleController.text.trim(),
      'category': _category,
      'due_month': _dueMonth,
      'due_day': _dueDay,
      'due_year': _repeatMode == _RepeatMode.once ? _oneTimeYear : null,
      'repeat_months': _repeatMode == _RepeatMode.yearly
          ? 12
          : _repeatMode == _RepeatMode.everyNMonths
              ? _everyNMonths
              : 12,
      'notice_days': int.tryParse(_noticeDaysController.text.trim()) ?? 30,
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      'needs_confirmation': _needsConfirmation,
      'is_active': _isActive,
      'condition_note': _conditionNoteController.text.trim().isEmpty
          ? null
          : _conditionNoteController.text.trim(),
      'how_to': _howToController.text.trim().isEmpty ? null : _howToController.text.trim(),
      'legal_refs': _legalRefs.map((r) => r.toJson()).toList(),
      'document_templates': _selectedTemplateKeys,
      'document_agenda': _documentAgendaController.text.trim().isEmpty
          ? null
          : _documentAgendaController.text.trim(),
      'drive_url': _driveUrlController.text.trim().isEmpty
          ? null
          : _driveUrlController.text.trim(),
    };

    try {
      if (_isEditing) {
        await _service.updateDeadline(widget.deadline!.id, values);
      } else {
        await _service.createDeadline(values);
      }
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

  @override
  Widget build(BuildContext context) {
    final maxDay = _daysInMonth(
      _dueMonth,
      _repeatMode == _RepeatMode.once ? _oneTimeYear : DateTime.now().year,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica scadenza' : 'Nuova scadenza'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titolo *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: kAsdDeadlineCategoryKeys
                  .map((key) => DropdownMenuItem(value: key, child: Text(asdCategoryLabel(key))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 16),
            const Text('Ripetizione', style: TextStyle(fontWeight: FontWeight.w700)),
            RadioListTile<_RepeatMode>(
              contentPadding: EdgeInsets.zero,
              value: _RepeatMode.yearly,
              groupValue: _repeatMode,
              title: const Text('Ogni anno'),
              onChanged: (value) => setState(() => _repeatMode = value!),
            ),
            RadioListTile<_RepeatMode>(
              contentPadding: EdgeInsets.zero,
              value: _RepeatMode.everyNMonths,
              groupValue: _repeatMode,
              title: Row(
                children: [
                  const Text('Ogni'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: DropdownButtonFormField<int>(
                      initialValue: _everyNMonths,
                      items: List.generate(11, (i) => i + 1)
                          .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                          .toList(),
                      onChanged: _repeatMode == _RepeatMode.everyNMonths
                          ? (value) {
                              if (value != null) setState(() => _everyNMonths = value);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('mesi'),
                ],
              ),
              onChanged: (value) => setState(() => _repeatMode = value!),
            ),
            RadioListTile<_RepeatMode>(
              contentPadding: EdgeInsets.zero,
              value: _RepeatMode.once,
              groupValue: _repeatMode,
              title: Row(
                children: [
                  const Text('Una volta sola, nell\'anno'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      enabled: _repeatMode == _RepeatMode.once,
                      initialValue: _oneTimeYear.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final year = int.tryParse(value);
                        if (year != null) setState(() => _oneTimeYear = year);
                      },
                    ),
                  ),
                ],
              ),
              onChanged: (value) => setState(() => _repeatMode = value!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _dueMonth,
                    decoration: const InputDecoration(labelText: 'Mese'),
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _onMonthChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _dueDay,
                    decoration: const InputDecoration(labelText: 'Giorno'),
                    items: List.generate(maxDay, (i) => i + 1)
                        .map((day) => DropdownMenuItem(value: day, child: Text('$day')))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _dueDay = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noticeDaysController,
              decoration: const InputDecoration(labelText: 'Giorni di preavviso'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _howToController,
              decoration: const InputDecoration(
                labelText: 'Guida pratica (un passaggio per riga)',
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            const Text('Riferimenti normativi', style: TextStyle(fontWeight: FontWeight.w700)),
            ..._legalRefs.asMap().entries.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(entry.value.label),
                    subtitle: Text(entry.value.url),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeLegalRef(entry.key),
                    ),
                  ),
                ),
            TextButton.icon(
              onPressed: _addLegalRef,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi riferimento'),
            ),
            const SizedBox(height: 16),
            const Text('Documenti da generare', style: TextStyle(fontWeight: FontWeight.w700)),
            if (_isLoadingTemplates)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_availableTemplates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nessun modello disponibile.'),
              )
            else
              ..._availableTemplates.map(
                (template) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedTemplateKeys.contains(template.key),
                  title: Text(template.title),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedTemplateKeys = [..._selectedTemplateKeys, template.key];
                      } else {
                        _selectedTemplateKeys =
                            _selectedTemplateKeys.where((k) => k != template.key).toList();
                      }
                    });
                  },
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _documentAgendaController,
              decoration: const InputDecoration(labelText: 'Ordine del giorno predefinito'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _driveUrlController,
              decoration: const InputDecoration(
                labelText: 'Cartella Drive di questa voce (link, facoltativo)',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data da confermare'),
              value: _needsConfirmation,
              onChanged: (value) => setState(() => _needsConfirmation = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Attiva'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _conditionNoteController,
              decoration: const InputDecoration(
                labelText: 'Quando si applica (facoltativo)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
