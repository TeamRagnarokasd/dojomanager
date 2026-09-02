import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isCheckingSession = true;

  // SharedPreferences keys
  static const String _keyRememberMe = 'remember_me';
  static const String _keyStoredEmail = 'stored_email';

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// Check for existing valid Supabase session and navigate if found
  Future<void> _checkExistingSession() async {
    setState(() {
      _isCheckingSession = true;
    });

    try {
      print('🔍 Checking existing Supabase session at app startup...');

      if (_authService.isAuthenticated) {
        final currentSession = _authService.currentSession;

        if (currentSession != null && !currentSession.isExpired) {
          final isApproved = await _checkUserApprovalStatus();
          if (!isApproved) {
            if (mounted) setState(() => _isCheckingSession = false);
            return;
          }

          await _authService.updateLastActiveTimestamp();
          await _navigateBasedOnUserRole();
          return;
        }
      }

      final shouldAutoLogin = await _authService.shouldAutoLogin();
      if (shouldAutoLogin && _authService.isAuthenticated) {
        final isApproved = await _checkUserApprovalStatus();
        if (!isApproved) {
          if (mounted) setState(() => _isCheckingSession = false);
          return;
        }
        await _navigateBasedOnUserRole();
        return;
      }

      // Check for inactivity timeout (14 days)
      final isInactive = await _authService.checkInactivityTimeout();
      if (isInactive) {
        _authService.showErrorToast('auth.session_expired_inactivity'.tr());
        setState(() {
          _emailController.clear();
          _rememberMe = false;
        });
        return;
      }

      // Pre-fill email if "Remember Me" was enabled
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      final storedEmail = prefs.getString(_keyStoredEmail);

      if (rememberMe && storedEmail != null && storedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = storedEmail;
          _rememberMe = true;
        });
      }

      print('❌ No valid session found - showing login screen');
    } catch (error) {
      print('⚠️ Session check error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  // SharedPreferences key for bypassing the 1-hour inactivity timeout
  static const String _keyRememberMeBypassInactivity =
      'remember_me_bypass_inactivity';

  /// Save "remember me" preference
  Future<void> _saveRememberMePreference(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, _rememberMe);

      if (_rememberMe) {
        await prefs.setString(_keyStoredEmail, email);
        // Mark that the 1-hour inactivity timeout should be bypassed
        await prefs.setBool(_keyRememberMeBypassInactivity, true);
        // Initialize last active timestamp when saving remember me preference
        await _authService.updateLastActiveTimestamp();
      } else {
        await prefs.remove(_keyStoredEmail);
        // Ensure bypass flag is cleared when Remember Me is not checked
        await prefs.remove(_keyRememberMeBypassInactivity);
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
      await prefs.remove(_keyRememberMeBypassInactivity);
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

  void _onForgotPassword() {
    _showPasswordResetDialog();
  }

  void _showPasswordResetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _PasswordResetDialog(initialEmail: _emailController.text.trim()),
    );
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
        final userId = response!.user!.id;

        try {
          final profileData = await Supabase.instance.client
              .from('user_profiles')
              .select('status, is_active, role')
              .eq('id', userId)
              .maybeSingle();

          if (profileData != null) {
            final userStatus = (profileData['status'] as String?)
                ?.trim()
                .toLowerCase();
            final isActive = profileData['is_active'] == true;

            if (userStatus == 'pending' || userStatus == 'rejected') {
              await _authService.signOut();
              if (mounted) {
                setState(() => _isLoading = false);
                _showApprovalPendingDialog(userStatus == 'rejected');
              }
              return;
            }

            if (!isActive) {
              await _authService.signOut();
              if (mounted) {
                setState(() => _isLoading = false);
                _authService.showErrorToast(
                  'Il tuo account è stato disattivato. Contatta l\'amministratore.',
                );
              }
              return;
            }
          }
        } catch (profileError) {
          debugPrint('Profile lookup failed after login: $profileError');
        }

        if (!kIsWeb) HapticFeedback.heavyImpact();

        await _saveRememberMePreference(email);

        _authService.showSuccessToast('auth.login_success'.tr());

        await _navigateBasedOnUserRole();
      } else {
        setState(() {
          _isLoading = false;
        });
        _authService.showErrorToast('auth.login_error'.tr());
      }
    } catch (error) {
      setState(() {
        _isLoading = false;

        final errorMessage = error.toString();

        // Set specific field errors
        if (errorMessage.contains('Invalid email')) {
          _emailError = 'auth.invalid_email_field'.tr();
        } else if (errorMessage.contains('Invalid password') ||
            errorMessage.contains('Credenziali non valide')) {
          _passwordError = 'auth.wrong_password'.tr();
        } else if (errorMessage.contains('Email not confirmed')) {
          _emailError = 'auth.email_not_confirmed'.tr();
        }
      });

      if (!kIsWeb) HapticFeedback.heavyImpact();
      _authService.showErrorToast(error.toString());
    }
  }

  void _showApprovalPendingDialog(bool isRejected) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isRejected ? Icons.block : Icons.hourglass_top,
              color: isRejected ? Colors.red : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                isRejected
                    ? 'auth.registration_rejected_title'.tr()
                    : 'auth.approval_pending_title'.tr(),
              ),
            ),
          ],
        ),
        content: Text(
          isRejected
              ? 'auth.registration_rejected_message'.tr()
              : 'auth.approval_pending_message'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  /// Check if the user's profile status allows app access.
  /// Returns true if the user is approved and active.
  Future<bool> _checkUserApprovalStatus() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return false;

      final profileData = await Supabase.instance.client
          .from('user_profiles')
          .select('status, is_active')
          .eq('id', userId)
          .maybeSingle();

      if (profileData == null) return false;

      final userStatus = (profileData['status'] as String?)
          ?.trim()
          .toLowerCase();
      final isActive = profileData['is_active'] == true;

      if (userStatus == 'pending' || userStatus == 'rejected' || !isActive) {
        await _authService.signOut();
        if (mounted) {
          if (userStatus == 'pending' || userStatus == 'rejected') {
            _showApprovalPendingDialog(userStatus == 'rejected');
          } else {
            _authService.showErrorToast('auth.account_deactivated'.tr());
          }
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking approval status: $e');
      return true;
    }
  }

  /// Navigate to appropriate dashboard based on user role
  Future<void> _navigateBasedOnUserRole({bool isSessionRestore = false}) async {
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
      } else if (userRole == 'instructor' || userRole == 'instructor_student') {
        // Instructors and instructor_student go to the unified instructor dashboard
        targetRoute = AppRoutes.instructorMainDashboard;
        print(
          '✅ Instructor detected - redirecting to instructor main dashboard',
        );
      } else {
        // ALL other non-admin users (students) go to dashboard home
        targetRoute = AppRoutes.dashboardHome;
        print('✅ Non-admin user detected - redirecting to dashboard home');
      }

      if (isSessionRestore) {
        print(
          '🔄 Session restore - navigating to default dashboard: $targetRoute',
        );
      } else {
        print('🆕 Fresh login - navigating to dashboard: $targetRoute');
        // Clear saved route on fresh login so next app open starts from home
        await _authService.clearLastVisitedRoute();
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
    // Show loading indicator during session check
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.secondaryDark,
                strokeWidth: 3,
              ),
              SizedBox(height: 3.h),
              Text(
                'Verifica sessione in corso...',
                style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
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
                          width: 48.w,
                          height: 48.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/146804-1762122410365.jpg',
                              width: 48.w,
                              height: 48.w,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 48.w,
                                  height: 48.w,
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceDark,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 24.w,
                                    color: AppTheme.textSecondaryDark,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'Team Ragnarok APP',
                          style: AppTheme.darkTheme.textTheme.headlineMedium
                              ?.copyWith(
                                color: AppTheme.textPrimaryDark,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'BJJ • SAMBO • MMA • GRAPPLING',
                          style: AppTheme.darkTheme.textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondaryDark,
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryDark,
                        foregroundColor: AppTheme.onSecondaryDark,
                      ),
                      onPressed: _isLoading ? null : _performLogin,
                      child: _isLoading
                          ? SizedBox(
                              width: 5.w,
                              height: 5.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.onSecondaryDark,
                                ),
                              ),
                            )
                          : Text(
                              'common.login'.tr(),
                              style: AppTheme.darkTheme.textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppTheme.onSecondaryDark,
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
                        'auth.new_user_prefix'.tr(),
                        style: AppTheme.darkTheme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.textSecondaryDark),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (!kIsWeb) HapticFeedback.lightImpact();
                          _navigateToRegistration();
                        },
                        child: Text(
                          'common.register'.tr(),
                          style: AppTheme.darkTheme.textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.secondaryDark,
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

// ─── Password Reset Dialog ────────────────────────────────────────────────────

class _PasswordResetDialog extends StatefulWidget {
  final String initialEmail;
  const _PasswordResetDialog({required this.initialEmail});

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  bool _isLoading = false;
  bool _submitted = false;
  String? _errorMsg;

  final _emailCtrl = TextEditingController();
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF0000),
            onPrimary: Colors.white,
            surface: Color(0xFF2A2A2A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _submitRequest() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _errorMsg = 'Inserisci un indirizzo email valido.');
      return;
    }
    if (_selectedBirthDate == null) {
      setState(() => _errorMsg = 'Inserisci la tua data di nascita.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final client = Supabase.instance.client;

      // Look up user by email
      final profileResult = await client
          .from('user_profiles')
          .select('id, full_name, birth_date')
          .eq('email', email)
          .maybeSingle();

      if (profileResult == null) {
        // Do not reveal whether the email exists — show generic error
        setState(() {
          _errorMsg =
              'Nessun account trovato con i dati forniti. Verifica email e data di nascita.';
        });
        return;
      }

      // Use the correct column name: birth_date
      final rawBirthDate = profileResult['birth_date'];

      if (rawBirthDate == null) {
        setState(() {
          _errorMsg =
              'Nessun account trovato con i dati forniti. Verifica email e data di nascita.';
        });
        return;
      }

      final storedDate = DateTime.tryParse(rawBirthDate.toString());
      if (storedDate == null) {
        setState(() {
          _errorMsg =
              'Nessun account trovato con i dati forniti. Verifica email e data di nascita.';
        });
        return;
      }

      // Compare only year/month/day
      final selected = _selectedBirthDate!;
      final match =
          storedDate.year == selected.year &&
          storedDate.month == selected.month &&
          storedDate.day == selected.day;

      if (!match) {
        setState(() {
          _errorMsg =
              'Nessun account trovato con i dati forniti. Verifica email e data di nascita.';
        });
        return;
      }

      // Insert password reset request — admin will be notified
      await client.from('password_reset_requests').insert({
        'user_id': profileResult['id'],
        'user_email': email,
        'user_full_name': profileResult['full_name'] ?? email,
        'status': 'pending',
      });

      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Si è verificato un errore. Riprova più tardi.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _formattedBirthDate {
    if (_selectedBirthDate == null) return 'Seleziona data';
    final d = _selectedBirthDate!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.lock_reset, color: Color(0xFFFF0000), size: 24),
          const SizedBox(width: 8),
          Text(
            'Recupero Password',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: _submitted ? _buildSuccessContent() : _buildFormContent(),
      ),
      actions: _submitted
          ? [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Chiudi',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ]
          : [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: Text(
                  'Annulla',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Invia Richiesta',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Per verificare la tua identità, inserisci l\'indirizzo email associato al tuo account e la tua data di nascita.',
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        // Email field
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Indirizzo Email',
            labelStyle: GoogleFonts.inter(color: Colors.grey[400]),
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[700]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF0000)),
            ),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
          ),
        ),
        const SizedBox(height: 14),

        // Birth date picker
        GestureDetector(
          onTap: _pickBirthDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedBirthDate != null
                    ? const Color(0xFFFF0000)
                    : Colors.grey[700]!,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedBirthDate != null
                        ? _formattedBirthDate
                        : 'Data di nascita',
                    style: GoogleFonts.inter(
                      color: _selectedBirthDate != null
                          ? Colors.white
                          : Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.grey[600],
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMsg!,
                    style: GoogleFonts.inter(
                      color: Colors.red[300],
                      fontSize: 12,
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

  Widget _buildSuccessContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Richiesta Inviata',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'La tua richiesta di recupero password è stata registrata con successo.\n\n'
          'Sarai contattato dall\'amministratore tramite WhatsApp con una password provvisoria. '
          'Una volta effettuato l\'accesso, ti consigliamo di aggiornare la password al più presto '
          'per garantire la sicurezza del tuo account.',
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 13,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
