import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static BiometricService? _instance;
  static BiometricService get instance => _instance ??= BiometricService._();

  BiometricService._();

  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyBiometricUserData = 'biometric_user_data';
  static const String _keyLastBiometricUser = 'last_biometric_user';

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on device
  Future<bool> isAvailable() async {
    if (kIsWeb) {
      return false; // Biometrics not available on web
    }

    try {
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        return false;
      }

      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      return canCheckBiometrics;
    } catch (e) {
      print('Biometric availability check failed: ${e.toString()}');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<String>> getAvailableBiometrics() async {
    if (kIsWeb) {
      return []; // No biometrics on web
    }

    try {
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      return availableBiometrics.map((type) => type.name).toList();
    } catch (e) {
      print('Failed to get available biometrics: ${e.toString()}');
      return [];
    }
  }

  /// Perform biometric authentication
  Future<bool> authenticate({
    required String reason,
    bool stickyAuth = false,
  }) async {
    if (kIsWeb) {
      return false; // Cannot authenticate on web
    }

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: stickyAuth,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      print('Biometric authentication error: ${e.toString()}');

      // Handle specific error cases
      if (e.toString().contains(auth_error.notAvailable)) {
        print('Biometric authentication not available');
      } else if (e.toString().contains(auth_error.notEnrolled)) {
        print('No biometric credentials enrolled');
      } else if (e.toString().contains(auth_error.lockedOut)) {
        print('Biometric authentication locked out');
      }

      return false;
    }
  }

  /// Check if biometric authentication is enabled for the current user
  Future<bool> isBiometricEnabledForUser(String userEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final biometricData = prefs.getString(_keyBiometricUserData);

      if (biometricData == null) return false;

      final Map<String, dynamic> userData = jsonDecode(biometricData);
      return userData[userEmail] == true;
    } catch (e) {
      print('Error checking biometric enabled for user: $e');
      return false;
    }
  }

  /// Enable biometric authentication for a user
  Future<void> enableBiometricForUser(
    String userEmail, {
    required String fullName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Update biometric enabled status
      await prefs.setBool(_keyBiometricEnabled, true);

      // Save user-specific biometric data
      final existingData = prefs.getString(_keyBiometricUserData);
      Map<String, dynamic> userData = {};

      if (existingData != null) {
        userData = jsonDecode(existingData);
      }

      userData[userEmail] = true;
      await prefs.setString(_keyBiometricUserData, jsonEncode(userData));

      // Save last biometric user info
      await prefs.setString(
          _keyLastBiometricUser,
          jsonEncode({
            'email': userEmail,
            'fullName': fullName,
            'enabledAt': DateTime.now().toIso8601String(),
          }));

      print('✅ Biometric authentication enabled for user: $userEmail');
    } catch (e) {
      print('❌ Error enabling biometric for user: $e');
      rethrow;
    }
  }

  /// Disable biometric authentication for a user
  Future<void> disableBiometricForUser(String userEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Update user-specific biometric data
      final existingData = prefs.getString(_keyBiometricUserData);
      if (existingData != null) {
        final Map<String, dynamic> userData = jsonDecode(existingData);
        userData[userEmail] = false;
        await prefs.setString(_keyBiometricUserData, jsonEncode(userData));
      }

      // Check if any user still has biometric enabled
      final biometricData = prefs.getString(_keyBiometricUserData);
      bool anyUserHasBiometric = false;

      if (biometricData != null) {
        final Map<String, dynamic> userData = jsonDecode(biometricData);
        anyUserHasBiometric = userData.values.any((enabled) => enabled == true);
      }

      // If no users have biometric enabled, disable globally
      if (!anyUserHasBiometric) {
        await prefs.setBool(_keyBiometricEnabled, false);
        await prefs.remove(_keyLastBiometricUser);
      }

      print('✅ Biometric authentication disabled for user: $userEmail');
    } catch (e) {
      print('❌ Error disabling biometric for user: $e');
      rethrow;
    }
  }

  /// Get the last user who enabled biometric authentication
  Future<Map<String, dynamic>?> getLastBiometricUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUserData = prefs.getString(_keyLastBiometricUser);

      if (lastUserData == null) return null;

      return jsonDecode(lastUserData);
    } catch (e) {
      print('Error getting last biometric user: $e');
      return null;
    }
  }

  /// Check if biometric is globally enabled
  Future<bool> isBiometricGloballyEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyBiometricEnabled) ?? false;
    } catch (e) {
      print('Error checking global biometric status: $e');
      return false;
    }
  }

  /// Clear all biometric data (useful for logout)
  Future<void> clearBiometricData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBiometricEnabled);
      await prefs.remove(_keyBiometricUserData);
      await prefs.remove(_keyLastBiometricUser);

      print('✅ All biometric data cleared');
    } catch (e) {
      print('❌ Error clearing biometric data: $e');
    }
  }

  /// Perform quick biometric login for returning users
  Future<Map<String, dynamic>?> quickBiometricLogin() async {
    try {
      if (!(await isAvailable())) {
        return null;
      }

      if (!(await isBiometricGloballyEnabled())) {
        return null;
      }

      final lastUser = await getLastBiometricUser();
      if (lastUser == null) {
        return null;
      }

      final userEmail = lastUser['email'] as String;
      final isEnabledForUser = await isBiometricEnabledForUser(userEmail);

      if (!isEnabledForUser) {
        return null;
      }

      // Perform biometric authentication
      final authenticated = await authenticate(
        reason: 'Accedi con ${lastUser['fullName']}',
        stickyAuth: true,
      );

      if (authenticated) {
        return {
          'email': userEmail,
          'fullName': lastUser['fullName'],
          'authenticatedAt': DateTime.now().toIso8601String(),
        };
      }

      return null;
    } catch (e) {
      print('Error in quick biometric login: $e');
      return null;
    }
  }

  /// Get biometric settings summary for debugging
  Future<Map<String, dynamic>> getBiometricDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAvailableOnDevice = await isAvailable();
      final availableBiometrics = await getAvailableBiometrics();
      final globallyEnabled = await isBiometricGloballyEnabled();
      final lastUser = await getLastBiometricUser();
      final userData = prefs.getString(_keyBiometricUserData);

      return {
        'isAvailableOnDevice': isAvailableOnDevice,
        'availableBiometrics': availableBiometrics,
        'globallyEnabled': globallyEnabled,
        'lastUser': lastUser,
        'userBiometricData': userData != null ? jsonDecode(userData) : null,
        'platform': kIsWeb ? 'web' : 'mobile',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'platform': kIsWeb ? 'web' : 'mobile',
      };
    }
  }
}
