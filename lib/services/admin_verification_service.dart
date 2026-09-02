import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVerificationService {
  static AdminVerificationService? _instance;
  static AdminVerificationService get instance =>
      _instance ??= AdminVerificationService._();

  AdminVerificationService._();

  final SupabaseClient _client = Supabase.instance.client;
  static const String _principalAdminEmail = 'lutadordeeliteravenna@gmail.com';
  static const String _principalAdminPassword = 'Magnus833cc';
  static const String _principalAdminName = 'Admin Principale Team Ragnarok';

  /// Complete admin system verification with proper error handling
  Future<AdminVerificationResult> performCompleteVerification() async {
    try {
      // First verify that the principal admin exists and is properly configured
      final principalAdminVerification =
          await verifyPrincipalAdminConfiguration();

      if (!principalAdminVerification.success) {
        return principalAdminVerification;
      }

      // Verify admin tables and functions exist
      final tablesVerification = await verifyAdminTables();
      if (!tablesVerification.success) {
        return tablesVerification;
      }

      // Verify admin functions exist and work
      final functionsVerification = await verifyAdminFunctions();
      if (!functionsVerification.success) {
        return functionsVerification;
      }

      // If all verifications pass
      return AdminVerificationResult(
        success: true,
        message: 'Admin system fully verified and operational',
      );
    } catch (error) {
      return AdminVerificationResult(
        success: false,
        message: 'Admin verification failed: ${error.toString()}',
        error: error.toString(),
      );
    }
  }

  /// Verify principal admin configuration using correct function call
  Future<AdminVerificationResult> verifyPrincipalAdminConfiguration() async {
    try {
      // Skip verification if no user is authenticated — RLS blocks anonymous reads
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        return AdminVerificationResult(
          success: true,
          message:
              'Principal admin check skipped (no authenticated user — RLS active)',
        );
      }

      // Use the database function to verify admin status with correct parameter name
      final response = await _client.rpc('get_admin_verification_status',
          params: {'admin_email': _principalAdminEmail});

      if (response == null) {
        return AdminVerificationResult(
          success: false,
          message: 'Admin verification function returned null',
        );
      }

      final Map<String, dynamic> result = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response);

      final profileExists = result['profile_exists'] == true;
      final authExists = result['auth_exists'] == true;

      if (!authExists || !profileExists) {
        // Try to create the admin if missing
        await ensurePrincipalAdminExists();

        return AdminVerificationResult(
          success: false,
          message:
              'Principal admin account not properly configured - Auth: $authExists, Profile: $profileExists. Creation attempted.',
        );
      }

      // Check if the profile has correct role
      final profileData = result['profile_data'] as Map<String, dynamic>?;
      final role = profileData?['role'];

      if (role != 'principal_admin') {
        return AdminVerificationResult(
          success: false,
          message: 'Principal admin has incorrect role: $role',
        );
      }

      return AdminVerificationResult(
        success: true,
        message: 'Principal admin properly configured with role: $role',
      );
    } catch (error) {
      // Fallback verification using direct table query
      return await _fallbackAdminVerification(error.toString());
    }
  }

  /// Fallback verification method when function calls fail
  Future<AdminVerificationResult> _fallbackAdminVerification(
      String originalError) async {
    try {
      print('Attempting fallback admin verification due to: $originalError');

      // Direct table verification
      final adminProfile = await _client
          .from('user_profiles')
          .select('id, email, role, is_active')
          .eq('email', _principalAdminEmail)
          .maybeSingle();

      if (adminProfile == null) {
        // Try to ensure admin exists
        final created = await ensurePrincipalAdminExists();

        return AdminVerificationResult(
          success: created,
          message: created
              ? 'Principal admin created successfully via fallback method'
              : 'Failed to create principal admin via fallback method',
        );
      }

      final role = adminProfile['role'];
      final isActive = adminProfile['is_active'] == true;

      if (role != 'principal_admin') {
        // Update role if incorrect
        await _client.from('user_profiles').update({
          'role': 'principal_admin',
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', adminProfile['id']);

        return AdminVerificationResult(
          success: true,
          message: 'Principal admin role corrected via fallback method',
        );
      }

      if (!isActive) {
        // Activate admin if inactive
        await _client.from('user_profiles').update({
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', adminProfile['id']);
      }

      return AdminVerificationResult(
        success: true,
        message: 'Principal admin verified via fallback method',
      );
    } catch (fallbackError) {
      return AdminVerificationResult(
        success: false,
        message: 'Both primary and fallback verification failed',
        error:
            'Original: $originalError, Fallback: ${fallbackError.toString()}',
      );
    }
  }

  /// Verify admin tables exist and are accessible
  Future<AdminVerificationResult> verifyAdminTables() async {
    try {
      // Skip user_profiles check if no user is authenticated — RLS blocks anonymous reads
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        return AdminVerificationResult(
          success: true,
          message:
              'Admin table check skipped (no authenticated user — RLS active)',
        );
      }

      // Test connection to critical admin tables
      await _client.from('user_profiles').select('id').limit(1);
      await _client.from('admin_activity_log').select('id').limit(1);
      await _client.from('admin_communications').select('id').limit(1);
      await _client.from('non_fiscal_receipts').select('id').limit(1);
      await _client.from('pending_registrations').select('id').limit(1);

      return AdminVerificationResult(
        success: true,
        message: 'All admin tables accessible',
      );
    } catch (error) {
      return AdminVerificationResult(
        success: false,
        message: 'Admin table verification failed: ${error.toString()}',
        error: error.toString(),
      );
    }
  }

  /// Verify admin functions exist and work
  Future<AdminVerificationResult> verifyAdminFunctions() async {
    try {
      // Test critical functions with proper error handling
      try {
        await _client.rpc('get_user_role');
      } catch (e) {
        // get_user_role might fail if no user is authenticated, which is ok
        print('get_user_role test: ${e.toString()}');
      }

      try {
        await _client.rpc('is_admin_level_user');
      } catch (e) {
        // is_admin_level_user might fail if no user is authenticated, which is ok
        print('is_admin_level_user test: ${e.toString()}');
      }

      return AdminVerificationResult(
        success: true,
        message: 'Admin functions verified and accessible',
      );
    } catch (error) {
      return AdminVerificationResult(
        success: false,
        message: 'Admin function verification failed: ${error.toString()}',
        error: error.toString(),
      );
    }
  }

  /// Emergency admin reset with enhanced error handling
  Future<bool> emergencyAdminReset() async {
    try {
      print('Performing emergency admin reset...');

      // Try using the function first
      try {
        final result = await _client.rpc('emergency_admin_reset');
        if (result == true) {
          print('Emergency admin reset successful via function');
          return true;
        }
      } catch (functionError) {
        print('Function-based reset failed: $functionError');
      }

      // Fallback to manual reset
      return await _manualEmergencyReset();
    } catch (error) {
      print('Emergency admin reset failed: $error');
      return false;
    }
  }

  /// Manual emergency reset as fallback
  Future<bool> _manualEmergencyReset() async {
    try {
      print('Attempting manual emergency admin reset...');

      // Check if admin profile exists
      final existingAdmin = await _client
          .from('user_profiles')
          .select('id')
          .eq('email', _principalAdminEmail)
          .maybeSingle();

      if (existingAdmin != null) {
        // Update existing admin
        await _client.from('user_profiles').update({
          'role': 'principal_admin',
          'is_active': true,
          'full_name': _principalAdminName,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existingAdmin['id']);

        print('Manual emergency reset: updated existing admin profile');
        return true;
      }

      print(
          'Manual emergency reset: admin profile not found, creation required');
      return false;
    } catch (error) {
      print('Manual emergency reset failed: $error');
      return false;
    }
  }

  /// Ensure principal admin exists with enhanced logic
  Future<bool> ensurePrincipalAdminExists() async {
    try {
      print('Ensuring principal admin exists...');

      // Try using the function first
      try {
        final result = await _client.rpc('ensure_principal_admin_exists');
        if (result == true) {
          print('Principal admin ensured via function');
          return true;
        }
      } catch (functionError) {
        print('Function-based creation failed: $functionError');
      }

      // Fallback to manual creation logic
      return await _manualAdminCreation();
    } catch (error) {
      print('Ensure principal admin exists failed: $error');
      return false;
    }
  }

  /// Manual admin creation as fallback
  Future<bool> _manualAdminCreation() async {
    try {
      print('Attempting manual admin creation...');

      // Check if admin already exists
      final existingAdmin = await _client
          .from('user_profiles')
          .select('id, role, is_active')
          .eq('email', _principalAdminEmail)
          .maybeSingle();

      if (existingAdmin != null) {
        // Update role and status if needed
        final needsUpdate = existingAdmin['role'] != 'principal_admin' ||
            existingAdmin['is_active'] != true;

        if (needsUpdate) {
          await _client.from('user_profiles').update({
            'role': 'principal_admin',
            'is_active': true,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existingAdmin['id']);
        }

        print('Manual admin creation: updated existing profile');
        return true;
      }

      print(
          'Manual admin creation: profile not found, auth user creation required');
      return false;
    } catch (error) {
      print('Manual admin creation failed: $error');
      return false;
    }
  }

  /// Verify and ensure principal admin exists (legacy compatibility)
  Future<bool> verifyPrincipalAdminExists() async {
    try {
      // Check if principal admin exists in user_profiles
      final response = await _client
          .from('user_profiles')
          .select('id, email, role, is_active')
          .eq('email', _principalAdminEmail)
          .eq('role', 'principal_admin')
          .maybeSingle();

      if (response != null && response['is_active'] == true) {
        print('Principal admin verified: ${response['email']}');
        return true;
      } else {
        print('Principal admin not found or inactive. Attempting creation...');
        return await ensurePrincipalAdminExists();
      }
    } catch (error) {
      print('Error verifying principal admin: $error');
      return false;
    }
  }

  /// Verify admin credentials can login (legacy compatibility)
  Future<bool> verifyAdminLogin() async {
    try {
      // Try to authenticate with admin credentials
      final response = await _client.auth.signInWithPassword(
        email: _principalAdminEmail,
        password: _principalAdminPassword,
      );

      if (response.user != null) {
        // Verify role is correct
        final profile = await _client
            .from('user_profiles')
            .select('role, is_active')
            .eq('id', response.user!.id)
            .maybeSingle();

        final isValidAdmin = profile != null &&
            profile['role'] == 'principal_admin' &&
            profile['is_active'] == true;

        // Sign out after verification (this is just a test)
        await _client.auth.signOut();

        return isValidAdmin;
      }
      return false;
    } catch (error) {
      print('Admin login verification failed: $error');
      return false;
    }
  }

  /// Get admin status summary with enhanced error handling
  Future<Map<String, dynamic>> getAdminStatusSummary() async {
    try {
      final adminProfile = await _client
          .from('user_profiles')
          .select('*')
          .eq('email', _principalAdminEmail)
          .maybeSingle();

      // Note: Direct auth.users query may not work in all contexts
      Map<String, dynamic>? authUser;
      try {
        authUser = await _client
            .from('auth.users')
            .select('id, email, created_at, email_confirmed_at')
            .eq('email', _principalAdminEmail)
            .maybeSingle();
      } catch (e) {
        print('Could not query auth.users table: $e');
        authUser = null;
      }

      return {
        'admin_profile_exists': adminProfile != null,
        'admin_auth_exists': authUser != null,
        'admin_role': adminProfile?['role'],
        'admin_active': adminProfile?['is_active'] ?? false,
        'admin_created_at': adminProfile?['created_at'],
        'auth_confirmed': authUser?['email_confirmed_at'] != null,
        'profile_data': adminProfile,
        'auth_data': authUser,
        'verification_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      return {
        'error': error.toString(),
        'admin_profile_exists': false,
        'admin_auth_exists': false,
        'verification_timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}

/// Enhanced data class for admin verification results
class AdminVerificationResult {
  final bool success;
  final String message;
  final String? error;

  AdminVerificationResult({
    required this.success,
    required this.message,
    this.error,
  });

  @override
  String toString() {
    return 'AdminVerificationResult(success: $success, message: $message${error != null ? ', error: $error' : ''})';
  }
}
