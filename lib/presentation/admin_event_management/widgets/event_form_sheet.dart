import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/events_service.dart';

/// Foglio di creazione/modifica di un evento in `events_seminars`, con
/// salvataggio vero (insert/update) tramite [EventsService]. Il "Luogo" è
/// testo libero: la "Sala" compare solo se il testo digitato è esattamente
/// "Palacosta", altrimenti viene salvata come null.
class EventFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existingEvent;
  final List<String> disciplines;
  final VoidCallback onSaved;

  const EventFormSheet({
    super.key,
    this.existingEvent,
    required this.disciplines,
    required this.onSaved,
  });

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructorController = TextEditingController();
  final _locationController = TextEditingController();
  final _roomController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedDiscipline;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  String? _posterPath;
  bool _isSaving = false;
  bool _isUploadingPoster = false;

  bool get _isEditing => widget.existingEvent != null;
  bool get _showRoomField =>
      _locationController.text.trim() == 'Palacosta';

  @override
  void initState() {
    super.initState();
    final event = widget.existingEvent;
    if (event != null) {
      _titleController.text = (event['title'] ?? '').toString();
      _instructorController.text = (event['instructor_name'] ?? '').toString();
      _locationController.text = (event['location'] ?? '').toString();
      _roomController.text = (event['room'] ?? '').toString();
      _capacityController.text = (event['capacity'] ?? '').toString();
      final price = event['price'];
      _priceController.text = price == null ? '0' : price.toString();
      _descriptionController.text = (event['description'] ?? '').toString();
      _posterPath = event['poster_path'] as String?;
      final discipline = event['discipline'] as String?;
      _selectedDiscipline = widget.disciplines.contains(discipline)
          ? discipline
          : null;
      try {
        final dt = DateTime.parse(event['event_datetime'].toString()).toLocal();
        _selectedDate = DateTime(dt.year, dt.month, dt.day);
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      } catch (_) {}
    } else {
      _priceController.text = '0';
    }
    _locationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructorController.dispose();
    _locationController.dispose();
    _roomController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime get _eventDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

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
                    _isEditing ? 'Modifica Evento' : 'Nuovo Evento',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  SizedBox(width: 2.w),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
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
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titolo Evento*',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Titolo obbligatorio'
                                : null,
                      ),
                      SizedBox(height: 2.h),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDiscipline,
                        decoration: const InputDecoration(
                          labelText: 'Disciplina',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Seleziona disciplina'),
                        items: widget.disciplines
                            .map(
                              (discipline) => DropdownMenuItem(
                                value: discipline,
                                child: Text(discipline),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedDiscipline = value),
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                        controller: _instructorController,
                        decoration: const InputDecoration(
                          labelText: 'Istruttore',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_formatDate(_selectedDate)),
                              ),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickTime,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Ora',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(_selectedTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Luogo',
                          hintText: 'Es. Palacosta, Dojo A, ...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_showRoomField) ...[
                        SizedBox(height: 2.h),
                        TextFormField(
                          controller: _roomController,
                          decoration: const InputDecoration(
                            labelText: 'Sala',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _capacityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Posti Disponibili*',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final n = int.tryParse(value ?? '');
                                if (n == null || n <= 0) {
                                  return 'Numero non valido';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Prezzo (€)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                return double.tryParse(
                                          value.replaceAll(',', '.'),
                                        ) ==
                                        null
                                    ? 'Prezzo non valido'
                                    : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      _buildPosterSection(),
                      SizedBox(height: 3.h),
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
    final posterUrl = EventsService.instance.posterUrl(_posterPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Immagine Evento',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        SizedBox(height: 1.h),
        Container(
          width: double.infinity,
          height: 20.h,
          decoration: BoxDecoration(
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
                      child: CustomImageWidget(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 20.h,
                      ),
                    ),
        ),
        SizedBox(height: 1.h),
        OutlinedButton.icon(
          onPressed: _isUploadingPoster ? null : _pickPoster,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(posterUrl == null ? 'Scegli dalla galleria' : 'Cambia immagine'),
        ),
      ],
    );
  }

  Future<void> _pickPoster() async {
    setState(() => _isUploadingPoster = true);
    final path = await EventsService.instance.pickAndUploadPoster();
    if (!mounted) return;
    setState(() {
      _isUploadingPoster = false;
      if (path != null) _posterPath = path;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formatDate(DateTime date) {
    const months = [
      '',
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);
    try {
      final location = _locationController.text.trim();
      final isPalacosta = location == 'Palacosta';
      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'event_datetime': _eventDateTime.toIso8601String(),
        'discipline': _selectedDiscipline,
        'instructor_name': _instructorController.text.trim().isEmpty
            ? null
            : _instructorController.text.trim(),
        'location': location.isEmpty ? null : location,
        'room': isPalacosta && _roomController.text.trim().isNotEmpty
            ? _roomController.text.trim()
            : null,
        'capacity': int.parse(_capacityController.text.trim()),
        'price': double.tryParse(
              _priceController.text.trim().replaceAll(',', '.'),
            ) ??
            0,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'poster_path': _posterPath,
      };

      if (_isEditing) {
        await EventsService.instance.updateEvent(
          widget.existingEvent!['id'].toString(),
          data,
        );
      } else {
        data['status'] = 'pubblicato';
        await EventsService.instance.createEvent(data);
      }

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
}
