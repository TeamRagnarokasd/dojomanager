import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import './widgets/biometric_prompt_widget.dart';
import './widgets/login_form_widget.dart';
import './widgets/role_selection_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService.instance;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showBiometricPrompt = false;
  String _selectedRole = 'student';
  String? _emailError;
  String? _passwordError;
  bool _showAdminStatus = false;
  Map<String, dynamic>? _adminStatusData;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    _loadAdminStatus();
  }

  void _initializeAuth() {
    // Initialize auth listener
    _authService.initAuthListener();

    // Check if user is already authenticated
    if (_authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToDashboard();
      });
    }
  }

  Future<void> _loadAdminStatus() async {
    try {
      final status =
          await _authService.adminVerification.getAdminStatusSummary();
      setState(() {
        _adminStatusData = status;
      });
    } catch (error) {
      print('Error loading admin status: $error');
    }
  }

  void _toggleAdminStatus() {
    setState(() {
      _showAdminStatus = !_showAdminStatus;
    });
  }

  Future<void> _performAdminVerification() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final result =
          await _authService.adminVerification.performCompleteVerification();

      if (result.success) {
        _authService.showSuccessToast(
          'Verifica admin completata con successo!',
        );
        await _loadAdminStatus();
      } else {
        _authService.showErrorToast(
          'Verifica admin fallita: ${result.message}',
        );

        // Show emergency reset option
        final shouldReset = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Problema Admin Rilevato'),
                content: Text(
                  '${result.message}\n\nVuoi eseguire un reset di emergenza dell\'admin?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annulla'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Reset Emergenza'),
                  ),
                ],
              ),
        );

        if (shouldReset == true) {
          final resetSuccess =
              await _authService.adminVerification.emergencyAdminReset();
          if (resetSuccess) {
            _authService.showSuccessToast('Reset emergenza admin completato!');
            await _loadAdminStatus();
          } else {
            _authService.showErrorToast('Reset emergenza fallito');
          }
        }
      }
    } catch (error) {
      _authService.showErrorToast('Errore durante verifica admin: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _onRoleSelected(String role) {
    setState(() {
      _selectedRole = role;
      _emailError = null;
      _passwordError = null;
    });

    // Set suggested email based on role
    switch (role) {
      case 'admin':
        _emailController.text = 'lutadordeeliteravenna@gmail.com';
        break;
      case 'instructor':
        _emailController.text = 'instructor@teamragnarok.com';
        break;
      case 'student':
        _emailController.text = 'studente@teamragnarok.com';
        break;
    }
  }

  void _onForgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _authService.showErrorToast(
        'Inserisci la tua email per recuperare la password',
      );
      return;
    }

    try {
      await _authService.resetPassword(email: _emailController.text.trim());
      _authService.showSuccessToast(
        'Link di reset password inviato alla tua email',
      );
    } catch (error) {
      _authService.showErrorToast(error.toString());
    }
  }

  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final response = await _authService.signInWithPassword(
        email: email,
        password: password,
      );

      if (response?.user != null) {
        // Success - trigger haptic feedback
        HapticFeedback.heavyImpact();

        _authService.showSuccessToast('Accesso effettuato con successo!');

        // Check user role and update selected role
        final userRole = await _authService.getUserRole();
        setState(() {
          _selectedRole = userRole;
        });

        // Show biometric prompt for future logins
        setState(() {
          _showBiometricPrompt = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _authService.showErrorToast('Errore durante l\'accesso');
      }
    } catch (error) {
      setState(() {
        _isLoading = false;

        final errorMessage = error.toString();

        // Set specific field errors
        if (errorMessage.contains('Invalid email')) {
          _emailError = 'Email non valida';
        } else if (errorMessage.contains('Invalid password') ||
            errorMessage.contains('Credenziali non valide')) {
          _passwordError = 'Password non corretta';
        } else if (errorMessage.contains('Email not confirmed')) {
          _emailError =
              'Email non confermata. Controlla la tua casella di posta.';
        }
      });

      HapticFeedback.heavyImpact();
      _authService.showErrorToast(error.toString());
    }
  }

  void _navigateToDashboard() {
    Navigator.pushReplacementNamed(context, '/dashboard-home');
  }

  void _onBiometricLogin() {
    HapticFeedback.heavyImpact();
    _authService.showSuccessToast('Accesso biometrico configurato!');
    _navigateToDashboard();
  }

  void _onSkipBiometric() {
    _navigateToDashboard();
  }

  void _navigateToRegistration() {
    Navigator.pushNamed(context, '/student-registration');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 8.h),

                  // Logo Section
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/149054-1756519869859.jpg',
                              width: 24.w,
                              height: 24.w,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 12.w,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Team Ragnarok APP',
                              style: AppTheme
                                  .lightTheme
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AppTheme.textPrimaryLight,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            SizedBox(width: 2.w),
                            GestureDetector(
                              onTap: _toggleAdminStatus,
                              child: Icon(
                                _showAdminStatus
                                    ? Icons.admin_panel_settings
                                    : Icons.admin_panel_settings_outlined,
                                color:
                                    _adminStatusData?['admin_profile_exists'] ==
                                            true
                                        ? Colors.green
                                        : Colors.orange,
                                size: 6.w,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'BJJ • SAMBO • MMA • GRAPPLING',
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // Admin Status Panel
                  if (_showAdminStatus && _adminStatusData != null) ...[
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: AppTheme.lightTheme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _adminStatusData!['admin_profile_exists'] == true
                                  ? Colors.green
                                  : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                color:
                                    _adminStatusData!['admin_profile_exists'] ==
                                            true
                                        ? Colors.green
                                        : Colors.orange,
                                size: 5.w,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                'Stato Sistema Admin',
                                style: AppTheme.lightTheme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          _buildStatusRow(
                            'Profilo Admin',
                            _adminStatusData!['admin_profile_exists'] == true,
                          ),
                          _buildStatusRow(
                            'Auth Admin',
                            _adminStatusData!['admin_auth_exists'] == true,
                          ),
                          _buildStatusRow(
                            'Admin Attivo',
                            _adminStatusData!['admin_active'] == true,
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _performAdminVerification,
                                  icon: Icon(Icons.verified_user, size: 4.w),
                                  label: const Text('Verifica Admin'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 4.h),
                  ],

                  SizedBox(height: 6.h),

                  // Login Form
                  if (!_showBiometricPrompt) ...[
                    Form(
                      key: _formKey,
                      child: LoginFormWidget(
                        emailController: _emailController,
                        passwordController: _passwordController,
                        isPasswordVisible: _isPasswordVisible,
                        onPasswordVisibilityToggle: _togglePasswordVisibility,
                        onForgotPassword: _onForgotPassword,
                        emailError: _emailError,
                        passwordError: _passwordError,
                      ),
                    ),

                    SizedBox(height: 4.h),

                    // Role Selection
                    RoleSelectionWidget(
                      selectedRole: _selectedRole,
                      onRoleSelected: _onRoleSelected,
                    ),

                    SizedBox(height: 6.h),

                    // Login Button
                    SizedBox(
                      height: 7.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _performLogin,
                        child:
                            _isLoading
                                ? SizedBox(
                                  width: 5.w,
                                  height: 5.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.onPrimaryLight,
                                    ),
                                  ),
                                )
                                : Text(
                                  'Accedi',
                                  style: AppTheme
                                      .lightTheme
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: AppTheme.onPrimaryLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                      ),
                    ),
                  ],

                  // Biometric Prompt
                  if (_showBiometricPrompt) ...[
                    BiometricPromptWidget(
                      onBiometricLogin: _onBiometricLogin,
                      onSkip: _onSkipBiometric,
                      isAvailable: true,
                    ),
                  ],

                  SizedBox(height: 4.h),

                  // Registration Link
                  if (!_showBiometricPrompt) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Nuovo utente? ',
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.textSecondaryLight),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _navigateToRegistration();
                          },
                          child: Text(
                            'Registrati',
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.primaryLight,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 4.h),

                  // Auth Info Section (for development/testing)
                  if (!_showBiometricPrompt &&
                      _authService.currentUser == null) ...[
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: AppTheme.lightTheme.colorScheme.surface
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.borderLight,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account di prova disponibili:',
                            style: AppTheme.lightTheme.textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.textPrimaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            'Admin: lutadordeeliteravenna@gmail.com',
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryLight,
                                  fontFamily: 'monospace',
                                ),
                          ),
                          Text(
                            'Studente: studente@teamragnarok.com',
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryLight,
                                  fontFamily: 'monospace',
                                ),
                          ),
                          Text(
                            'Istruttore: instructor@teamragnarok.com',
                            style: AppTheme.lightTheme.textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryLight,
                                  fontFamily: 'monospace',
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isSuccess) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
            size: 4.w,
          ),
          SizedBox(width: 2.w),
          Text(
            label,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: isSuccess ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
