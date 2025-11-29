import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/student_registration_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_icon_widget.dart';
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
  final _personalInfoFormKey = GlobalKey<FormState>();
  final _emergencyContactFormKey = GlobalKey<FormState>();
  final _termsFormKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _isSubmitting = false;

  // Personal Info Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _capController = TextEditingController();
  // 🎯 FIX 2: ADD TAX CODE CONTROLLER
  final _taxCodeController = TextEditingController();
  final _scrollController = ScrollController();

  // New mandatory controllers for Italian registration
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
  String? _passwordError;
  String? _confirmPasswordError;
  String? _codiceFiscaleError;

  // New form state for mandatory fields
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

  DateTime? _selectedBirthDate;
  bool _isMinor = false;

  List<Map<String, dynamic>> _emergencyContacts = [
    {'nome': '', 'telefono': ''},
  ];

  List<Map<String, dynamic>> _uploadedDocuments = [];
  bool _termsAccepted = false;
  bool _isLoading = false;

  // Progress tracking
  final int _totalSteps = 4;
  final List<String> _stepLabels = [
    'Info Personali',
    'Contatti Emergenza',
    'Certificato Medico',
    'Termini',
  ];

  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationState();
    _loadSavedData();
    _scheduleReminderCheck();
  }

  /// Check if user is already authenticated and handle accordingly
  Future<void> _checkAuthenticationState() async {
    try {
      final authService = AuthService.instance;

      if (authService.isAuthenticated) {
        final user = authService.currentUser;
        if (user != null) {
          print('⚠️ User is already authenticated: ${user.email}');

          // Show dialog to inform user they're already signed in
          if (mounted) {
            _showAlreadyAuthenticatedDialog(user.email ?? '');
          }
        }
      }
    } catch (e) {
      print('Error checking authentication state: $e');
    }
  }

  /// Force sign out any existing user before registration
  Future<void> _ensureUserSignedOut() async {
    try {
      final authService = AuthService.instance;
      if (authService.isAuthenticated) {
        print('🔓 Signing out existing user before registration');
        await StudentRegistrationService.forceSignOut();

        // Wait a moment for the sign out to complete
        await Future.delayed(Duration(milliseconds: 1000));

        // Double check
        if (authService.isAuthenticated) {
          print('⚠️ User still authenticated, trying again...');
          await StudentRegistrationService.forceSignOut();
          await Future.delayed(Duration(milliseconds: 1000));
        }
      }
    } catch (e) {
      print('Error signing out user: $e');
    }
  }

  /// Show dialog when user is already authenticated
  void _showAlreadyAuthenticatedDialog(String userEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 24,
                ),
                SizedBox(width: 2.w),
                Text('Utente già autenticato'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sei già connesso con l\'account:',
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.lightTheme.colorScheme.primary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'email',
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          userEmail,
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.lightTheme.colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Per registrare un nuovo account, devi prima disconnetterti.',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to previous screen
                },
                child: Text('Indietro'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _logoutAndContinue();
                },
                child: Text('Disconnetti e Continua'),
              ),
            ],
          ),
    );
  }

  /// Logout current user and continue with registration
  Future<void> _logoutAndContinue() async {
    try {
      setState(() => _isLoading = true);

      // Sign out the current user
      await StudentRegistrationService.forceSignOut();

      // Clear any cached data
      await _clearSavedData();

      // Clear authentication state
      await _clearAuthenticationState();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Disconnesso con successo. Puoi ora procedere con la registrazione.',
            ),
            backgroundColor: AppTheme.lightTheme.colorScheme.tertiary,
            duration: Duration(seconds: 3),
          ),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showGeneralErrorDialog(
          'Errore durante la disconnessione: ${e.toString()}',
        );
      }
    }
  }

  /// Clear any cached authentication state
  Future<void> _clearAuthenticationState() async {
    try {
      // Clear any shared preferences or local storage related to auth
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session');
      await prefs.remove('auth_token');
      await prefs.remove('user_data');

      // Force a small delay to ensure state is cleared
      await Future.delayed(Duration(milliseconds: 300));
    } catch (e) {
      print('Error clearing authentication state: $e');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _birthPlaceController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _capController.dispose();
    _taxCodeController.dispose(); // Dispose tax code controller
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
                child: Column(
                  children: [
                    ProgressIndicatorWidget(
                      currentStep: _currentStep,
                      totalSteps: 4,
                      stepLabels: _stepLabels,
                    ),
                    SizedBox(height: 3.h),
                    if (_currentStep == 0)
                      PersonalInfoSection(
                        fullNameController: _fullNameController,
                        emailController: _emailController,
                        phoneController: _phoneController,
                        birthDateController: _birthDateController,
                        birthPlaceController: _birthPlaceController,
                        addressController: _addressController,
                        cityController: _cityController,
                        provinceController: _provinceController,
                        capController: _capController,
                        taxCodeController:
                            _taxCodeController, // Pass tax code controller
                        formKey: _personalInfoFormKey,
                        onNext: _nextStep,
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
          onPressed: _saveFormDataWithConfirmation,
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
            color: AppTheme.lightTheme.colorScheme.shadow.withValues(
              alpha: 0.1,
            ),
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
        child:
            _isLoading
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

  Future<void> _submitRegistration() async {
    if (!(_termsFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      await StudentRegistrationService.submitRegistration(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        birthDate: _birthDateController.text.trim(),
        birthPlace: _birthPlaceController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        cap: _capController.text.trim(),
        taxCode:
            _taxCodeController.text.trim().toUpperCase(), // 🎯 Include tax code
        // ... keep existing emergency contact fields ...
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione inviata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _selectBirthDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().subtract(
          const Duration(days: 6570),
        ), // 18 years ago
        firstDate: DateTime(1950),
        lastDate: DateTime.now(),
        locale: const Locale('it', 'IT'),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: AppTheme.lightTheme.colorScheme,
              dialogTheme: DialogTheme(
                backgroundColor: AppTheme.lightTheme.colorScheme.surface,
                surfaceTintColor: Colors.transparent,
              ),
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
          _selectedBirthDate = picked;
          _birthDateController.text =
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
    } catch (e) {
      print('Error selecting date: $e');
    }
  }

  void _onManualDateChanged(DateTime selectedDate) {
    // Calculate if person is minor (under 18)
    final age = DateTime.now().difference(selectedDate).inDays ~/ 365;
    final isMinor = age < 18;

    setState(() {
      _selectedBirthDate = selectedDate;
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
    final basicInfoComplete =
        _fullNameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _birthDateController.text.isNotEmpty &&
        _birthPlaceController.text.isNotEmpty &&
        _addressController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _provinceController.text.isNotEmpty &&
        _capController.text.isNotEmpty;

    // Check parent info if minor
    if (_isMinor) {
      final parentInfoComplete =
          _genitoreNomeController.text.isNotEmpty &&
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
    return _emergencyContacts.any(
      (contact) =>
          (contact['nome'] as String).isNotEmpty &&
          (contact['telefono'] as String).isNotEmpty,
    );
  }

  bool _isFormValid() {
    return _isPersonalInfoComplete() &&
        _isEmergencyContactsComplete() &&
        _termsAccepted;
  }

  bool _validateAllFields() {
    bool isValid = true;

    // Reset all error states first
    setState(() {
      _nomeError = null;
      _cognomeError = null;
      _emailError = null;
      _telefonoError = null;
      _dataNascitaError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _codiceFiscaleError = null;
      _residenzaIndirizzoError = null;
      _residenzaCittaError = null;
      _residenzaProvinciaError = null;
      _residenzaCAPError = null;
      _genitoreNomeError = null;
      _genitoreCognomeError = null;
      _genitoreCodiceFiscaleError = null;
      _genitoreEmailError = null;
      _genitoreTelefonoError = null;
      _genitoreRelationError = null;
    });

    // Validate nome
    if (_fullNameController.text.isEmpty) {
      _nomeError = 'Il nome è obbligatorio';
      isValid = false;
    } else if (_fullNameController.text.length < 2) {
      _nomeError = 'Il nome deve contenere almeno 2 caratteri';
      isValid = false;
    } else {
      _nomeError = null;
    }

    // Validate email
    if (_emailController.text.isEmpty) {
      _emailError = 'L\'email è obbligatoria';
      isValid = false;
    } else if (!RegExp(
      r'^[^@]+@[^@]+\.[^@]+',
    ).hasMatch(_emailController.text)) {
      _emailError = 'Inserisci un\'email valida';
      isValid = false;
    } else {
      _emailError = null;
    }

    // Validate telefono
    if (_phoneController.text.isEmpty) {
      _telefonoError = 'Il telefono è obbligatorio';
      isValid = false;
    } else if (!RegExp(
      r'^[\+]?[0-9\s\-]{8,15}$',
    ).hasMatch(_phoneController.text)) {
      _telefonoError = 'Inserisci un numero di telefono valido';
      isValid = false;
    } else {
      _telefonoError = null;
    }

    // Enhanced date validation for manual input
    if (_birthDateController.text.isEmpty) {
      _dataNascitaError = 'La data di nascita è obbligatoria';
      isValid = false;
    } else {
      // Validate manual date input format and values
      final dateText = _birthDateController.text;
      if (dateText.length != 10 ||
          !RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(dateText)) {
        _dataNascitaError = 'Formato data non valido. Usa DD/MM/YYYY';
        isValid = false;
      } else {
        final parsedDate = _parseManualDateString(dateText);
        if (parsedDate == null) {
          _dataNascitaError = 'Data non valida. Verifica giorno, mese e anno';
          isValid = false;
        } else if (parsedDate.isAfter(DateTime.now())) {
          _dataNascitaError = 'La data di nascita non può essere nel futuro';
          isValid = false;
        } else if (parsedDate.isBefore(DateTime(1900, 1, 1))) {
          _dataNascitaError = 'Data di nascita non valida';
          isValid = false;
        } else {
          _dataNascitaError = null;
          // Update selected date if valid and different
          if (_selectedBirthDate == null ||
              _selectedBirthDate!.year != parsedDate.year ||
              _selectedBirthDate!.month != parsedDate.month ||
              _selectedBirthDate!.day != parsedDate.day) {
            _selectedBirthDate = parsedDate;

            // Check if person is minor
            final age = DateTime.now().difference(parsedDate).inDays ~/ 365;
            final isMinor = age < 18;

            if (_isMinor != isMinor) {
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
            }
          }
        }
      }
    }

    // New mandatory field validations
    // Validate codice fiscale
    if (_taxCodeController.text.isEmpty) {
      _codiceFiscaleError = 'Il codice fiscale è obbligatorio';
      isValid = false;
    } else if (!RegExp(
      r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$',
    ).hasMatch(_taxCodeController.text.toUpperCase())) {
      _codiceFiscaleError = 'Inserisci un codice fiscale valido';
      isValid = false;
    } else {
      _codiceFiscaleError = null;
    }

    // Validate residenza indirizzo
    if (_addressController.text.isEmpty) {
      _residenzaIndirizzoError = 'L\'indirizzo di residenza è obbligatorio';
      isValid = false;
    } else if (_addressController.text.length < 5) {
      _residenzaIndirizzoError =
          'L\'indirizzo deve contenere almeno 5 caratteri';
      isValid = false;
    } else {
      _residenzaIndirizzoError = null;
    }

    // Validate residenza città
    if (_cityController.text.isEmpty) {
      _residenzaCittaError = 'La città è obbligatoria';
      isValid = false;
    } else if (_cityController.text.length < 2) {
      _residenzaCittaError = 'La città deve contenere almeno 2 caratteri';
      isValid = false;
    } else {
      _residenzaCittaError = null;
    }

    // Validate residenza provincia
    if (_provinceController.text.isEmpty) {
      _residenzaProvinciaError = 'La provincia è obbligatoria';
      isValid = false;
    } else if (_provinceController.text.length != 2) {
      _residenzaProvinciaError =
          'Inserisci la sigla della provincia (es. MI, RM)';
      isValid = false;
    } else {
      _residenzaProvinciaError = null;
    }

    // Validate CAP
    if (_capController.text.isEmpty) {
      _residenzaCAPError = 'Il CAP è obbligatorio';
      isValid = false;
    } else if (!RegExp(r'^[0-9]{5}$').hasMatch(_capController.text)) {
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
      } else if (!RegExp(
        r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$',
      ).hasMatch(_genitoreCodiceFiscaleController.text.toUpperCase())) {
        _genitoreCodiceFiscaleError = 'Inserisci un codice fiscale valido';
        isValid = false;
      } else {
        _genitoreCodiceFiscaleError = null;
      }

      // Validate genitore email
      if (_genitoreEmailController.text.isEmpty) {
        _genitoreEmailError = 'L\'email del genitore/tutore è obbligatoria';
        isValid = false;
      } else if (!RegExp(
        r'^[^@]+@[^@]+\.[^@]+',
      ).hasMatch(_genitoreEmailController.text)) {
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
      } else if (!RegExp(
        r'^[\+]?[0-9\s\-]{8,15}$',
      ).hasMatch(_genitoreTelefonoController.text)) {
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

  DateTime? _parseManualDateString(String dateStr) {
    try {
      if (dateStr.length != 10) return null;

      final parts = dateStr.split('/');
      if (parts.length != 3) return null;

      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day == null || month == null || year == null) return null;

      // Validate ranges
      if (day < 1 || day > 31) return null;
      if (month < 1 || month > 12) return null;
      if (year < 1900 || year > DateTime.now().year) return null;

      // Try to create the date
      final date = DateTime(year, month, day);

      // Verify the date is valid (handles invalid dates like 31/02/2023)
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }

      return date;
    } catch (e) {
      return null;
    }
  }

  void _nextStep() {
    setState(() {
      _currentStep++;
    });
    _saveFormData();
  }

  void _handleBackNavigation() {
    if (_hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Modifiche non salvate'),
              content: Text(
                'Hai modifiche non salvate. Vuoi salvare prima di uscire?',
              ),
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
    return _fullNameController.text.isNotEmpty ||
        _emailController.text.isNotEmpty ||
        _phoneController.text.isNotEmpty ||
        _birthDateController.text.isNotEmpty ||
        _birthPlaceController.text.isNotEmpty ||
        _addressController.text.isNotEmpty ||
        _cityController.text.isNotEmpty ||
        _provinceController.text.isNotEmpty ||
        _capController.text.isNotEmpty ||
        _emergencyContacts.any(
          (contact) =>
              (contact['nome'] as String).isNotEmpty ||
              (contact['telefono'] as String).isNotEmpty,
        ) ||
        _uploadedDocuments.isNotEmpty ||
        _termsAccepted;
  }

  Future<void> _saveFormData() async {
    // In a real app, save to local storage or cache
    // Removed automatic save notification to prevent UI interference
    // with registration button. Auto-save now operates silently.

    // Silent auto-save - no UI feedback to prevent blocking registration button
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text('Dati salvati automaticamente'),
    //     duration: const Duration(seconds: 1),
    //     behavior: SnackBarBehavior.floating,
    //   ),
    // );
  }

  // Add method for manual save with confirmation
  Future<void> _saveFormDataWithConfirmation() async {
    // Show confirmation only when user explicitly saves via the save button
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.lightTheme.colorScheme.onInverseSurface,
              size: 20,
            ),
            SizedBox(width: 2.w),
            Text('Bozza salvata con successo'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.lightTheme.colorScheme.inverseSurface,
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

  void _showGeneralErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
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
                Text(
                  result['message'] ?? 'Registrazione completata con successo!',
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: AppTheme.lightTheme.colorScheme.primaryContainer
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.lightTheme.colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'pending',
                            color: AppTheme.lightTheme.colorScheme.primary,
                            size: 20,
                          ),
                          SizedBox(width: 2.w),
                          Flexible(
                            child: Text(
                              'In Attesa di Approvazione Amministratore',
                              style: AppTheme.lightTheme.textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppTheme.lightTheme.colorScheme.primary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        '📧 Gli amministratori sono stati notificati della tua richiesta.\n'
                        '⏳ Riceverai una email di conferma entro 24-48 ore.\n'
                        '🔐 Il tuo account sarà attivato dopo l\'approvazione.',
                        style: AppTheme.lightTheme.textTheme.bodySmall
                            ?.copyWith(
                              color: AppTheme.lightTheme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: AppTheme
                        .lightTheme
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: AppTheme.lightTheme.colorScheme.onSurface,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Cosa succede ora?',
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        '1. L\'amministratore esaminerà la tua richiesta\n'
                        '2. Riceverai un\'email con l\'esito della valutazione\n'
                        '3. Se approvata, potrai accedere al tuo account\n'
                        '4. Potrai completare il profilo e iniziare ad usare i servizi',
                        style: AppTheme.lightTheme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                child: Text('Torna al Login'),
              ),
            ],
          ),
    );
  }
}