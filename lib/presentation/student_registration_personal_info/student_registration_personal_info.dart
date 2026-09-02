import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/registration_data_manager.dart';
import '../../services/student_registration_service.dart';
import './widgets/progress_indicator_widget.dart';

/// Step 1 of 4: Personal Information
/// Collects nome, cognome, email, phone, birth date, birth place, tax code, address
/// For users aged 14-17, also collects parent/guardian data.
class StudentRegistrationPersonalInfo extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const StudentRegistrationPersonalInfo({super.key, this.existingData});

  @override
  State<StudentRegistrationPersonalInfo> createState() =>
      _StudentRegistrationPersonalInfoState();
}

class _StudentRegistrationPersonalInfoState
    extends State<StudentRegistrationPersonalInfo> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _taxCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _capController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Parent/Guardian controllers (for 14-17 minor flow)
  final _parentNameController = TextEditingController();
  final _parentSurnameController = TextEditingController();
  final _parentCFController = TextEditingController();
  final _parentDocTypeController = TextEditingController();
  final _parentDocNumberController = TextEditingController();

  DateTime? _selectedBirthDate;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isMinor1417 = false;

  static const List<String> _documentTypes = [
    'Carta d\'Identità',
    'Passaporto',
    'Patente di Guida',
    'Permesso di Soggiorno',
  ];
  String? _selectedDocType;

  @override
  void initState() {
    super.initState();
    RegistrationDataManager.reset();
    _loadExistingData();
  }

  void _loadExistingData() {
    if (RegistrationDataManager.hasPersonalInfo()) {
      _nomeController.text = RegistrationDataManager.nome ?? '';
      _cognomeController.text = RegistrationDataManager.cognome ?? '';
      _emailController.text = RegistrationDataManager.email ?? '';
      _phoneController.text = RegistrationDataManager.telefono ?? '';
      _birthDateController.text =
          RegistrationDataManager.dataNascitaDisplay ?? '';
      _birthPlaceController.text = RegistrationDataManager.luogoNascita ?? '';
      _taxCodeController.text = RegistrationDataManager.codiceFiscale ?? '';
      _addressController.text =
          RegistrationDataManager.indirizzoResidenza ?? '';
      _cityController.text = RegistrationDataManager.citta ?? '';
      _provinceController.text = RegistrationDataManager.provincia ?? '';
      _capController.text = RegistrationDataManager.cap ?? '';
      _passwordController.text = RegistrationDataManager.password ?? '';
      _confirmPasswordController.text = RegistrationDataManager.password ?? '';

      if (RegistrationDataManager.dataNascita != null) {
        _selectedBirthDate = RegistrationDataManager.dataNascita;
        _isMinor1417 = RegistrationDataManager.isMinor1417();
      }

      // Restore parent data if present
      _parentNameController.text =
          RegistrationDataManager.parentGuardianName ?? '';
      _parentSurnameController.text =
          RegistrationDataManager.parentGuardianSurname ?? '';
      _parentCFController.text =
          RegistrationDataManager.parentGuardianCodiceFiscale ?? '';
      _parentDocNumberController.text =
          RegistrationDataManager.parentGuardianDocumentNumber ?? '';
      if (RegistrationDataManager.parentGuardianDocumentType != null) {
        _selectedDocType = RegistrationDataManager.parentGuardianDocumentType;
        _parentDocTypeController.text = _selectedDocType ?? '';
      }
    }
  }

  bool _isFormValid() {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    final baseValid = _nomeController.text.trim().isNotEmpty &&
        _cognomeController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        emailRegex.hasMatch(_emailController.text.trim()) &&
        _phoneController.text.trim().isNotEmpty &&
        _birthDateController.text.isNotEmpty &&
        _birthPlaceController.text.trim().isNotEmpty &&
        _taxCodeController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty &&
        _cityController.text.trim().isNotEmpty &&
        _provinceController.text.trim().isNotEmpty &&
        _capController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text &&
        _passwordController.text.length >= 8 &&
        StudentRegistrationService.validateCodiceFiscale(
            _taxCodeController.text.trim()) &&
        StudentRegistrationService.validateCAP(_capController.text.trim()) &&
        StudentRegistrationService.validateProvince(
            _provinceController.text.trim().toUpperCase());

    if (!baseValid) return false;

    // Additional validation for 14-17 minor
    if (_isMinor1417) {
      return _parentNameController.text.trim().isNotEmpty &&
          _parentSurnameController.text.trim().isNotEmpty &&
          _parentCFController.text.trim().length == 16 &&
          _selectedDocType != null &&
          _parentDocNumberController.text.trim().isNotEmpty;
    }

    return true;
  }

  void _proceedToNextStep() {
    if (_formKey.currentState!.validate()) {
      _saveToDataManager();
      Navigator.pushNamed(
        context,
        AppRoutes.studentRegistrationEmergencyContacts,
      );
    }
  }

  void _saveToDataManager() {
    RegistrationDataManager.nome = _nomeController.text.trim();
    RegistrationDataManager.cognome = _cognomeController.text.trim();
    RegistrationDataManager.email = _emailController.text.trim().toLowerCase();
    RegistrationDataManager.password = _passwordController.text;
    RegistrationDataManager.telefono = _phoneController.text.trim();
    RegistrationDataManager.dataNascita = _selectedBirthDate;
    RegistrationDataManager.dataNascitaDisplay = _birthDateController.text;
    RegistrationDataManager.luogoNascita = _birthPlaceController.text.trim();
    RegistrationDataManager.codiceFiscale =
        _taxCodeController.text.trim().toUpperCase();
    RegistrationDataManager.indirizzoResidenza = _addressController.text.trim();
    RegistrationDataManager.citta = _cityController.text.trim();
    RegistrationDataManager.provincia =
        _provinceController.text.trim().toUpperCase();
    RegistrationDataManager.cap = _capController.text.trim();

    // Save parent/guardian data for 14-17 minor
    if (_isMinor1417) {
      RegistrationDataManager.parentGuardianName =
          _parentNameController.text.trim();
      RegistrationDataManager.parentGuardianSurname =
          _parentSurnameController.text.trim();
      RegistrationDataManager.parentGuardianCodiceFiscale =
          _parentCFController.text.trim().toUpperCase();
      RegistrationDataManager.parentGuardianDocumentType = _selectedDocType;
      RegistrationDataManager.parentGuardianDocumentNumber =
          _parentDocNumberController.text.trim();
    } else {
      // Clear parent data if not in 14-17 range
      RegistrationDataManager.parentGuardianName = null;
      RegistrationDataManager.parentGuardianSurname = null;
      RegistrationDataManager.parentGuardianCodiceFiscale = null;
      RegistrationDataManager.parentGuardianDocumentType = null;
      RegistrationDataManager.parentGuardianDocumentNumber = null;
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFFF0000),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';

        // Detect 14-17 age range
        final today = DateTime.now();
        int age = today.year - picked.year;
        if (today.month < picked.month ||
            (today.month == picked.month && today.day < picked.day)) {
          age--;
        }
        _isMinor1417 = age >= 14 && age < 18;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _birthPlaceController.dispose();
    _taxCodeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _capController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _parentNameController.dispose();
    _parentSurnameController.dispose();
    _parentCFController.dispose();
    _parentDocTypeController.dispose();
    _parentDocNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'registration.title'.tr(),
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          RegistrationProgressIndicator(
            currentStep: 1,
            totalSteps: 4,
            stepLabels: [
              'registration.personal_info'.tr(),
              'registration.emergency_contacts'.tr(),
              'registration.medical_certificate'.tr(),
              'registration.step_terms'.tr(),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'registration.personal_info_section'.tr(),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    _buildTextField(
                      controller: _nomeController,
                      label: 'Nome *',
                      hint: 'Inserisci il tuo nome',
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true)
                          return 'Campo obbligatorio';
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _cognomeController,
                      label: 'Cognome *',
                      hint: 'Inserisci il tuo cognome',
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true)
                          return 'Campo obbligatorio';
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email *',
                      hint: 'esempio@email.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true)
                          return 'Campo obbligatorio';
                        final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value!.trim()))
                          return 'Formato email non valido';
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Telefono *',
                      hint: '+39 123 456 7890',
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true)
                          return 'Campo obbligatorio';
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _birthDateController,
                      label: 'Data di Nascita *',
                      hint: 'GG/MM/AAAA',
                      readOnly: true,
                      onTap: _selectBirthDate,
                      suffixIcon: const Icon(Icons.calendar_today,
                          color: Color(0xFFFF0000)),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                        return null;
                      },
                    ),
                    // Age notice for 14-17
                    if (_isMinor1417) ...[
                      SizedBox(height: 1.5.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 3.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8C00).withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFF8C00), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Color(0xFFFF8C00), size: 20),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                'Hai tra i 14 e i 17 anni: è richiesta la compilazione dei dati del genitore/tutore legale.',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFFFF8C00),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _birthPlaceController,
                      label: 'Luogo di Nascita *',
                      hint: 'Città di nascita',
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true)
                          return 'Campo obbligatorio';
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _taxCodeController,
                      label: 'Codice Fiscale *',
                      hint: 'RSSMRA85M01H501Z',
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true)
                          return 'Campo obbligatorio';
                        if (!StudentRegistrationService.validateCodiceFiscale(
                            value!.trim())) {
                          return 'Codice fiscale non valido (16 caratteri)';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Indirizzo Residenza *',
                      hint: 'Via Roma 123',
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true)
                          return 'Campo obbligatorio';
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'Città *',
                            hint: 'Milano',
                            validator: (value) {
                              if (value?.trim().isEmpty ?? true)
                                return 'Obbligatorio';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          flex: 1,
                          child: _buildTextField(
                            controller: _provinceController,
                            label: 'Prov. *',
                            hint: 'MI',
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) {
                              if (value?.trim().isEmpty ?? true)
                                return 'Obbligatorio';
                              if (!StudentRegistrationService.validateProvince(
                                  value!.trim().toUpperCase())) {
                                return 'Non valida';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          flex: 1,
                          child: _buildTextField(
                            controller: _capController,
                            label: 'CAP *',
                            hint: '20100',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.trim().isEmpty ?? true)
                                return 'Obbligatorio';
                              if (!StudentRegistrationService.validateCAP(
                                  value!.trim())) {
                                return 'Non valido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password *',
                      hint: 'Inserisci la password',
                      obscureText: !_passwordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: const Color(0xFFFF0000),
                        ),
                        onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                        if (value!.length < 8) return 'Minimo 8 caratteri';
                        return null;
                      },
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Conferma Password *',
                      hint: 'Conferma la password',
                      obscureText: !_confirmPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: const Color(0xFFFF0000),
                        ),
                        onPressed: () => setState(() =>
                            _confirmPasswordVisible = !_confirmPasswordVisible),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Campo obbligatorio';
                        if (value != _passwordController.text)
                          return 'Le password non corrispondono';
                        return null;
                      },
                    ),

                    // ── Parent/Guardian section (only for 14-17) ──
                    if (_isMinor1417) ...[
                      SizedBox(height: 3.h),
                      _buildSectionHeader(
                        icon: Icons.family_restroom,
                        title: 'Dati Genitore / Tutore Legale',
                        subtitle:
                            'Obbligatori per i minori di età compresa tra 14 e 17 anni',
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _parentNameController,
                              label: 'Nome Genitore *',
                              hint: 'Mario',
                              validator: (value) {
                                if (_isMinor1417 &&
                                    (value?.trim().isEmpty ?? true))
                                  return 'Campo obbligatorio';
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: _buildTextField(
                              controller: _parentSurnameController,
                              label: 'Cognome Genitore *',
                              hint: 'Rossi',
                              validator: (value) {
                                if (_isMinor1417 &&
                                    (value?.trim().isEmpty ?? true))
                                  return 'Campo obbligatorio';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      _buildTextField(
                        controller: _parentCFController,
                        label: 'Codice Fiscale Genitore *',
                        hint: 'RSSMRA70M01H501Z',
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (_isMinor1417) {
                            if (value?.trim().isEmpty ?? true)
                              return 'Campo obbligatorio';
                            if (value!.trim().length != 16)
                              return 'Codice fiscale non valido (16 caratteri)';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 2.h),
                      _buildDocumentTypeDropdown(),
                      SizedBox(height: 2.h),
                      _buildTextField(
                        controller: _parentDocNumberController,
                        label: 'Numero Documento Genitore *',
                        hint: 'Es. CA12345AB',
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (_isMinor1417 && (value?.trim().isEmpty ?? true))
                            return 'Campo obbligatorio';
                          return null;
                        },
                      ),
                    ],

                    SizedBox(height: 6.h),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF404040),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 15,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isFormValid() ? _proceedToNextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    disabledBackgroundColor: const Color(0xFF404040),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: _isFormValid() ? 4 : 0,
                    shadowColor: _isFormValid()
                        ? const Color(0xFFFF0000).withAlpha(102)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Avanti',
                        style: TextStyle(
                          color: _isFormValid()
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.arrow_forward,
                        color: _isFormValid()
                            ? Colors.white
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C00).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8C00).withAlpha(100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFF8C00), size: 24),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo Documento Genitore *',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 1.h),
        DropdownButtonFormField<String>(
          initialValue: _selectedDocType,
          dropdownColor: const Color(0xFF2A2A2A),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Seleziona tipo documento',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF0000), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          ),
          items: _documentTypes
              .map((type) => DropdownMenuItem(
                    value: type,
                    child:
                        Text(type, style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedDocType = value;
              _parentDocTypeController.text = value ?? '';
            });
          },
          validator: (value) {
            if (_isMinor1417 && (value == null || value.isEmpty))
              return 'Campo obbligatorio';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
          textCapitalization: textCapitalization,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF0000), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _collectData() {
    return {
      'nome': _nomeController.text.trim(),
      'cognome': _cognomeController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      'telefono': _phoneController.text.trim(),
      'dataNascita': _selectedBirthDate,
      'dataNascitaDisplay': _birthDateController.text,
      'luogoNascita': _birthPlaceController.text.trim(),
      'codiceFiscale': _taxCodeController.text.trim().toUpperCase(),
      'indirizzoResidenza': _addressController.text.trim(),
      'citta': _cityController.text.trim(),
      'provincia': _provinceController.text.trim().toUpperCase(),
      'cap': _capController.text.trim(),
      'password': _passwordController.text,
      'confirmPassword': _confirmPasswordController.text,
    };
  }
}
