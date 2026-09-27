import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/competitions_service.dart';
import './competition_list_item.dart' show kCompetitionPosterCardAspectRatio;

/// Foglio di modifica di una gara esistente in `competitions`, con
/// salvataggio vero (update) ed eliminazione (con conferma) tramite
/// [CompetitionsService]. La categoria itera su
/// [CompetitionsService.categories], quindi comprende automaticamente
/// eventuali nuove categorie (es. K1) senza bisogno di modifiche qui.
class CompetitionEditSheet extends StatefulWidget {
  final Map<String, dynamic> competition;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  const CompetitionEditSheet({
    super.key,
    required this.competition,
    required this.onSaved,
    required this.onDeleted,
  });

  @override
  State<CompetitionEditSheet> createState() => _CompetitionEditSheetState();
}

class _CompetitionEditSheetState extends State<CompetitionEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _notesController = TextEditingController();
  final _linkController = TextEditingController();

  late String _category;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _posterPath;
  String _posterDisplayMode = 'riempi';
  double _posterFocusY = 0.5;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUploadingPoster = false;

  @override
  void initState() {
    super.initState();
    final c = widget.competition;
    _nameController.text = (c['name'] ?? '').toString();
    _cityController.text = (c['city'] ?? '').toString();
    _notesController.text = (c['notes'] ?? '').toString();
    _linkController.text = (c['registration_link'] ?? '').toString();
    _posterPath = c['poster_path'] as String?;
    final rawMode = c['poster_display_mode'] as String?;
    _posterDisplayMode = (rawMode == 'intera' || rawMode == 'riempi')
        ? rawMode!
        : 'riempi';
    final rawFocusY = c['poster_focus_y'];
    _posterFocusY = rawFocusY is num
        ? rawFocusY.toDouble().clamp(0.0, 1.0)
        : 0.5;
    final category = c['category'] as String?;
    _category = CompetitionsService.categories.contains(category)
        ? category!
        : CompetitionsService.categories.first;
    try {
      _startDate = DateTime.parse(c['event_date_start'].toString());
    } catch (_) {}
    try {
      _endDate = DateTime.parse(c['event_date_end'].toString());
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92.h,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Modifica gara',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: (_isSaving || _isDeleting)
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  SizedBox(width: 2.w),
                  ElevatedButton(
                    onPressed: (_isSaving || _isDeleting) ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salva'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nome gara*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Nome obbligatorio'
                                : null,
                      ),
                      SizedBox(height: 2.h),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                        ),
                        items: CompetitionsService.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(
                                  CompetitionsService.categoryLabel(category),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickDate(isStart: true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data inizio*',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_formatDate(_startDate)),
                              ),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickDate(isStart: false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data fine',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  _formatDate(_endDate ?? _startDate),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'Città',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                        controller: _linkController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Link iscrizione',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 3.h),
                      _buildPosterSection(),
                      SizedBox(height: 3.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: (_isSaving || _isDeleting)
                              ? null
                              : _confirmDelete,
                          icon: _isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                          label: const Text(
                            'Elimina gara',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterSection() {
    final posterUrl = CompetitionsService.instance.posterUrl(_posterPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Locandina',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        SizedBox(height: 1.h),
        Container(
          width: double.infinity,
          height: 20.h,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: _isUploadingPoster
              ? const Center(child: CircularProgressIndicator())
              : posterUrl == null
                  ? Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        posterUrl,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: 20.h,
                      ),
                    ),
        ),
        SizedBox(height: 1.h),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isUploadingPoster ? null : _pickPoster,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                posterUrl == null
                    ? 'Scegli dalla galleria'
                    : 'Cambia immagine',
              ),
            ),
            if (posterUrl != null) ...[
              SizedBox(width: 2.w),
              TextButton.icon(
                onPressed: _isUploadingPoster
                    ? null
                    : () => setState(() => _posterPath = null),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Rimuovi'),
              ),
            ],
          ],
        ),
        if (posterUrl != null) ...[
          SizedBox(height: 3.h),
          Text(
            'Come mostrarla nella scheda',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 1.h),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'intera',
                label: Text('Locandina intera'),
                icon: Icon(Icons.crop_free),
              ),
              ButtonSegment(
                value: 'riempi',
                label: Text('Riempi scheda'),
                icon: Icon(Icons.crop),
              ),
            ],
            selected: {_posterDisplayMode},
            onSelectionChanged: (selection) {
              setState(() => _posterDisplayMode = selection.first);
            },
          ),
          if (_posterDisplayMode == 'riempi') ...[
            SizedBox(height: 2.h),
            Text(
              'Anteprima nella scheda',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 1.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: kCompetitionPosterCardAspectRatio,
                child: Container(
                  color: Colors.black,
                  child: Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment(0, _posterFocusY * 2 - 1),
                  ),
                ),
              ),
            ),
            SizedBox(height: 1.h),
            Row(
              children: [
                const Icon(Icons.vertical_align_top, size: 18),
                Expanded(
                  child: Slider(
                    value: _posterFocusY,
                    onChanged: (value) {
                      setState(() => _posterFocusY = value);
                    },
                  ),
                ),
                const Icon(Icons.vertical_align_bottom, size: 18),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickPoster() async {
    setState(() => _isUploadingPoster = true);
    final path = await CompetitionsService.instance.pickAndUploadPoster();
    if (!mounted) return;
    setState(() {
      _isUploadingPoster = false;
      if (path != null) _posterPath = path;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial =
        (isStart ? _startDate : _endDate) ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Seleziona data';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T')[0];

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona la data di inizio.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final start = _startDate!;
      final end = _endDate ?? start;
      final data = <String, dynamic>{
        'category': _category,
        'name': _nameController.text.trim(),
        'event_date_start': _dateOnly(start),
        'event_date_end': _dateOnly(end),
        'city': _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'registration_link': _linkController.text.trim().isEmpty
            ? null
            : _linkController.text.trim(),
        'poster_path': _posterPath,
        'poster_display_mode': _posterDisplayMode,
        'poster_focus_y': _posterFocusY,
      };

      await CompetitionsService.instance.updateCompetition(
        widget.competition['id'].toString(),
        data,
      );

      HapticFeedback.lightImpact();
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel salvataggio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare la gara?'),
        content: Text(
          'La gara "${_nameController.text.trim()}" verrà eliminata '
          'definitivamente, insieme a interessi e iscrizioni collegati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await CompetitionsService.instance.deleteCompetition(
        widget.competition['id'].toString(),
      );
      widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Errore nell'eliminazione: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}
