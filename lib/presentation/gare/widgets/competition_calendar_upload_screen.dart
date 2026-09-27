import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/competitions_service.dart';

/// Riga letta dal calendario, modificabile dall'admin prima di pubblicare.
class _DraftCompetition {
  final TextEditingController nameController;
  final TextEditingController cityController;
  final TextEditingController notesController;
  final TextEditingController linkController;
  DateTime? startDate;
  DateTime? endDate;
  bool included;

  _DraftCompetition({
    required String name,
    required String city,
    required String notes,
    this.startDate,
    this.endDate,
    this.included = true,
  })  : nameController = TextEditingController(text: name),
        cityController = TextEditingController(text: city),
        notesController = TextEditingController(text: notes),
        linkController = TextEditingController();

  void dispose() {
    nameController.dispose();
    cityController.dispose();
    notesController.dispose();
    linkController.dispose();
  }
}

/// Admin: sceglie una categoria, carica la foto di un calendario gare,
/// Claude la legge (edge function competition-calendar-read), l'admin
/// controlla/corregge ogni riga, aggiunge il link di iscrizione e infine
/// pubblica (insert vero in `competitions`) solo le righe confermate.
class CompetitionCalendarUploadScreen extends StatefulWidget {
  const CompetitionCalendarUploadScreen({super.key});

  @override
  State<CompetitionCalendarUploadScreen> createState() =>
      _CompetitionCalendarUploadScreenState();
}

class _CompetitionCalendarUploadScreenState
    extends State<CompetitionCalendarUploadScreen> {
  String _category = CompetitionsService.categories.first;
  String? _imagePath;
  bool _isUploadingImage = false;
  bool _isReadingCalendar = false;
  bool _isPublishing = false;
  List<_DraftCompetition>? _drafts;

  @override
  void dispose() {
    _drafts?.forEach((d) => d.dispose());
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _isUploadingImage = true);
    final path = await CompetitionsService.instance.pickAndUploadSourceImage();
    if (!mounted) return;
    setState(() {
      _isUploadingImage = false;
      if (path != null) _imagePath = path;
    });
  }

  Future<void> _readCalendar() async {
    if (_imagePath == null) return;
    setState(() => _isReadingCalendar = true);
    try {
      final rows = await CompetitionsService.instance.readCalendar(
        _imagePath!,
      );
      if (!mounted) return;
      setState(() {
        _drafts = rows.map((row) {
          DateTime? start;
          DateTime? end;
          try {
            start = DateTime.parse(row['event_date_start'].toString());
          } catch (_) {}
          try {
            end = DateTime.parse(row['event_date_end'].toString());
          } catch (_) {}
          return _DraftCompetition(
            name: (row['name'] ?? '').toString(),
            city: (row['city'] ?? '').toString(),
            notes: (row['notes'] ?? '').toString(),
            startDate: start,
            endDate: end,
          );
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isReadingCalendar = false);
    }
  }

  Future<void> _pickDraftDate(_DraftCompetition draft, bool isStart) async {
    final initial = (isStart ? draft.startDate : draft.endDate) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        draft.startDate = picked;
      } else {
        draft.endDate = picked;
      }
    });
  }

  Future<void> _publish() async {
    final drafts = _drafts;
    if (drafts == null) return;
    final selected = drafts.where((d) => d.included).toList();
    if (selected.isEmpty) return;

    for (final draft in selected) {
      if (draft.nameController.text.trim().isEmpty || draft.startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ogni riga selezionata richiede nome e data di inizio.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isPublishing = true);
    try {
      final rows = selected.map((draft) {
        final start = draft.startDate!;
        final end = draft.endDate ?? start;
        return <String, dynamic>{
          'category': _category,
          'name': draft.nameController.text.trim(),
          'event_date_start': _dateOnly(start),
          'event_date_end': _dateOnly(end),
          'city': draft.cityController.text.trim().isEmpty
              ? null
              : draft.cityController.text.trim(),
          'notes': draft.notesController.text.trim().isEmpty
              ? null
              : draft.notesController.text.trim(),
          'registration_link': draft.linkController.text.trim().isEmpty
              ? null
              : draft.linkController.text.trim(),
          'source_image_path': _imagePath,
        };
      }).toList();

      await CompetitionsService.instance.publishCompetitions(rows);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nella pubblicazione: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T')[0];

  String _formatDate(DateTime? date) {
    if (date == null) return 'Seleziona data';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carica calendario gare')),
      body: _drafts == null ? _buildUploadStep() : _buildReviewStep(),
    );
  }

  Widget _buildUploadStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categoria',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 1.h),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: CompetitionsService.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(CompetitionsService.categoryLabel(category)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          SizedBox(height: 3.h),
          Text(
            'Foto del calendario',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 1.h),
          OutlinedButton.icon(
            onPressed: _isUploadingImage ? null : _pickImage,
            icon: _isUploadingImage
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_library_outlined),
            label: Text(
              _imagePath == null ? 'Scegli dalla galleria' : 'Cambia foto',
            ),
          ),
          if (_imagePath != null)
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Text(
                'Foto caricata ✓',
                style: TextStyle(color: Colors.green[700]),
              ),
            ),
          SizedBox(height: 3.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_imagePath == null || _isReadingCalendar)
                  ? null
                  : _readCalendar,
              icon: _isReadingCalendar
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isReadingCalendar ? 'Lettura in corso...' : 'Leggi calendario',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final drafts = _drafts!;
    if (drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Text(
            'Nessuna gara riconosciuta nella foto. Torna indietro e riprova con un\'altra immagine.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(4.w),
            itemCount: drafts.length,
            itemBuilder: (context, index) => _buildDraftCard(drafts[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPublishing ? null : _publish,
                child: _isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Pubblica ${drafts.where((d) => d.included).length} gare',
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftCard(_DraftCompetition draft) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: draft.included,
                onChanged: (value) =>
                    setState(() => draft.included = value ?? true),
              ),
              Expanded(
                child: TextFormField(
                  controller: draft.nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome gara',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDraftDate(draft, true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Inizio',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatDate(draft.startDate)),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDraftDate(draft, false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fine',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_formatDate(draft.endDate ?? draft.startDate)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          TextFormField(
            controller: draft.cityController,
            decoration: const InputDecoration(
              labelText: 'Città',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            controller: draft.notesController,
            decoration: const InputDecoration(
              labelText: 'Note',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            controller: draft.linkController,
            decoration: const InputDecoration(
              labelText: 'Link iscrizione',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }
}
