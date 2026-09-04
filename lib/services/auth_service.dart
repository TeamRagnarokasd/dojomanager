import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_export.dart';
import './admin_verification_service.dart';
import './biometric_service.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  final SupabaseClient _client = Supabase.instance.client;
  final AdminVerificationService _adminVerificationService =
      AdminVerificationService.instance;

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get current user session
  Session? get currentSession => _client.auth.currentSession;

  /// Initialize authentication system with admin verification and session check
  Future<void> initializeAuthSystem() async {
    try {
      print('🔐 Initializing authentication system...');

      // Verify admin system is properly set up
      final adminVerification =
          await _adminVerificationService.performCompleteVerification();

      if (adminVerification.success) {
        print('✅ Admin verification successful: ${adminVerification.message}');
      } else {
        print('⚠️ Admin verification failed: ${adminVerification.message}');

        // Attempt emergency admin reset
        print('Attempting emergency admin reset...');
        final resetSuccess =
            await _adminVerificationService.emergencyAdminReset();

        if (resetSuccess) {
          print('✅ Emergency admin reset successful');
        } else {
          print(
            '❌ Emergency admin reset failed - manual intervention required',
          );
        }
      }

      // Initialize auth listener for session refresh
      initAuthListener();

      // Check if we have a persisted session
      await _checkPersistedSession();

      print('✅ Authentication system initialization completed');
    } catch (error) {
      print('❌ Error initializing authentication system: $error');
    }
  }

  /// Check for persisted Supabase session
  Future<bool> _checkPersistedSession() async {
    try {
      final currentSession = _client.auth.currentSession;

      if (currentSession != null && !currentSession.isExpired) {
        print('✅ Valid persisted Supabase session found');
        print(
          '   - Session expires at: ${DateTime.fromMillisecondsSinceEpoch(currentSession.expiresAt! * 1000)}',
        );

        // Update last active timestamp
        await updateLastActiveTimestamp();

        return true;
      } else {
        print('❌ No valid persisted session found');
        return false;
      }
    } catch (error) {
      print('⚠️ Error checking persisted session: $error');
      return false;
    }
  }

  /// Get remember me preference
  Future<bool> getRememberMePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRememberMe) ?? false;
    } catch (error) {
      print('Error reading remember me preference: $error');
      return false;
    }
  }

  /// Set remember me preference
  Future<void> setRememberMePreference(bool value, {String? email}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, value);

      if (value && email != null) {
        await prefs.setString(_keyRememberMeEmail, email);
        await prefs.setInt(
          _keyRememberMeTimestamp,
          DateTime.now().millisecondsSinceEpoch,
        );
        // Initialize last active timestamp when enabling Remember Me
        await updateLastActiveTimestamp();
      } else {
        await prefs.remove(_keyRememberMeEmail);
        await prefs.remove(_keyRememberMeTimestamp);
        await prefs.remove(
          _keyLastActiveTimestamp,
        ); // Clear last active when disabling
      }
    } catch (error) {
      print('Error saving remember me preference: $error');
    }
  }

  /// Check if auto-login should be performed
  Future<bool> shouldAutoLogin() async {
    try {
      // First, check if Supabase has a valid session (highest priority)
      final currentSession = _client.auth.currentSession;
      if (currentSession != null && !currentSession.isExpired) {
        print('✅ Valid Supabase session detected - auto-login enabled');
        return true;
      }

      // Fallback to legacy "Remember Me" check
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;

      if (!rememberMe) {
        print('❌ Remember Me disabled - auto-login not available');
        return false;
      }

      // Check if remember me session is still valid (14-day window)
      final timestamp = prefs.getInt(_keyRememberMeTimestamp);
      if (timestamp == null) {
        print('⚠️ No Remember Me timestamp found');
        return false;
      }

      final lastLoginDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final daysSinceLogin = DateTime.now().difference(lastLoginDate).inDays;

      if (daysSinceLogin > _rememberMeDurationDays) {
        // Remember me session expired
        print(
          '⏰ Remember Me session expired (${daysSinceLogin} days > ${_rememberMeDurationDays} days)',
        );
        await setRememberMePreference(false);
        return false;
      }

      print('✅ Remember Me valid - checking for active Supabase session');
      return isAuthenticated;
    } catch (error) {
      print('⚠️ Error checking auto-login: $error');
      return false;
    }
  }

  /// Sign in with email and password with enhanced session persistence
  Future<AuthResponse?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Check if this is admin account for enhanced verification
      final isAdminAccount =
          email.toLowerCase() == 'lutadordeeliteravenna@gmail.com';

      // ENHANCED: For admin login, first verify with custom function
      if (isAdminAccount) {
        try {
          final adminVerificationResult = await _client.rpc(
            'verify_principal_admin_login',
            params: {'check_email': email, 'check_password': password},
          );

          if (adminVerificationResult != null &&
              adminVerificationResult['success'] == false) {
            // Custom admin verification failed
            throw Exception(
              adminVerificationResult['message'] ??
                  'Credenziali non valide. Verifica email e password.',
            );
          }
        } catch (verificationError) {
          print('Admin verification error: $verificationError');
          // Don't throw here, let normal auth proceed as fallback
        }
      }

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null && response.session != null) {
        print('✅ Login successful');
        print(
          '   - Session expires at: ${DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)}',
        );

        // REMOVED: No longer updating user profile during login
        // Only read existing data, never write/update during authentication

        // Update last active timestamp for session tracking
        await updateLastActiveTimestamp();

        // REMOVED: Special handling for principal admin that updated the role
        // Authentication should only read data, not modify it
      }

      return response;
    } catch (error) {
      // ENHANCED: Better error handling for admin accounts
      String errorMessage = _handleAuthError(error);

      // Special handling for admin login errors
      if (email.toLowerCase() == 'lutadordeeliteravenna@gmail.com') {
        if (errorMessage.contains('Invalid login credentials') ||
            errorMessage.contains('Invalid email or password') ||
            errorMessage.contains('Credenziali non valide')) {
          errorMessage =
              'Credenziali amministratore non valide. Verifica email (lutadordeeliteravenna@gmail.com) e password (Magnus833cc).';
        }
      }

      throw Exception(errorMessage);
    }
  }

  /// Sign out current user and clear remember me data if requested
  Future<void> signOut({bool clearRememberMe = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear user-specific last visited route BEFORE signing out (while userId is still available)
      final userId = currentUser?.id;
      if (userId != null) {
        await prefs.remove('${_keyLastVisitedRoute}_$userId');
      }
      // Also clear the legacy key
      await prefs.remove(_keyLastVisitedRoute);

      await _client.auth.signOut();

      if (clearRememberMe) {
        await prefs.remove('remember_me');
        await prefs.remove('stored_email');
        await prefs.remove(_keyRememberMe);
        await prefs.remove(_keyRememberMeEmail);
        await prefs.remove(_keyRememberMeTimestamp);
        await prefs.remove(_keyRememberMeBypassInactivity);
      }
    } catch (error) {
      throw _handleAuthError(error);
    }
  }

  /// Full logout from UI — ends session and clears persisted login preferences.
  Future<void> logout() async {
    await signOut(clearRememberMe: true);
  }

  /// Clear all authentication data (simplified without biometric)
  Future<void> clearAllAuthData() async {
    try {
      await logout();
    } catch (error) {
      print('Error clearing all auth data: $error');
    }
  }

  /// Sign up new user with email and password
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = 'student',
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role},
      );

      return response;
    } catch (error) {
      throw _handleAuthError(error);
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (error) {
      throw _handleAuthError(error);
    }
  }

  /// Update user password
  Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } catch (error) {
      throw _handleAuthError(error);
    }
  }

  /// Get user profile from database with enhanced error handling
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (error) {
      print('Failed to fetch user profile for $userId: $error');

      // For test accounts, try to find by email if ID lookup fails
      try {
        final user = currentUser;
        if (user?.email != null) {
          final emailResponse = await _client
              .from('user_profiles')
              .select()
              .eq('email', user!.email!)
              .maybeSingle();

          if (emailResponse != null) {
            print('Found profile by email lookup: ${user.email}');
            return emailResponse;
          }
        }
      } catch (emailError) {
        print('Email lookup also failed: $emailError');
      }

      throw Exception('Failed to fetch user profile: $error');
    }
  }

  /// DEPRECATED: This method is no longer called during login
  /// Profile updates should only happen through explicit user actions (profile editing)
  /// NOT during authentication
  Future<void> _updateUserProfile(User user) async {
    // This method is kept for backward compatibility but is no longer called during login
    // Profile data should only be read during authentication, never written
    print(
      '⚠️ WARNING: _updateUserProfile called - this should not happen during login',
    );
  }

  /// Get user role from profile with enhanced error handling
  Future<String> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) return 'guest';

      // Enhanced role retrieval with better error handling
      try {
        final roleResult = await _client.rpc('get_user_role');
        if (roleResult != null) {
          return roleResult.toString();
        }
      } catch (functionError) {
        print('get_user_role function failed: $functionError');
        // Fall back to direct table query
      }

      // Enhanced fallback to direct table query with better error handling
      try {
        final profile = await getUserProfile(user.id);
        if (profile != null && profile['role'] != null) {
          return profile['role'].toString();
        }
      } catch (profileError) {
        print('Failed to get profile for role: $profileError');
      }

      // Ultimate fallback - check email patterns for test accounts
      final email = user.email?.toLowerCase() ?? '';
      if (email.contains('admin') ||
          email == 'lutadordeeliteravenna@gmail.com') {
        return 'principal_admin';
      } else if (email.contains('instructor')) {
        return 'instructor';
      } else if (email.contains('student') || email.contains('studente')) {
        return 'student';
      }

      return 'student'; // Default fallback
    } catch (error) {
      print('Error getting user role: $error');
      return 'student'; // Safe fallback
    }
  }

  /// Get current user role - enhanced version with better error handling
  Future<String?> getCurrentUserRole() async {
    try {
      final role = await getUserRole();
      return role == 'guest' ? null : role;
    } catch (error) {
      print('Error getting current user role: $error');
      return null;
    }
  }

  /// Get dashboard route based on user role using Supabase function
  Future<String> getDashboardRouteForCurrentUser() async {
    try {
      final userRole = await getUserRole();
      if (userRole == 'guest') return AppRoutes.login;

      // Use the database function to get the appropriate dashboard route
      final response = await _client.rpc(
        'get_role_dashboard_route',
        params: {'user_role': userRole},
      );

      return response ?? AppRoutes.login;
    } catch (error) {
      print('Error getting dashboard route: $error');
      // Default to login if there's an error
      return AppRoutes.login;
    }
  }

  /// Check if user has admin privileges with enhanced verification
  Future<bool> isAdmin() async {
    try {
      // Try using database function first for more reliable checking
      try {
        final isAdminResult = await _client.rpc('is_admin_level_user');
        if (isAdminResult != null) {
          return isAdminResult == true;
        }
      } catch (functionError) {
        print('is_admin_level_user function failed: $functionError');
        // Fall back to role-based checking
      }

      // Fallback to role-based checking
      final role = await getUserRole();
      return ['admin', 'instructor_admin', 'principal_admin'].contains(role);
    } catch (error) {
      print('Error checking admin status: $error');
      return false;
    }
  }

  /// Check if user is principal admin with enhanced verification
  Future<bool> isPrincipalAdmin() async {
    try {
      // Try using database function first
      try {
        final isPrincipalResult = await _client.rpc('is_principal_admin');
        if (isPrincipalResult != null) {
          return isPrincipalResult == true;
        }
      } catch (functionError) {
        print('is_principal_admin function failed: $functionError');
        // Fall back to role and email checking
      }

      // Fallback to role and email checking
      final user = currentUser;
      if (user == null) return false;

      final role = await getUserRole();
      final isPrincipalByRole = role == 'principal_admin';
      final isPrincipalByEmail =
          user.email?.toLowerCase() == 'lutadordeeliteravenna@gmail.com';

      // ENHANCED: Log the check results for debugging
      print('🔍 Principal admin check:');
      print('  - User email: ${user.email}');
      print('  - User role: $role');
      print('  - Is principal by role: $isPrincipalByRole');
      print('  - Is principal by email: $isPrincipalByEmail');
      print('  - Final result: ${isPrincipalByRole || isPrincipalByEmail}');

      return isPrincipalByRole || isPrincipalByEmail;
    } catch (error) {
      print('Error checking principal admin status: $error');
      return false;
    }
  }

  /// Check if user has instructor privileges
  Future<bool> isInstructor() async {
    try {
      final role = await getUserRole();
      return [
        'instructor',
        'instructor_admin',
        'instructor_student',
        'principal_admin',
      ].contains(role);
    } catch (error) {
      return false;
    }
  }

  /// Get admin verification service
  AdminVerificationService get adminVerification => _adminVerificationService;

  /// Expose biometric service
  BiometricService get biometricService => BiometricService.instance;

  static const String _keyPendingBiometricSetup = 'pending_biometric_setup';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyRememberMeEmail = 'remember_me_email';
  static const String _keyRememberMeTimestamp = 'remember_me_timestamp';
  static const String _keyLastActiveTimestamp =
      'last_active_timestamp'; // Track last activity
  static const String _keyLastVisitedRoute =
      'last_visited_route'; // Track last route for restoration (prefix, suffixed with user id)
  static const String _keyRememberMeBypassInactivity =
      'remember_me_bypass_inactivity'; // Skip 1-hour timeout when Remember Me is active
  static const int _rememberMeDurationDays = 14; // Changed from 30 to 14 days
  static const int _inactivityTimeoutDays = 14; // Changed from 7 to 14 days
  static const int _inactivityTimeoutMinutes = 60; // 1-hour inactivity timeout

  /// Save the last visited route for state restoration
  Future<void> saveLastVisitedRoute(String route) async {
    try {
      // Don't save login screen or initial route
      if (route == AppRoutes.login ||
          route == AppRoutes.initial ||
          route == '/') {
        return;
      }

      final userId = currentUser?.id;
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_keyLastVisitedRoute}_$userId', route);
      print('✅ Last visited route saved for user $userId: $route');
    } catch (error) {
      print('⚠️ Error saving last visited route: $error');
    }
  }

  /// Get the last visited route for state restoration
  Future<String?> getLastVisitedRoute() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString('${_keyLastVisitedRoute}_$userId');
      print('📍 Last visited route retrieved for user $userId: $route');
      return route;
    } catch (error) {
      print('⚠️ Error getting last visited route: $error');
      return null;
    }
  }

  /// Clear the last visited route (called after fresh login)
  Future<void> clearLastVisitedRoute() async {
    try {
      final userId = currentUser?.id;
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        await prefs.remove('${_keyLastVisitedRoute}_$userId');
      } else {
        // Fallback: clear the legacy shared key too
        await prefs.remove(_keyLastVisitedRoute);
      }
      print('🗑️ Last visited route cleared');
    } catch (error) {
      print('⚠️ Error clearing last visited route: $error');
    }
  }

  /// Update last active timestamp
  Future<void> updateLastActiveTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyLastActiveTimestamp, now);
      print(
        '✅ Last active timestamp updated: ${DateTime.fromMillisecondsSinceEpoch(now)}',
      );
    } catch (error) {
      print('⚠️ Error updating last active timestamp: $error');
    }
  }

  /// Check if user session has expired due to 1-hour inactivity.
  /// If the user logged in with "Remember Me" enabled, this timeout is bypassed —
  /// the user stays connected until explicit logout or app update.
  /// Returns true if the user has been inactive for more than 1 hour (and signs them out).
  Future<bool> checkHourlyInactivityTimeout() async {
    try {
      if (!isAuthenticated) return false;

      final prefs = await SharedPreferences.getInstance();

      // Skip the 1-hour inactivity check if "Remember Me" is active
      final bypassInactivity =
          prefs.getBool(_keyRememberMeBypassInactivity) ?? false;
      if (bypassInactivity) {
        print('✅ Remember Me active — skipping 1-hour inactivity timeout');
        // Refresh the timestamp so it stays current
        await updateLastActiveTimestamp();
        return false;
      }

      final lastActiveTimestamp = prefs.getInt(_keyLastActiveTimestamp);

      if (lastActiveTimestamp == null) {
        // No timestamp recorded — update it now and allow access
        await updateLastActiveTimestamp();
        return false;
      }

      final lastActiveDate = DateTime.fromMillisecondsSinceEpoch(
        lastActiveTimestamp,
      );
      final inactiveMinutes =
          DateTime.now().difference(lastActiveDate).inMinutes;

      print('📊 Hourly inactivity check:');
      print('  - Last active: $lastActiveDate');
      print('  - Inactive minutes: $inactiveMinutes');
      print('  - Threshold: $_inactivityTimeoutMinutes minutes');

      if (inactiveMinutes >= _inactivityTimeoutMinutes) {
        print('⏱️ 1-hour inactivity timeout exceeded - forcing logout');
        await signOut(clearRememberMe: false);
        return true;
      }

      print(
        '✅ Session still active (${_inactivityTimeoutMinutes - inactiveMinutes} minutes remaining)',
      );
      return false;
    } catch (error) {
      print('⚠️ Error checking hourly inactivity timeout: $error');
      return false;
    }
  }

  /// Check if user session has expired due to inactivity (14 days)
  Future<bool> checkInactivityTimeout() async {
    try {
      // First, check if Supabase session is still valid
      final currentSession = _client.auth.currentSession;
      if (currentSession != null && !currentSession.isExpired) {
        print('✅ Supabase session is still valid - no inactivity timeout');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;

      // Only check inactivity if "Remember Me" is enabled
      if (!rememberMe) {
        print('⏭️ Remember Me not enabled - skipping inactivity check');
        return false;
      }

      final lastActiveTimestamp = prefs.getInt(_keyLastActiveTimestamp);
      if (lastActiveTimestamp == null) {
        print('⚠️ No last active timestamp found - allowing login');
        return false;
      }

      final lastActiveDate = DateTime.fromMillisecondsSinceEpoch(
        lastActiveTimestamp,
      );
      final inactiveDays = DateTime.now().difference(lastActiveDate).inDays;

      print('📊 Inactivity check:');
      print('  - Last active: $lastActiveDate');
      print('  - Inactive days: $inactiveDays');
      print('  - Threshold: $_inactivityTimeoutDays days');

      if (inactiveDays > _inactivityTimeoutDays) {
        print('⏱️ Inactivity timeout exceeded - forcing logout');
        await signOut(clearRememberMe: true);
        return true; // Session expired due to inactivity
      }

      print('✅ Session still active (within $_inactivityTimeoutDays days)');
      return false;
    } catch (error) {
      print('⚠️ Error checking inactivity timeout: $error');
      return false;
    }
  }

  /// Retrieve any pending biometric setup payload saved during login
  Future<Map<String, dynamic>?> getPendingBiometricSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyPendingBiometricSetup);
      if (jsonString == null || jsonString.isEmpty) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (error) {
      print('Error reading pending biometric setup: $error');
      return null;
    }
  }

  /// Clear pending biometric setup payload
  Future<void> clearPendingBiometricSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPendingBiometricSetup);
    } catch (error) {
      print('Error clearing pending biometric setup: $error');
    }
  }

  /// Enable biometric authentication for the current user
  Future<bool> enableBiometricAuth() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final String email = user.email ?? '';
      if (email.isEmpty) return false;

      // Resolve full name from profile or user metadata
      String fullName = user.userMetadata?['full_name'] ??
          (await getUserProfile(user.id))?['full_name'] ??
          email.split('@').first;

      await BiometricService.instance.enableBiometricForUser(
        email,
        fullName: fullName,
      );
      return true;
    } catch (error) {
      print('Error enabling biometric auth: $error');
      return false;
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Initialize auth state listener with session refresh
  void initAuthListener() {
    onAuthStateChange.listen((AuthState data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session?.user != null) {
            print('🔐 User signed in - reading existing profile data only');
            // REMOVED: No longer calling _updateUserProfile during sign-in
            // Authentication should only read existing data, never modify it
            updateLastActiveTimestamp();
          }
          break;
        case AuthChangeEvent.signedOut:
          print('🔓 User signed out');
          break;
        case AuthChangeEvent.tokenRefreshed:
          print('🔄 Session token refreshed');
          print(
            '   - New expiry: ${DateTime.fromMillisecondsSinceEpoch(session!.expiresAt! * 1000)}',
          );
          updateLastActiveTimestamp();
          break;
        default:
          break;
      }
    });
  }

  /// Handle authentication errors
  String _handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.statusCode) {
        case '400':
          return 'Credenziali non valide. Verifica email e password.';
        case '422':
          return 'Email non valida. Inserisci un indirizzo email corretto.';
        case '429':
          return 'Troppi tentativi. Riprova tra qualche minuto.';
        case '500':
          return 'Errore del server. Riprova più tardi.';
        default:
          // ENHANCED: Better handling of specific auth error messages
          if (error.message.toLowerCase().contains(
                'invalid login credentials',
              )) {
            return 'Credenziali non valide. Verifica email e password.';
          } else if (error.message.toLowerCase().contains(
                'invalid email or password',
              )) {
            return 'Credenziali non valide. Verifica email e password.';
          } else if (error.message.toLowerCase().contains(
                'email not confirmed',
              )) {
            return 'Email non confermata. Controlla la tua casella di posta.';
          }
          return error.message;
      }
    }

    // Handle custom error messages from our verification functions
    final errorString = error.toString();
    if (errorString.contains('Exception:')) {
      return errorString.replaceAll('Exception:', '').trim();
    }

    return 'Errore di connessione. Verifica la tua connessione internet.';
  }

  /// Show error toast
  void showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.errorLight,
      textColor: Colors.white,
    );
  }

  /// Show success toast
  void showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppTheme.successLight,
      textColor: Colors.white,
    );
  }
}
