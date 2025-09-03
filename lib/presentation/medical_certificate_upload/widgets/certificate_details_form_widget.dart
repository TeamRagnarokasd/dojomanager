import 'package:flutter/material.dart';
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
  final _issueDateController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _doctorLicenseController = TextEditingController();
  final _medicalCenterController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _issueDate;
  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    _setupFormListeners();
  }

  @override
  void dispose() {
    _issueDateController.dispose();
    _expirationDateController.dispose();
    _doctorNameController.dispose();
    _doctorLicenseController.dispose();
    _medicalCenterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setupFormListeners() {
    _issueDateController.addListener(_notifyFormChange);
    _expirationDateController.addListener(_notifyFormChange);
    _doctorNameController.addListener(_notifyFormChange);
    _doctorLicenseController.addListener(_notifyFormChange);
    _medicalCenterController.addListener(_notifyFormChange);
    _notesController.addListener(_notifyFormChange);
  }

  void _notifyFormChange() {
    final formData = {
      'issueDate': _issueDate,
      'expirationDate': _expirationDate,
      'doctorName': _doctorNameController.text.trim(),
      'doctorLicense': _doctorLicenseController.text.trim(),
      'medicalCenter': _medicalCenterController.text.trim(),
      'notes': _notesController.text.trim(),
      'isValid': _isFormValid(),
    };
    widget.onFormChanged(formData);
  }

  bool _isFormValid() {
    return _issueDate != null &&
        _expirationDate != null &&
        _doctorNameController.text.trim().isNotEmpty &&
        _doctorLicenseController.text.trim().isNotEmpty &&
        _medicalCenterController.text.trim().isNotEmpty &&
        _expirationDate!.isAfter(_issueDate!) &&
        _expirationDate!.isAfter(DateTime.now());
  }

  Future<void> _selectDate(BuildContext context, bool isIssueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isIssueDate
          ? (_issueDate ?? DateTime.now().subtract(Duration(days: 30)))
          : (_expirationDate ?? DateTime.now().add(Duration(days: 365))),
      firstDate: isIssueDate
          ? DateTime.now().subtract(Duration(days: 365))
          : (_issueDate ?? DateTime.now()),
      lastDate: isIssueDate
          ? DateTime.now()
          : DateTime.now().add(Duration(days: 1095)), // 3 years
      locale: Locale('it', 'IT'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: AppTheme.lightTheme.colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _issueDate = picked;
          _issueDateController.text = _formatDate(picked);
          // Reset expiration date if it's before the new issue date
          if (_expirationDate != null && _expirationDate!.isBefore(picked)) {
            _expirationDate = null;
            _expirationDateController.clear();
          }
        } else {
          _expirationDate = picked;
          _expirationDateController.text = _formatDate(picked);
        }
      });
      _notifyFormChange();
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
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.3),
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
            _buildDoctorFields(),
            SizedBox(height: 3.h),
            _buildNotesField(),
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
                controller: _issueDateController,
                label: 'Data di Emissione *',
                hintText: 'GG/MM/AAAA',
                onTap: () => _selectDate(context, true),
                validator: (value) {
                  if (_issueDate == null) {
                    return 'Data richiesta';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: _buildDateField(
                controller: _expirationDateController,
                label: 'Data di Scadenza *',
                hintText: 'GG/MM/AAAA',
                onTap: () => _selectDate(context, false),
                validator: (value) {
                  if (_expirationDate == null) {
                    return 'Data richiesta';
                  }
                  if (_issueDate != null &&
                      _expirationDate!.isBefore(_issueDate!)) {
                    return 'Deve essere dopo l\'emissione';
                  }
                  if (_expirationDate!.isBefore(DateTime.now())) {
                    return 'Certificato scaduto';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        if (_expirationDate != null &&
            _expirationDate!.difference(DateTime.now()).inDays <= 30)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 2.h),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color:
                  AppTheme.lightTheme.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.error
                    .withValues(alpha: 0.3),
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
                    'Attenzione: Il certificato scade tra ${_expirationDate!.difference(DateTime.now()).inDays} giorni',
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
      readOnly: true,
      enabled: widget.isEnabled,
      onTap: widget.isEnabled ? onTap : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixIcon: CustomIconWidget(
          iconName: 'calendar_today',
          color: AppTheme.lightTheme.colorScheme.primary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDoctorFields() {
    return Column(
      children: [
        TextFormField(
          controller: _doctorNameController,
          enabled: widget.isEnabled,
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Nome del medico richiesto';
            }
            if (value.trim().length < 2) {
              return 'Nome troppo corto';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'Nome del Medico *',
            hintText: 'Dr. Mario Rossi',
            prefixIcon: CustomIconWidget(
              iconName: 'person',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        TextFormField(
          controller: _doctorLicenseController,
          enabled: widget.isEnabled,
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Numero di abilitazione richiesto';
            }
            if (value.trim().length < 3) {
              return 'Numero di abilitazione non valido';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'Numero di Abilitazione *',
            hintText: 'RM12345',
            prefixIcon: CustomIconWidget(
              iconName: 'badge',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 20,
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
            labelText: 'Centro Medico *',
            hintText: 'Ospedale San Giovanni',
            prefixIcon: CustomIconWidget(
              iconName: 'local_hospital',
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      enabled: widget.isEnabled,
      maxLines: 3,
      maxLength: 200,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'Note Aggiuntive',
        hintText: 'Eventuali note o osservazioni...',
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: CustomIconWidget(
            iconName: 'note',
            color: AppTheme.lightTheme.colorScheme.primary,
            size: 20,
          ),
        ),
        alignLabelWithHint: true,
      ),
    );
  }
}
