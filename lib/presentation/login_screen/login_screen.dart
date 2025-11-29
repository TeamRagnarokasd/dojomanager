import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import './widgets/login_form_widget.dart';

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
  bool _rememberMe = false;
  String? _emailError;
  String? _passwordError;

  // SharedPreferences keys
  static const String _keyRememberMe = 'remember_me';
  static const String _keyStoredEmail = 'stored_email';

  @override
  void initState() {
    super.initState();
    _checkRememberedSession();
  }

  /// Check if user has enabled "remember me" and auto-login
  Future<void> _checkRememberedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      final storedEmail = prefs.getString(_keyStoredEmail);

      if (rememberMe && storedEmail != null && storedEmail.isNotEmpty) {
        // Check if there's an active Supabase session
        final currentSession = _authService.currentSession;

        if (currentSession != null && !currentSession.isExpired) {
          // User is already logged in, navigate to appropriate dashboard
          await _navigateBasedOnUserRole();
        } else {
          // Pre-fill email for convenience
          setState(() {
            _emailController.text = storedEmail;
            _rememberMe = true;
          });
        }
      }
    } catch (error) {
      print('Error checking remembered session: $error');
    }
  }

  /// Save "remember me" preference
  Future<void> _saveRememberMePreference(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, _rememberMe);

      if (_rememberMe) {
        await prefs.setString(_keyStoredEmail, email);
      } else {
        await prefs.remove(_keyStoredEmail);
      }
    } catch (error) {
      print('Error saving remember me preference: $error');
    }
  }

  /// Clear "remember me" data
  Future<void> _clearRememberMeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRememberMe);
      await prefs.remove(_keyStoredEmail);
    } catch (error) {
      print('Error clearing remember me data: $error');
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

  void _onRememberMeChanged(bool value) {
    setState(() {
      _rememberMe = value;
    });
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

        // Save remember me preference
        await _saveRememberMePreference(email);

        _authService.showSuccessToast('Accesso effettuato con successo!');

        // Navigate directly based on database role
        await _navigateBasedOnUserRole();
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

  /// Navigate to appropriate dashboard based on user role
  Future<void> _navigateBasedOnUserRole() async {
    try {
      final user = _authService.currentUser;
      final userRole = await _authService.getUserRole();
      final isPrincipalAdmin = await _authService.isPrincipalAdmin();

      // Check if user is principal admin by email or role
      final isPrincipalByEmail =
          user?.email?.toLowerCase() == 'lutadordeeliteravenna@gmail.com';

      String targetRoute;

      if (isPrincipalAdmin || isPrincipalByEmail) {
        // Principal admin goes DIRECTLY to enhanced admin dashboard
        targetRoute = AppRoutes.enhancedAdminDashboard;
        print('✅ Principal admin detected - redirecting to enhanced dashboard');
      } else if (['admin', 'instructor_admin'].contains(userRole)) {
        // Other admins go to enhanced admin dashboard
        targetRoute = AppRoutes.enhancedAdminDashboard;
        print('✅ Admin detected - redirecting to enhanced admin dashboard');
      } else {
        // ALL non-admin users (students, instructors) go to dashboard home
        targetRoute = AppRoutes.dashboardHome;
        print('✅ Non-admin user detected - redirecting to dashboard home');
      }

      // Navigate to the determined route
      Navigator.pushNamedAndRemoveUntil(context, targetRoute, (route) => false);
    } catch (error) {
      print('Error in role-based navigation: $error');
      // Fallback to dashboard home for non-admin users
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboardHome,
        (route) => false,
      );
    }
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
              minHeight: MediaQuery.of(context).size.height -
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
                              'assets/images/146804-1762122410365.jpg',
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
                        Text(
                          'Team Ragnarok APP',
                          style: AppTheme.lightTheme.textTheme.headlineMedium
                              ?.copyWith(
                            color: AppTheme.textPrimaryLight,
                            fontWeight: FontWeight.w700,
                          ),
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

                  SizedBox(height: 6.h),

                  // Login Form
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
                      rememberMe: _rememberMe,
                      onRememberMeChanged: _onRememberMeChanged,
                    ),
                  ),

                  SizedBox(height: 6.h),

                  // Login Button
                  SizedBox(
                    height: 7.h,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _performLogin,
                      child: _isLoading
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
                              style: AppTheme.lightTheme.textTheme.titleMedium
                                  ?.copyWith(
                                color: AppTheme.onPrimaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // Registration Link
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

                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
