import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // SharedPreferences only ever stores flags/metadata here — never the
  // password. The declined-setup map remembers, per email, that the user
  // picked "Non chiedermelo più" on the post-login prompt.
  static const String _keyDeclinedSetup = 'biometric_declined_setup';

  // Encrypted, on-device only (Android Keystore via flutter_secure_storage)
  // — this is the ONLY place the login password is ever persisted.
  static const String _secureKeyEmail = 'biometric_login_email';
  static const String _secureKeyPassword = 'biometric_login_password';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Single normalization point for every email used as a storage key
  /// below — trims it and lowercases it, so "Name@Example.com" (e.g. the
  /// keyboard's auto-capitalized first letter at login) and
  /// "name@example.com" (SupabaseService's currentUser?.email, already
  /// lowercase) always resolve to the same key.
  String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Reads a JSON-encoded {email: value} map from prefs[storageKey] and
  /// resolves [normalizedEmail] against its keys case-insensitively —
  /// data saved before this normalization existed may still have a
  /// differently-cased key. When such a stale key is found, it's migrated
  /// to the normalized key (in the returned map and back into storage)
  /// so every later lookup hits it directly.
  Future<Map<String, dynamic>> _loadEmailKeyedMap(
    SharedPreferences prefs,
    String storageKey,
    String normalizedEmail,
  ) async {
    final raw = prefs.getString(storageKey);
    if (raw == null) return {};

    Map<String, dynamic> map;
    try {
      map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }

    if (map.containsKey(normalizedEmail)) return map;

    String? staleKey;
    for (final key in map.keys) {
      if (key.toLowerCase() == normalizedEmail) {
        staleKey = key;
        break;
      }
    }
    if (staleKey != null) {
      map[normalizedEmail] = map.remove(staleKey);
      await prefs.setString(storageKey, jsonEncode(map));
    }
    return map;
  }

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
      final email = _normalizeEmail(userEmail);
      final prefs = await SharedPreferences.getInstance();
      final userData = await _loadEmailKeyedMap(
        prefs,
        _keyBiometricUserData,
        email,
      );
      return userData[email] == true;
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
      final email = _normalizeEmail(userEmail);
      final prefs = await SharedPreferences.getInstance();

      // Update biometric enabled status
      await prefs.setBool(_keyBiometricEnabled, true);

      // Save user-specific biometric data
      final userData = await _loadEmailKeyedMap(
        prefs,
        _keyBiometricUserData,
        email,
      );
      userData[email] = true;
      await prefs.setString(_keyBiometricUserData, jsonEncode(userData));

      // Save last biometric user info
      await prefs.setString(
          _keyLastBiometricUser,
          jsonEncode({
            'email': email,
            'fullName': fullName,
            'enabledAt': DateTime.now().toIso8601String(),
          }));

      print('✅ Biometric authentication enabled for user: $email');
    } catch (e) {
      print('❌ Error enabling biometric for user: $e');
      rethrow;
    }
  }

  /// Enable fingerprint login: saves the email/password in the encrypted,
  /// on-device-only secure storage (Android Keystore) and sets the usual
  /// per-user flag above. This is the only path that ever writes a
  /// password anywhere — never in SharedPreferences, never in plain text.
  Future<void> enableBiometricLogin({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await saveCredentials(email: email, password: password);
    await enableBiometricForUser(email, fullName: fullName);
  }

  /// Disable biometric authentication for a user
  Future<void> disableBiometricForUser(String userEmail) async {
    try {
      final email = _normalizeEmail(userEmail);
      final prefs = await SharedPreferences.getInstance();

      // Update user-specific biometric data
      final hadExistingData = prefs.getString(_keyBiometricUserData) != null;
      final userData = await _loadEmailKeyedMap(
        prefs,
        _keyBiometricUserData,
        email,
      );
      if (hadExistingData) {
        userData[email] = false;
        await prefs.setString(_keyBiometricUserData, jsonEncode(userData));
      }

      // If no users have biometric enabled, disable globally
      final anyUserHasBiometric = userData.values.any(
        (enabled) => enabled == true,
      );
      if (!anyUserHasBiometric) {
        await prefs.setBool(_keyBiometricEnabled, false);
        await prefs.remove(_keyLastBiometricUser);
      }

      // Always drop the saved credentials for this user — biometric login
      // being off means there is nothing left that should use them.
      await clearStoredCredentials();

      print('✅ Biometric authentication disabled for user: $email');
    } catch (e) {
      print('❌ Error disabling biometric for user: $e');
      rethrow;
    }
  }

  /// Saves the login credentials in the encrypted secure storage. Only one
  /// account's credentials are kept on the device at a time.
  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(
      key: _secureKeyEmail,
      value: _normalizeEmail(email),
    );
    await _secureStorage.write(key: _secureKeyPassword, value: password);
  }

  /// Reads the saved login credentials, or null if none are stored.
  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final email = await _secureStorage.read(key: _secureKeyEmail);
      final password = await _secureStorage.read(key: _secureKeyPassword);
      if (email == null || email.isEmpty || password == null || password.isEmpty) {
        return null;
      }
      return {'email': email, 'password': password};
    } catch (e) {
      print('Error reading stored biometric credentials: $e');
      return null;
    }
  }

  /// Removes the saved login credentials from the secure storage.
  Future<void> clearStoredCredentials() async {
    try {
      await _secureStorage.delete(key: _secureKeyEmail);
      await _secureStorage.delete(key: _secureKeyPassword);
    } catch (e) {
      print('Error clearing stored biometric credentials: $e');
    }
  }

  /// Whether the user picked "Non chiedermelo più" on the post-login
  /// biometric setup prompt for this email.
  Future<bool> hasDeclinedSetupForever(String userEmail) async {
    try {
      final email = _normalizeEmail(userEmail);
      final prefs = await SharedPreferences.getInstance();
      final declined = await _loadEmailKeyedMap(
        prefs,
        _keyDeclinedSetup,
        email,
      );
      return declined[email] == true;
    } catch (e) {
      print('Error reading declined biometric setup flag: $e');
      return false;
    }
  }

  /// Remembers that the user picked "Non chiedermelo più" for this email.
  Future<void> declineSetupForever(String userEmail) async {
    try {
      final email = _normalizeEmail(userEmail);
      final prefs = await SharedPreferences.getInstance();
      final declined = await _loadEmailKeyedMap(
        prefs,
        _keyDeclinedSetup,
        email,
      );
      declined[email] = true;
      await prefs.setString(_keyDeclinedSetup, jsonEncode(declined));
    } catch (e) {
      print('Error saving declined biometric setup flag: $e');
    }
  }

  /// Whether the post-login "enable fingerprint login?" prompt should be
  /// shown for this email: biometric hardware available with at least one
  /// fingerprint/face enrolled, not already enabled for this account, and
  /// the user hasn't picked "Non chiedermelo più" before.
  Future<bool> shouldOfferSetup(String userEmail) async {
    if (!(await isAvailable())) return false;
    final availableBiometrics = await getAvailableBiometrics();
    if (availableBiometrics.isEmpty) return false;
    if (await isBiometricEnabledForUser(userEmail)) return false;
    if (await hasDeclinedSetupForever(userEmail)) return false;
    return true;
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
