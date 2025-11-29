import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import './widgets/authentication_method_selection_widget.dart';
import './widgets/backup_authentication_widget.dart';
import './widgets/biometric_detection_widget.dart';
import './widgets/biometric_setup_header_widget.dart';
import './widgets/biometric_toggle_controls_widget.dart';
import './widgets/security_explanation_widget.dart';
import './widgets/setup_completion_widget.dart';
import './widgets/setup_wizard_widget.dart';
import './widgets/test_authentication_widget.dart';

class BiometricAuthenticationSetup extends StatefulWidget {
  const BiometricAuthenticationSetup({super.key});

  @override
  State<BiometricAuthenticationSetup> createState() =>
      _BiometricAuthenticationSetupState();
}

class _BiometricAuthenticationSetupState
    extends State<BiometricAuthenticationSetup> {
  final AuthService _authService = AuthService.instance;
  final BiometricService _biometricService = BiometricService.instance;

  int _currentStep = 0;
  bool _isLoading = true;
  bool _isDeviceSupported = false;
  List<String> _availableBiometrics = [];
  String _selectedBiometricMethod = '';
  bool _biometricSetupCompleted = false;
  bool _testAuthenticationPassed = false;
  Map<String, bool> _biometricSettings = {
    'appLaunch': true,
    'paymentConfirmation': true,
    'sensitiveDataAccess': true,
  };
  String _backupPIN = '';
  bool _backupAuthConfigured = false;

  @override
  void initState() {
    super.initState();
    _initializeBiometricSetup();
  }

  /// Initialize biometric setup and check device capabilities
  Future<void> _initializeBiometricSetup() async {
    try {
      setState(() => _isLoading = true);

      // Check if biometrics are available on this device
      final isAvailable = await _biometricService.isAvailable();

      if (isAvailable) {
        // Get available biometric methods
        final availableBiometrics =
            await _biometricService.getAvailableBiometrics();

        setState(() {
          _isDeviceSupported = true;
          _availableBiometrics = availableBiometrics;
          _selectedBiometricMethod =
              availableBiometrics.isNotEmpty ? availableBiometrics.first : '';
        });
      } else {
        setState(() {
          _isDeviceSupported = false;
        });
      }
    } catch (e) {
      print('Error initializing biometric setup: $e');
      setState(() {
        _isDeviceSupported = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Test biometric authentication
  Future<void> _testBiometricAuthentication() async {
    try {
      final result = await _biometricService.authenticate(
        reason: 'Testa la configurazione biometrica per Team Ragnarok',
        stickyAuth: true,
      );

      setState(() {
        _testAuthenticationPassed = result;
      });

      if (result) {
        _showSuccessMessage('Test biometrico riuscito!');
      } else {
        _showErrorMessage('Test biometrico fallito. Riprova.');
      }
    } catch (e) {
      print('Test authentication error: $e');
      _showErrorMessage('Errore durante il test biometrico');
    }
  }

  /// Enable biometric authentication for the current user
  Future<void> _enableBiometricAuthentication() async {
    try {
      setState(() => _isLoading = true);

      final success = await _authService.enableBiometricAuth();

      if (success) {
        setState(() {
          _biometricSetupCompleted = true;
          _currentStep = 7; // Move to completion step
        });
        _showSuccessMessage('Autenticazione biometrica attivata!');
      } else {
        _showErrorMessage('Errore durante l\'attivazione biometrica');
      }
    } catch (e) {
      print('Error enabling biometric authentication: $e');
      _showErrorMessage('Errore durante l\'attivazione biometrica');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Configure backup PIN authentication
  void _configureBackupPIN(String pin) {
    setState(() {
      _backupPIN = pin;
      _backupAuthConfigured = pin.length >= 4;
    });
  }

  /// Update biometric toggle settings
  void _updateBiometricSetting(String key, bool value) {
    setState(() {
      _biometricSettings[key] = value;
    });
  }

  /// Navigate to next setup step
  void _nextStep() {
    if (_currentStep < 7) {
      setState(() => _currentStep++);
    }
  }

  /// Navigate to previous setup step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  /// Skip biometric setup and go to dashboard
  void _skipBiometricSetup() {
    Navigator.pushReplacementNamed(context, AppRoutes.dashboardHome);
  }

  /// Complete setup and navigate to dashboard
  void _completeSetup() {
    Navigator.pushReplacementNamed(context, AppRoutes.dashboardHome);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorLight,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successLight,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              ),
            )
          : !_isDeviceSupported && !kIsWeb
              ? _buildUnsupportedDeviceView()
              : _buildBiometricSetupView(),
    );
  }

  /// Build view for unsupported devices
  Widget _buildUnsupportedDeviceView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fingerprint_outlined,
              size: 20.w,
              color: Colors.grey.shade600,
            ),
            SizedBox(height: 3.h),
            Text(
              'Dispositivo non supportato',
              style: GoogleFonts.inter(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            Text(
              'Il tuo dispositivo non supporta l\'autenticazione biometrica o non ha sensori biometrici configurati.',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey.shade400,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            ElevatedButton(
              onPressed: _skipBiometricSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continua senza biometria',
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build main biometric setup view
  Widget _buildBiometricSetupView() {
    return Column(
      children: [
        // Header with Team Ragnarok logo and security shield
        BiometricSetupHeaderWidget(
          currentStep: _currentStep,
          totalSteps: 8,
          onSkip: _skipBiometricSetup,
        ),

        // Setup content based on current step
        Expanded(
          child: _buildSetupStepContent(),
        ),

        // Navigation buttons
        _buildNavigationButtons(),
      ],
    );
  }

  /// Build content for current setup step
  Widget _buildSetupStepContent() {
    switch (_currentStep) {
      case 0:
        return BiometricDetectionWidget(
          availableBiometrics: _availableBiometrics,
          onDetectionComplete: () => _nextStep(),
        );

      case 1:
        return SetupWizardWidget(
          currentStep: 1,
          onContinue: () => _nextStep(),
        );

      case 2:
        return AuthenticationMethodSelectionWidget(
          availableMethods: _availableBiometrics,
          selectedMethod: _selectedBiometricMethod,
          onMethodSelected: (method) {
            setState(() => _selectedBiometricMethod = method);
          },
          onContinue: () => _nextStep(),
        );

      case 3:
        return SecurityExplanationWidget(
          onContinue: () => _nextStep(),
        );

      case 4:
        return TestAuthenticationWidget(
          selectedMethod: _selectedBiometricMethod,
          testPassed: _testAuthenticationPassed,
          onTest: _testBiometricAuthentication,
          onContinue: _testAuthenticationPassed ? () => _nextStep() : null,
        );

      case 5:
        return BackupAuthenticationWidget(
          backupPIN: _backupPIN,
          isConfigured: _backupAuthConfigured,
          onPINConfigured: _configureBackupPIN,
          onContinue: _backupAuthConfigured ? () => _nextStep() : null,
        );

      case 6:
        return BiometricToggleControlsWidget(
          settings: _biometricSettings,
          onSettingChanged: _updateBiometricSetting,
          onContinue: () => _nextStep(),
        );

      case 7:
        return SetupCompletionWidget(
          selectedMethod: _selectedBiometricMethod,
          settings: _biometricSettings,
          onActivate: _enableBiometricAuthentication,
          onComplete: _completeSetup,
          isActivated: _biometricSetupCompleted,
        );

      default:
        return const SizedBox();
    }
  }

  /// Build navigation buttons at bottom
  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Indietro',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          if (_currentStep > 0) SizedBox(width: 4.w),

          // Skip button for first few steps
          if (_currentStep < 6)
            Expanded(
              child: TextButton(
                onPressed: _skipBiometricSetup,
                child: Text(
                  'Salta configurazione',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
