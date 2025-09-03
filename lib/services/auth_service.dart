import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_export.dart';
import '../theme/app_theme.dart';
import './admin_verification_service.dart';

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

  /// Initialize authentication system with admin verification
  Future<void> initializeAuthSystem() async {
    try {
      print('Initializing authentication system...');

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

      // Initialize auth listener
      initAuthListener();

      print('Authentication system initialization completed');
    } catch (error) {
      print('Error initializing authentication system: $error');
    }
  }

  /// Sign in with email and password (with admin verification)
  Future<AuthResponse?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _updateUserProfile(response.user!);

        // Special handling for principal admin
        if (email.toLowerCase() == 'lutadordeeliteravenna@gmail.com') {
          print('Principal admin login detected - verifying permissions');

          final userRole = await getUserRole();
          if (userRole != 'principal_admin') {
            print(
              'WARNING: Principal admin email logged in but role is: $userRole',
            );

            // Force update role to principal_admin
            await _client.from('user_profiles').update({
              'role': 'principal_admin',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', response.user!.id);

            print('Updated user role to principal_admin');
          }
        }
      }

      return response;
    } catch (error) {
      throw _handleAuthError(error);
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

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
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

  /// Get user profile from database
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (error) {
      throw Exception('Failed to fetch user profile: $error');
    }
  }

  /// Update user profile in database
  Future<void> _updateUserProfile(User user) async {
    try {
      final existingProfile = await getUserProfile(user.id);

      if (existingProfile == null) {
        // Create new profile if doesn't exist
        await _client.from('user_profiles').insert({
          'id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ??
              user.email?.split('@')[0] ??
              'User',
          'role': user.userMetadata?['role'] ?? 'student',
          'is_active': true,
        });
      } else {
        // Update existing profile
        await _client.from('user_profiles').update({
          'email': user.email ?? existingProfile['email'],
          'full_name':
              user.userMetadata?['full_name'] ?? existingProfile['full_name'],
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }
    } catch (error) {
      // Log error but don't throw - profile creation/update is not critical for auth
      print('Profile update error: $error');
    }
  }

  /// Get user role from profile with enhanced error handling
  Future<String> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) return 'guest';

      // Try using database function first
      try {
        final roleResult = await _client.rpc('get_user_role');
        if (roleResult != null) {
          return roleResult.toString();
        }
      } catch (functionError) {
        print('get_user_role function failed: $functionError');
        // Fall back to direct table query
      }

      // Fallback to direct table query
      final profile = await getUserProfile(user.id);
      return profile?['role']?.toString() ?? 'student';
    } catch (error) {
      print('Error getting user role: $error');
      return 'student';
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
        'principal_admin',
      ].contains(role);
    } catch (error) {
      return false;
    }
  }

  /// Get admin verification service
  AdminVerificationService get adminVerification => _adminVerificationService;

  /// Listen to auth state changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Initialize auth state listener
  void initAuthListener() {
    onAuthStateChange.listen((AuthState data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session?.user != null) {
            _updateUserProfile(session!.user);
          }
          break;
        case AuthChangeEvent.signedOut:
          // Handle sign out cleanup if needed
          break;
        case AuthChangeEvent.tokenRefreshed:
          // Handle token refresh if needed
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
          return error.message;
      }
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
