import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/emergency_contact_section.dart';
import './widgets/medical_certificate_section.dart';
import './widgets/personal_info_section.dart';
import './widgets/progress_indicator_widget.dart';
import './widgets/terms_acceptance_section.dart';

class StudentRegistration extends StatefulWidget {
  const StudentRegistration({super.key});

  @override
  State<StudentRegistration> createState() => _StudentRegistrationState();
}

class _StudentRegistrationState extends State<StudentRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _dataNascitaController = TextEditingController();

  // New mandatory controllers for Italian registration
  final _codiceFiscaleController = TextEditingController();
  final _residenzaIndirizzoController = TextEditingController();
  final _residenzaCittaController = TextEditingController();
  final _residenzaProvinciaController = TextEditingController();
  final _residenzaCAPController = TextEditingController();

  // Parent/guardian controllers (for minors)
  final _genitoreNomeController = TextEditingController();
  final _genitoreCognomeController = TextEditingController();
  final _genitoreCodiceFiscaleController = TextEditingController();
  final _genitoreEmailController = TextEditingController();
  final _genitoreTelefonoController = TextEditingController();
  final _genitoreRelationController = TextEditingController();

  // Form state
  String? _nomeError;
  String? _cognomeError;
  String? _emailError;
  String? _telefonoError;
  String? _dataNascitaError;

  // New form state for mandatory fields
  String? _codiceFiscaleError;
  String? _residenzaIndirizzoError;
  String? _residenzaCittaError;
  String? _residenzaProvinciaError;
  String? _residenzaCAPError;

  // Parent/guardian form state
  String? _genitoreNomeError;
  String? _genitoreCognomeError;
  String? _genitoreCodiceFiscaleError;
  String? _genitoreEmailError;
  String? _genitoreTelefonoError;
  String? _genitoreRelationError;

  bool _isMinor = false;

  List<Map<String, dynamic>> _emergencyContacts = [
    {'nome': '', 'telefono': ''}
  ];

  List<Map<String, dynamic>> _uploadedDocuments = [];
  bool _termsAccepted = false;
  bool _isLoading = false;

  // Progress tracking
  int _currentStep = 1;
  final int _totalSteps = 4;
  final List<String> _stepLabels = [
    'Info Personali',
    'Contatti Emergenza',
    'Certificato Medico',
    'Termini'
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _scheduleReminderCheck();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _dataNascitaController.dispose();

    _codiceFiscaleController.dispose();
    _residenzaIndirizzoController.dispose();
    _residenzaCittaController.dispose();
    _residenzaProvinciaController.dispose();
    _residenzaCAPController.dispose();

    _genitoreNomeController.dispose();
    _genitoreCognomeController.dispose();
    _genitoreCodiceFiscaleController.dispose();
    _genitoreEmailController.dispose();
    _genitoreTelefonoController.dispose();
    _genitoreRelationController.dispose();

    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(4.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProgressIndicatorWidget(
                        currentStep: _currentStep,
                        totalSteps: _totalSteps,
                        stepLabels: _stepLabels,
                      ),
                      SizedBox(height: 3.h),
                      PersonalInfoSection(
                        nomeController: _nomeController,
                        cognomeController: _cognomeController,
                        emailController: _emailController,
                        telefonoController: _telefonoController,
                        dataNascitaController: _dataNascitaController,
                        codiceFiscaleController: _codiceFiscaleController,
                        residenzaIndirizzoController:
                            _residenzaIndirizzoController,
                        residenzaCittaController: _residenzaCittaController,
                        residenzaProvinciaController:
                            _residenzaProvinciaController,
                        residenzaCAPController: _residenzaCAPController,
                        genitoreNomeController: _genitoreNomeController,
                        genitoreCognomeController: _genitoreCognomeController,
                        genitoreCodiceFiscaleController:
                            _genitoreCodiceFiscaleController,
                        genitoreEmailController: _genitoreEmailController,
                        genitoreTelefonoController: _genitoreTelefonoController,
                        genitoreRelationController: _genitoreRelationController,
                        onDateTap: _selectBirthDate,
                        nomeError: _nomeError,
                        cognomeError: _cognomeError,
                        emailError: _emailError,
                        telefonoError: _telefonoError,
                        dataNascitaError: _dataNascitaError,
                        codiceFiscaleError: _codiceFiscaleError,
                        residenzaIndirizzoError: _residenzaIndirizzoError,
                        residenzaCittaError: _residenzaCittaError,
                        residenzaProvinciaError: _residenzaProvinciaError,
                        residenzaCAPError: _residenzaCAPError,
                        genitoreNomeError: _genitoreNomeError,
                        genitoreCognomeError: _genitoreCognomeError,
                        genitoreCodiceFiscaleError: _genitoreCodiceFiscaleError,
                        genitoreEmailError: _genitoreEmailError,
                        genitoreTelefonoError: _genitoreTelefonoError,
                        genitoreRelationError: _genitoreRelationError,
                        isMinor: _isMinor,
                      ),
                      SizedBox(height: 3.h),
                      EmergencyContactSection(
                        emergencyContacts: _emergencyContacts,
                        onRemoveContact: _removeEmergencyContact,
                        onAddContact: _addEmergencyContact,
                        onContactChanged: _updateEmergencyContact,
                      ),
                      SizedBox(height: 3.h),
                      MedicalCertificateSection(
                        uploadedDocuments: _uploadedDocuments,
                        onDocumentAdded: _addDocument,
                        onDocumentRemoved: _removeDocument,
                      ),
                      SizedBox(height: 3.h),
                      TermsAcceptanceSection(
                        isAccepted: _termsAccepted,
                        onChanged: _updateTermsAcceptance,
                      ),
                      SizedBox(height: 10.h), // Space for sticky button
                    ],
                  ),
                ),
              ),
            ),
            _buildStickyButton(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('Registrazione Studente'),
      leading: IconButton(
        icon: CustomIconWidget(
          iconName: 'arrow_back',
          color: AppTheme.lightTheme.colorScheme.onSurface,
          size: 24,
        ),
        onPressed: _handleBackNavigation,
      ),
      actions: [
        IconButton(
          icon: CustomIconWidget(
            iconName: 'save',
            color: AppTheme.lightTheme.colorScheme.primary,
            size: 24,
          ),
          onPressed: _saveFormData,
          tooltip: 'Salva bozza',
        ),
      ],
    );
  }

  Widget _buildStickyButton() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.lightTheme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isFormValid() && !_isLoading ? _submitRegistration : null,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.lightTheme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text('Registrazione in corso...'),
                ],
              )
            : Text(
                'Registra Account',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
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
      // Calculate if person is minor (under 18)
      final age = DateTime.now().difference(picked).inDays ~/ 365;
      final isMinor = age < 18;

      setState(() {
        _dataNascitaController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
        _dataNascitaError = null;
        _isMinor = isMinor;

        // Clear parent data if user becomes adult
        if (!isMinor) {
          _genitoreNomeController.clear();
          _genitoreCognomeController.clear();
          _genitoreCodiceFiscaleController.clear();
          _genitoreEmailController.clear();
          _genitoreTelefonoController.clear();
          _genitoreRelationController.clear();
        }
        _updateProgress();
      });
      _saveFormData();
    }
  }

  void _addEmergencyContact() {
    setState(() {
      _emergencyContacts.add({'nome': '', 'telefono': ''});
      _updateProgress();
    });
    _saveFormData();
  }

  void _removeEmergencyContact(int index) {
    if (_emergencyContacts.length > 1) {
      setState(() {
        _emergencyContacts.removeAt(index);
        _updateProgress();
      });
      _saveFormData();
    }
  }

  void _updateEmergencyContact(int index, String field, String value) {
    setState(() {
      _emergencyContacts[index][field] = value;
      _updateProgress();
    });
    _saveFormData();
  }

  void _addDocument(Map<String, dynamic> document) {
    setState(() {
      _uploadedDocuments.add(document);
      _updateProgress();
    });
    _saveFormData();
  }

  void _removeDocument(int index) {
    setState(() {
      _uploadedDocuments.removeAt(index);
      _updateProgress();
    });
    _saveFormData();
  }

  void _updateTermsAcceptance(bool accepted) {
    setState(() {
      _termsAccepted = accepted;
      _updateProgress();
    });
    _saveFormData();
  }

  void _updateProgress() {
    int step = 1;

    // Step 1: Personal Info (including new mandatory fields)
    if (_isPersonalInfoComplete()) {
      step = 2;
    }

    // Step 2: Emergency Contacts
    if (step >= 2 && _isEmergencyContactsComplete()) {
      step = 3;
    }

    // Step 3: Medical Certificate (now optional, always allow to proceed)
    if (step >= 3) {
      step = 4;
    }

    // Step 4: Terms
    if (step >= 4 && _termsAccepted) {
      step = 4; // Completed
    }

    setState(() {
      _currentStep = step;
    });
  }

  bool _isPersonalInfoComplete() {
    final basicInfoComplete = _nomeController.text.isNotEmpty &&
        _cognomeController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _telefonoController.text.isNotEmpty &&
        _dataNascitaController.text.isNotEmpty &&
        _codiceFiscaleController.text.isNotEmpty &&
        _residenzaIndirizzoController.text.isNotEmpty &&
        _residenzaCittaController.text.isNotEmpty &&
        _residenzaProvinciaController.text.isNotEmpty &&
        _residenzaCAPController.text.isNotEmpty;

    // Check parent info if minor
    if (_isMinor) {
      final parentInfoComplete = _genitoreNomeController.text.isNotEmpty &&
          _genitoreCognomeController.text.isNotEmpty &&
          _genitoreCodiceFiscaleController.text.isNotEmpty &&
          _genitoreEmailController.text.isNotEmpty &&
          _genitoreTelefonoController.text.isNotEmpty &&
          _genitoreRelationController.text.isNotEmpty;

      return basicInfoComplete && parentInfoComplete;
    }

    return basicInfoComplete;
  }

  bool _isEmergencyContactsComplete() {
    return _emergencyContacts.any((contact) =>
        (contact['nome'] as String).isNotEmpty &&
        (contact['telefono'] as String).isNotEmpty);
  }

  bool _isFormValid() {
    return _isPersonalInfoComplete() &&
        _isEmergencyContactsComplete() &&
        _termsAccepted &&
        _validateAllFields();
  }

  bool _validateAllFields() {
    bool isValid = true;

    // Validate nome
    if (_nomeController.text.isEmpty) {
      _nomeError = 'Il nome è obbligatorio';
      isValid = false;
    } else if (_nomeController.text.length < 2) {
      _nomeError = 'Il nome deve contenere almeno 2 caratteri';
      isValid = false;
    } else {
      _nomeError = null;
    }

    // Validate cognome
    if (_cognomeController.text.isEmpty) {
      _cognomeError = 'Il cognome è obbligatorio';
      isValid = false;
    } else if (_cognomeController.text.length < 2) {
      _cognomeError = 'Il cognome deve contenere almeno 2 caratteri';
      isValid = false;
    } else {
      _cognomeError = null;
    }

    // Validate email
    if (_emailController.text.isEmpty) {
      _emailError = 'L\'email è obbligatoria';
      isValid = false;
    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
        .hasMatch(_emailController.text)) {
      _emailError = 'Inserisci un\'email valida';
      isValid = false;
    } else {
      _emailError = null;
    }

    // Validate telefono
    if (_telefonoController.text.isEmpty) {
      _telefonoError = 'Il telefono è obbligatorio';
      isValid = false;
    } else if (!RegExp(r'^[\+]?[0-9\s\-]{8,15}$')
        .hasMatch(_telefonoController.text)) {
      _telefonoError = 'Inserisci un numero di telefono valido';
      isValid = false;
    } else {
      _telefonoError = null;
    }

    // Validate data nascita
    if (_dataNascitaController.text.isEmpty) {
      _dataNascitaError = 'La data di nascita è obbligatoria';
      isValid = false;
    } else {
      _dataNascitaError = null;
    }

    // New mandatory field validations
    // Validate codice fiscale
    if (_codiceFiscaleController.text.isEmpty) {
      _codiceFiscaleError = 'Il codice fiscale è obbligatorio';
      isValid = false;
    } else if (!RegExp(r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$')
        .hasMatch(_codiceFiscaleController.text.toUpperCase())) {
      _codiceFiscaleError = 'Inserisci un codice fiscale valido';
      isValid = false;
    } else {
      _codiceFiscaleError = null;
    }

    // Validate residenza indirizzo
    if (_residenzaIndirizzoController.text.isEmpty) {
      _residenzaIndirizzoError = 'L\'indirizzo di residenza è obbligatorio';
      isValid = false;
    } else if (_residenzaIndirizzoController.text.length < 5) {
      _residenzaIndirizzoError =
          'L\'indirizzo deve contenere almeno 5 caratteri';
      isValid = false;
    } else {
      _residenzaIndirizzoError = null;
    }

    // Validate residenza città
    if (_residenzaCittaController.text.isEmpty) {
      _residenzaCittaError = 'La città è obbligatoria';
      isValid = false;
    } else if (_residenzaCittaController.text.length < 2) {
      _residenzaCittaError = 'La città deve contenere almeno 2 caratteri';
      isValid = false;
    } else {
      _residenzaCittaError = null;
    }

    // Validate residenza provincia
    if (_residenzaProvinciaController.text.isEmpty) {
      _residenzaProvinciaError = 'La provincia è obbligatoria';
      isValid = false;
    } else if (_residenzaProvinciaController.text.length != 2) {
      _residenzaProvinciaError =
          'Inserisci la sigla della provincia (es. MI, RM)';
      isValid = false;
    } else {
      _residenzaProvinciaError = null;
    }

    // Validate CAP
    if (_residenzaCAPController.text.isEmpty) {
      _residenzaCAPError = 'Il CAP è obbligatorio';
      isValid = false;
    } else if (!RegExp(r'^[0-9]{5}$').hasMatch(_residenzaCAPController.text)) {
      _residenzaCAPError = 'Inserisci un CAP valido (5 cifre)';
      isValid = false;
    } else {
      _residenzaCAPError = null;
    }

    // Validate parent/guardian info if minor
    if (_isMinor) {
      // Validate genitore nome
      if (_genitoreNomeController.text.isEmpty) {
        _genitoreNomeError = 'Il nome del genitore/tutore è obbligatorio';
        isValid = false;
      } else if (_genitoreNomeController.text.length < 2) {
        _genitoreNomeError = 'Il nome deve contenere almeno 2 caratteri';
        isValid = false;
      } else {
        _genitoreNomeError = null;
      }

      // Validate genitore cognome
      if (_genitoreCognomeController.text.isEmpty) {
        _genitoreCognomeError = 'Il cognome del genitore/tutore è obbligatorio';
        isValid = false;
      } else if (_genitoreCognomeController.text.length < 2) {
        _genitoreCognomeError = 'Il cognome deve contenere almeno 2 caratteri';
        isValid = false;
      } else {
        _genitoreCognomeError = null;
      }

      // Validate genitore codice fiscale
      if (_genitoreCodiceFiscaleController.text.isEmpty) {
        _genitoreCodiceFiscaleError =
            'Il codice fiscale del genitore/tutore è obbligatorio';
        isValid = false;
      } else if (!RegExp(r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$')
          .hasMatch(_genitoreCodiceFiscaleController.text.toUpperCase())) {
        _genitoreCodiceFiscaleError = 'Inserisci un codice fiscale valido';
        isValid = false;
      } else {
        _genitoreCodiceFiscaleError = null;
      }

      // Validate genitore email
      if (_genitoreEmailController.text.isEmpty) {
        _genitoreEmailError = 'L\'email del genitore/tutore è obbligatoria';
        isValid = false;
      } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
          .hasMatch(_genitoreEmailController.text)) {
        _genitoreEmailError = 'Inserisci un\'email valida';
        isValid = false;
      } else {
        _genitoreEmailError = null;
      }

      // Validate genitore telefono
      if (_genitoreTelefonoController.text.isEmpty) {
        _genitoreTelefonoError =
            'Il telefono del genitore/tutore è obbligatorio';
        isValid = false;
      } else if (!RegExp(r'^[\+]?[0-9\s\-]{8,15}$')
          .hasMatch(_genitoreTelefonoController.text)) {
        _genitoreTelefonoError = 'Inserisci un numero di telefono valido';
        isValid = false;
      } else {
        _genitoreTelefonoError = null;
      }

      // Validate genitore relation
      if (_genitoreRelationController.text.isEmpty) {
        _genitoreRelationError = 'Il grado di parentela è obbligatorio';
        isValid = false;
      } else {
        _genitoreRelationError = null;
      }
    }

    return isValid;
  }

  Future<void> _submitRegistration() async {
    if (!_validateAllFields()) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Set up medical certificate reminder if no document uploaded
      if (_uploadedDocuments.isEmpty) {
        await _scheduleInitialMedicalCertificateReminder();
      }

      // Clear saved data on successful registration
      await _clearSavedData();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showGeneralErrorDialog('Errore durante la registrazione. Riprova più tardi.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGeneralErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'error',
              color: AppTheme.lightTheme.colorScheme.error,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text('Errore'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'check_circle',
              color: AppTheme.lightTheme.colorScheme.tertiary,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text('Registrazione Completata'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('La tua registrazione è stata completata con successo!'),
            SizedBox(height: 2.h),
            Text(
              'Ti abbiamo inviato un\'email di verifica all\'indirizzo:',
              style: AppTheme.lightTheme.textTheme.bodySmall,
            ),
            SizedBox(height: 1.h),
            Text(
              _emailController.text,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
            if (_uploadedDocuments.isEmpty) ...[
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.tertiary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'schedule',
                      color: AppTheme.lightTheme.colorScheme.tertiary,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Ricorda: hai 30 giorni per caricare il certificato medico.',
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login-screen');
            },
            child: Text('Vai al Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _scheduleInitialMedicalCertificateReminder() async {
    // In a real app, this would schedule push notifications or create database entries
    // for reminder system. For now, we'll use shared preferences to track the deadline.
    // Note: Import 'package:shared_preferences/shared_preferences.dart' for this to work
    // For now, we'll simulate the functionality without the actual SharedPreferences
    final registrationDate = DateTime.now();
    final deadlineDate = registrationDate.add(const Duration(days: 30));

    // In a real implementation, you would:
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('medical_cert_registration_date', registrationDate.toIso8601String());
    // await prefs.setString('medical_cert_deadline', deadlineDate.toIso8601String());
    // await prefs.setBool('medical_cert_uploaded', false);
    // await prefs.setString('user_email', _emailController.text);
    // await prefs.setString('next_reminder_date', registrationDate.add(const Duration(days: 7)).toIso8601String());
  }

  void _scheduleReminderCheck() {
    // Check every time the app starts if user needs reminder
    _checkMedicalCertificateReminder();
  }

  Future<void> _checkMedicalCertificateReminder() async {
    // Note: Import 'package:shared_preferences/shared_preferences.dart' for this to work
    // For now, we'll simulate the functionality without the actual SharedPreferences
    // In a real implementation, you would:
    // final prefs = await SharedPreferences.getInstance();
    // final medicalCertUploaded = prefs.getBool('medical_cert_uploaded') ?? true;
    // ... rest of the logic
    
    // Simplified version without SharedPreferences dependency
    return;
  }

  void _handleBackNavigation() {
    if (_hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Modifiche non salvate'),
          content:
              Text('Hai modifiche non salvate. Vuoi salvare prima di uscire?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('Esci senza salvare'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveFormData();
                Navigator.pop(context);
              },
              child: Text('Salva ed esci'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Continua'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool _hasUnsavedChanges() {
    // Simple check - in a real app, you'd compare with last saved state
    return _nomeController.text.isNotEmpty ||
        _cognomeController.text.isNotEmpty ||
        _emailController.text.isNotEmpty ||
        _telefonoController.text.isNotEmpty ||
        _dataNascitaController.text.isNotEmpty ||
        _codiceFiscaleController.text.isNotEmpty ||
        _residenzaIndirizzoController.text.isNotEmpty ||
        _residenzaCittaController.text.isNotEmpty ||
        _residenzaProvinciaController.text.isNotEmpty ||
        _residenzaCAPController.text.isNotEmpty ||
        _emergencyContacts.any((contact) =>
            (contact['nome'] as String).isNotEmpty ||
            (contact['telefono'] as String).isNotEmpty) ||
        _uploadedDocuments.isNotEmpty ||
        _termsAccepted;
  }

  Future<void> _saveFormData() async {
    // In a real app, save to local storage or cache
    // For now, just show a brief confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dati salvati automaticamente'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadSavedData() async {
    // In a real app, load from local storage
    // For demo purposes, we'll leave this empty
  }

  Future<void> _clearSavedData() async {
    // In a real app, clear saved form data
    // For demo purposes, we'll leave this empty
  }
}