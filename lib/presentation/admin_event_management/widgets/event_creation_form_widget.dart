import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class EventCreationFormWidget extends StatefulWidget {
  final Map<String, dynamic>? existingEvent;
  final DateTime? initialDate;
  final List<String> availableInstructors;
  final List<String> disciplines;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const EventCreationFormWidget({
    super.key,
    this.existingEvent,
    this.initialDate,
    required this.availableInstructors,
    required this.disciplines,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<EventCreationFormWidget> createState() =>
      _EventCreationFormWidgetState();
}

class _EventCreationFormWidgetState extends State<EventCreationFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _venueController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _equipmentController = TextEditingController();

  String _selectedType = 'seminario';
  String? _selectedInstructor;
  String? _selectedDiscipline;
  String _selectedPriority = 'medium';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String _imageUrl =
      'https://images.unsplash.com/photo-1555597408-966dcdc2b8b0?w=400';

  final List<String> eventTypes = ['seminario', 'stage'];
  final List<String> priorities = ['low', 'medium', 'high'];
  final List<String> venues = [
    'Sala BJJ secondo piano',
    'Gabbia MMA',
    'Palestra principale',
    'Tatami sambo',
    'Sala grappling',
    'Dojo A',
    'Dojo B',
  ];

  final List<String> stockImages = [
    'https://images.unsplash.com/photo-1555597408-966dcdc2b8b0?w=400',
    'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?w=400',
    'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
    'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.existingEvent != null) {
      final event = widget.existingEvent!;
      _titleController.text = event['title'] ?? '';
      _descriptionController.text = event['description'] ?? '';
      _priceController.text = event['price'].toString();
      _capacityController.text = event['capacity'].toString();
      _venueController.text = event['venue'] ?? '';
      _requirementsController.text = event['requirements'] ?? '';
      _equipmentController.text = event['equipment'] ?? '';

      _selectedType = event['type'] ?? 'seminario';
      _selectedInstructor = event['instructor'];
      _selectedDiscipline = event['category'];
      _selectedPriority = event['priority'] ?? 'medium';
      _selectedDate = event['date'] ?? DateTime.now();
      _imageUrl = event['image'] ?? stockImages[0];

      // Parse time from string like "14:00 - 18:00"
      if (event['time'] != null) {
        final timeParts = event['time'].split(' - ');
        if (timeParts.length == 2) {
          final startParts = timeParts[0].split(':');
          final endParts = timeParts[1].split(':');
          _startTime = TimeOfDay(
            hour: int.parse(startParts[0]),
            minute: int.parse(startParts[1]),
          );
          _endTime = TimeOfDay(
            hour: int.parse(endParts[0]),
            minute: int.parse(endParts[1]),
          );
        }
      }
    } else if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    _venueController.dispose();
    _requirementsController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85.h,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[800]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  widget.existingEvent != null
                      ? 'Modifica Evento'
                      : 'admin_event.new_event'.tr(),
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'common.cancel'.tr(),
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ),
                SizedBox(width: 2.w),
                ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                  ),
                  child: Text('common.save'.tr()),
                ),
              ],
            ),
          ),

          // Form content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(),
                    SizedBox(height: 3.h),
                    _buildDateTimeSection(),
                    SizedBox(height: 3.h),
                    _buildDetailsSection(),
                    SizedBox(height: 3.h),
                    _buildImageSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informazioni Base',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),

        // Event title
        TextFormField(
          controller: _titleController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Titolo Evento*',
            labelStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF0000)),
            ),
          ),
          validator: (value) =>
              value?.isEmpty == true ? 'Titolo obbligatorio' : null,
        ),
        SizedBox(height: 2.h),

        // Type and discipline row
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedType,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tipo Evento',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: Colors.grey[800],
                items: eventTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: widget.disciplines.contains(_selectedDiscipline)
                    ? _selectedDiscipline
                    : null,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Disciplina',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                hint: Text(
                  'Seleziona disciplina',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                dropdownColor: Colors.grey[800],
                items: widget.disciplines
                    .map(
                      (discipline) => DropdownMenuItem(
                        value: discipline,
                        child: Text(
                          discipline,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedDiscipline = value),
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),

        // Description
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Descrizione*',
            labelStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF0000)),
            ),
          ),
          validator: (value) =>
              value?.isEmpty == true ? 'Descrizione obbligatoria' : null,
        ),
      ],
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data e Orario',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),

        // Date picker
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'calendar_today',
                  color: Colors.grey[400]!,
                  size: 20,
                ),
                SizedBox(width: 3.w),
                Text(
                  'Data: ${_formatDate(_selectedDate)}',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 2.h),

        // Time pickers
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTime(true),
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'schedule',
                        color: Colors.grey[400]!,
                        size: 20,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Inizio: ${_startTime.format(context)}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTime(false),
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'schedule',
                        color: Colors.grey[400]!,
                        size: 20,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Fine: ${_endTime.format(context)}',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'receipt.details_label'.tr(),
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),

        // Instructor dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedInstructor,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Istruttore*',
            labelStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: Colors.grey[800],
          items: widget.availableInstructors
              .map(
                (instructor) => DropdownMenuItem(
                  value: instructor.split(' - ')[0],
                  child: Text(
                    instructor,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedInstructor = value),
          validator: (value) =>
              value == null ? 'Istruttore obbligatorio' : null,
        ),
        SizedBox(height: 2.h),

        // Venue dropdown
        DropdownButtonFormField<String>(
          initialValue: venues.contains(_venueController.text)
              ? _venueController.text
              : null,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Sede*',
            labelStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: Colors.grey[800],
          items: venues
              .map(
                (venue) => DropdownMenuItem(
                  value: venue,
                  child: Text(venue, style: TextStyle(color: Colors.white)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _venueController.text = value!),
          validator: (value) => value == null ? 'Sede obbligatoria' : null,
        ),
        SizedBox(height: 2.h),

        // Capacity and price row
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Posti Disponibili*',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Obbligatorio' : null,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Prezzo (€)*',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Obbligatorio' : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),

        // Priority dropdown
        DropdownButtonFormField<String>(
          initialValue: _selectedPriority,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Priorità',
            labelStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          dropdownColor: Colors.grey[800],
          items: priorities
              .map(
                (priority) => DropdownMenuItem(
                  value: priority,
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedPriority = value!),
        ),
        SizedBox(height: 2.h),

        // Requirements
        TextFormField(
          controller: _requirementsController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Requisiti',
            labelStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        SizedBox(height: 2.h),

        // Equipment
        TextFormField(
          controller: _equipmentController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Attrezzatura',
            labelStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Immagine Evento',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),

        // Current image preview
        Container(
          width: double.infinity,
          height: 20.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomImageWidget(imageUrl: _imageUrl, fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: 2.h),

        // Image selection
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: stockImages
              .map(
                (imageUrl) => GestureDetector(
                  onTap: () => setState(() => _imageUrl = imageUrl),
                  child: Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _imageUrl == imageUrl
                            ? const Color(0xFFFF0000)
                            : Colors.grey[700]!,
                        width: _imageUrl == imageUrl ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CustomImageWidget(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF0000),
              surface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF0000),
              surface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveEvent() {
    if (_formKey.currentState?.validate() != true) return;
    if (_selectedInstructor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin_event.select_instructor'.tr()),
          backgroundColor: AppTheme.errorLight,
        ),
      );
      return;
    }

    final eventData = {
      'title': _titleController.text,
      'type': _selectedType,
      'date': _selectedDate,
      'time': '${_startTime.format(context)} - ${_endTime.format(context)}',
      'instructor': _selectedInstructor!,
      'instructorId': 'instructor_${DateTime.now().millisecondsSinceEpoch}',
      'venue': _venueController.text,
      'capacity': int.parse(_capacityController.text),
      'price': double.parse(_priceController.text),
      'description': _descriptionController.text,
      'image': _imageUrl,
      'priority': _selectedPriority,
      'category': _selectedDiscipline,
      'requirements': _requirementsController.text,
      'equipment': _equipmentController.text,
    };

    widget.onSave(eventData);
  }

  String _formatDate(DateTime date) {
    final months = [
      '',
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}
