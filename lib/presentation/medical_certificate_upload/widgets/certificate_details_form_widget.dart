import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class CertificateDetailsFormWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onFormChanged;
  final bool isEnabled;

  const CertificateDetailsFormWidget({
    super.key,
    required this.onFormChanged,
    this.isEnabled = true,
  });

  @override
  State<CertificateDetailsFormWidget> createState() =>
      _CertificateDetailsFormWidgetState();
}

class _CertificateDetailsFormWidgetState
    extends State<CertificateDetailsFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _medicalCenterController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _certificateType;

  final List<Map<String, String>> _certificateTypes = [
    {'value': 'agonistico', 'label': 'Agonistico'},
    {'value': 'di_base', 'label': 'Di Base'},
    {'value': 'contatto_pieno', 'label': 'Per Contatto Pieno'},
  ];

  @override
  void initState() {
    super.initState();
    _setupFormListeners();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _doctorNameController.dispose();
    _medicalCenterController.dispose();
    super.dispose();
  }

  void _setupFormListeners() {
    _startDateController.addListener(_onDateTextChanged);
    _endDateController.addListener(_onDateTextChanged);
    _doctorNameController.addListener(_notifyFormChange);
    _medicalCenterController.addListener(_notifyFormChange);
  }

  void _onDateTextChanged() {
    // Parse dates from text input
    _parseStartDate(_startDateController.text);
    _parseEndDate(_endDateController.text);
    _notifyFormChange();
  }

  void _parseStartDate(String text) {
    final parsedDate = _parseDate(text);
    if (parsedDate != _startDate) {
      setState(() {
        _startDate = parsedDate;
      });
    }
  }

  void _parseEndDate(String text) {
    final parsedDate = _parseDate(text);
    if (parsedDate != _endDate) {
      setState(() {
        _endDate = parsedDate;
      });
    }
  }

  DateTime? _parseDate(String text) {
    if (text.isEmpty) return null;

    // Try to parse different formats: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
    final patterns = [
      RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$'),
      RegExp(
          r'^(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})$'), // YYYY/MM/DD format
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text.trim());
      if (match != null) {
        try {
          int day, month, year;

          if (pattern == patterns[0]) {
            // DD/MM/YYYY format
            day = int.parse(match.group(1)!);
            month = int.parse(match.group(2)!);
            year = int.parse(match.group(3)!);
          } else {
            // YYYY/MM/DD format
            year = int.parse(match.group(1)!);
            month = int.parse(match.group(2)!);
            day = int.parse(match.group(3)!);
          }

          // Validate date components
          if (month >= 1 &&
              month <= 12 &&
              day >= 1 &&
              day <= 31 &&
              year >= 1900 &&
              year <= 2100) {
            return DateTime(year, month, day);
          }
        } catch (e) {
          // Invalid date format
        }
      }
    }
    return null;
  }

  void _notifyFormChange() {
    final missingFields = <String>[];
    if (_startDate == null) missingFields.add('Data Inizio');
    if (_endDate == null) missingFields.add('Data Fine');
    if (_doctorNameController.text.trim().isEmpty) missingFields.add('Medico');
    if (_medicalCenterController.text.trim().isEmpty) {
      missingFields.add('Centro Medico');
    }
    if (_certificateType == null) missingFields.add('Tipologia Certificato');
    if (_startDate != null &&
        _endDate != null &&
        !_endDate!.isAfter(_startDate!)) {
      missingFields.add('Data Fine deve essere dopo Data Inizio');
    }

    final formData = {
      'startDate': _startDate,
      'endDate': _endDate,
      'doctorName': _doctorNameController.text.trim(),
      'medicalCenter': _medicalCenterController.text.trim(),
      'certificateType': _certificateType,
      'isValid': _isFormValid(),
      'missingFields': missingFields,
    };
    widget.onFormChanged(formData);
  }

  bool _isFormValid() {
    return _startDate != null &&
        _endDate != null &&
        _doctorNameController.text.trim().isNotEmpty &&
        _medicalCenterController.text.trim().isNotEmpty &&
        _certificateType != null &&
        _endDate!.isAfter(_startDate!);
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: isStartDate
            ? (_startDate ?? DateTime.now().subtract(const Duration(days: 30)))
            : (_endDate ?? DateTime.now().add(const Duration(days: 365))),
        firstDate: isStartDate
            ? DateTime.now().subtract(const Duration(days: 365))
            : (_startDate ?? DateTime.now()),
        lastDate: isStartDate
            ? DateTime.now().add(const Duration(days: 365))
            : DateTime.now().add(const Duration(days: 1095)), // 3 years
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFFF0000),
                onPrimary: Colors.white,
                surface: Color(0xFF2A2A2A),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null && mounted) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
            _startDateController.text = _formatDate(picked);
            // Reset end date if it's before the new start date
            if (_endDate != null && _endDate!.isBefore(picked)) {
              _endDate = null;
              _endDateController.clear();
            }
          } else {
            _endDate = picked;
            _endDateController.text = _formatDate(picked);
          }
        });
        _notifyFormChange();
      }
    } catch (e) {
      // Handle date picker errors gracefully
      debugPrint('Date picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nell\'apertura del calendario. Riprova.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withAlpha(77),
          width: 1,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(),
            SizedBox(height: 3.h),
            _buildDateFields(),
            SizedBox(height: 3.h),
            _buildDoctorAndCenterFields(),
            SizedBox(height: 3.h),
            _buildCertificateTypeField(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        CustomIconWidget(
          iconName: 'assignment',
          color: AppTheme.lightTheme.colorScheme.primary,
          size: 20,
        ),
        SizedBox(width: 2.w),
        Text(
          'Dettagli del Certificato',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.lightTheme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDateFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateField(
                controller: _startDateController,
                label: 'Data Inizio Certificato *',
                hintText: 'GG/MM/AAAA',
                onTap: () => _selectDate(context, true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Data richiesta';
                  }
                  if (_startDate == null) {
                    return 'Formato data non valido (GG/MM/AAAA)';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: _buildDateField(
                controller: _endDateController,
                label: 'Data Fine Certificato *',
                hintText: 'GG/MM/AAAA',
                onTap: () => _selectDate(context, false),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Data richiesta';
                  }
                  if (_endDate == null) {
                    return 'Formato data non valido (GG/MM/AAAA)';
                  }
                  if (_startDate != null && _endDate!.isBefore(_startDate!)) {
                    return 'Deve essere dopo l\'inizio';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        if (_endDate != null &&
            _endDate!.difference(DateTime.now()).inDays <= 30)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 2.h),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.error.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.error.withAlpha(77),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'warning',
                  color: AppTheme.lightTheme.colorScheme.error,
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Attenzione: Il certificato scade tra ${_endDate!.difference(DateTime.now()).inDays} giorni',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required VoidCallback onTap,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: widget.isEnabled,
      validator: validator,
      keyboardType: TextInputType.datetime,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\/\-\.]')),
        LengthLimitingTextInputFormatter(10), // DD/MM/YYYY = 10 characters
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: 'Puoi digitare la data o toccare il calendario',
        helperStyle: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
          color: AppTheme.lightTheme.colorScheme.onSurface.withAlpha(153),
          fontSize: 11,
        ),
        suffixIcon: InkWell(
          onTap: widget.isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: CustomIconWidget(
              iconName: 'calendar_today',
              color: widget.isEnabled
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.outline,
              size: 20,
            ),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.lightTheme.colorScheme.outline.withAlpha(128),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.lightTheme.colorScheme.outline.withAlpha(128),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.lightTheme.colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.lightTheme.colorScheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.lightTheme.colorScheme.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppTheme.lightTheme.colorScheme.outline.withAlpha(77),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorAndCenterFields() {
    return Column(
      children: [
        TextFormField(
          controller: _doctorNameController,
          enabled: widget.isEnabled,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Medico che ha visitato richiesto';
            }
            if (value.trim().length < 2) {
              return 'Nome troppo corto';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'Medico che ha Visitato *',
            hintText: 'Dr. Mario Rossi',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CustomIconWidget(
                iconName: 'person',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        SizedBox(height: 2.h),
        TextFormField(
          controller: _medicalCenterController,
          enabled: widget.isEnabled,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Centro medico richiesto';
            }
            if (value.trim().length < 3) {
              return 'Nome centro medico troppo corto';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'Centro Medico dove è stata effettuata la Visita *',
            hintText: 'Ospedale San Giovanni',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CustomIconWidget(
                iconName: 'local_hospital',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificateTypeField() {
    final bool showWarning = _certificateType == null &&
        _startDate != null &&
        _endDate != null &&
        _doctorNameController.text.trim().isNotEmpty &&
        _medicalCenterController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipologia di Certificato Medico *',
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            color: showWarning
                ? AppTheme.lightTheme.colorScheme.error
                : AppTheme.lightTheme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: showWarning
                ? AppTheme.lightTheme.colorScheme.error.withAlpha(13)
                : null,
            border: Border.all(
              color: showWarning
                  ? AppTheme.lightTheme.colorScheme.error
                  : AppTheme.lightTheme.colorScheme.outline.withAlpha(128),
              width: showWarning ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _certificateType,
              isExpanded: true,
              hint: Text(
                'Seleziona tipologia certificato',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color:
                      AppTheme.lightTheme.colorScheme.onSurface.withAlpha(153),
                ),
              ),
              icon: CustomIconWidget(
                iconName: 'arrow_drop_down',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              items: _certificateTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: _getCertificateTypeIcon(type['value']!),
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        type['label']!,
                        style: AppTheme.lightTheme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: widget.isEnabled
                  ? (String? newValue) {
                      setState(() {
                        _certificateType = newValue;
                      });
                      _notifyFormChange();
                    }
                  : null,
            ),
          ),
        ),
        if (_certificateType != null) ...[
          SizedBox(height: 1.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.primary.withAlpha(77),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 16,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    _getCertificateTypeDescription(_certificateType!),
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getCertificateTypeIcon(String type) {
    switch (type) {
      case 'agonistico':
        return 'sports';
      case 'di_base':
        return 'favorite';
      case 'contatto_pieno':
        return 'sports_martial_arts';
      default:
        return 'assignment';
    }
  }

  String _getCertificateTypeDescription(String type) {
    switch (type) {
      case 'agonistico':
        return 'Certificato per attività sportiva agonistica e competitiva';
      case 'di_base':
        return 'Certificato per attività sportiva non agonistica di base';
      case 'contatto_pieno':
        return 'Certificato per sport da combattimento e arti marziali con contatto pieno';
      default:
        return '';
    }
  }
}
