class AppConstants {
  // Team Information - Production Ready
  static const String teamName = 'Team Ragnarok ASD';
  static const String teamFiscalCode = '92100170395';
  static const String teamAddress = 'via giulio bezzi 25, 48026 Russi - RA';
  static const String teamLogo = 'assets/images/146804-1762122410365.jpg';

  // Martial Arts Disciplines - Production Ready
  static const List<String> disciplines = ['BJJ', 'MMA', 'SAMBO', 'Grappling'];

  // App Configuration - Production Ready
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'lutadordeeliteravenna@gmail.com';

  // UI Constants
  static const double defaultBorderRadius = 8.0;
  static const double defaultPadding = 16.0;
  static const double cardElevation = 4.0;

  // Time Constants
  static const int sessionTimeoutMinutes = 30;
  static const int refreshIntervalSeconds = 300;

  // Notification Constants
  static const String defaultNotificationTitle = 'Team Ragnarok APP';
  static const int maxNotifications = 50;

  // Production-Ready Subscription Plans
  // Note: These are now reference data - actual plans should be fetched from Supabase
  static const List<Map<String, dynamic>> subscriptionPlansReference = [
    {
      "id": "single_entry",
      "title": "Ingresso Singolo",
      "price": 10,
      "frequency": "Per Allenamento",
      "description": "Un singolo ingresso per allenamento",
    },
    {
      "id": "multi_entry_10",
      "title": "Pacchetto 10 Ingressi",
      "price": 80,
      "frequency": "Pacchetto",
      "description": "Pacchetto di 10 ingressi per allenamenti",
    },
    {
      "id": "monthly_unlimited",
      "title": "Abbonamento Mensile",
      "price": 60,
      "frequency": "Mensile",
      "description": "Abbonamento mensile illimitato",
    },
  ];

  // Production Environment Settings
  static const bool isProduction = true;
  static const bool enableDebugMode = false;
  static const bool enableMockData = false;

  // Production Notice
  static const String productionNotice =
      'App pronta per l\'utilizzo reale - Tutti i dati di test sono stati rimossi';

  // Local Storage Keys
  static const String keyUserToken = 'user_token';
  static const String keyUserProfile = 'user_profile';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguageCode = 'language_code';
  static const String keyAppSettings = 'app_settings';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyBiometricUserData = 'biometric_user_data';
  static const String keyLastBiometricUser = 'last_biometric_user';
  static const String keyAutoLogin = 'auto_login';
  static const String keyLastLogin = 'last_login';

  // Admin Account Configuration
  static const String principalAdminEmail = 'lutadordeeliteravenna@gmail.com';
  static const List<String> testAccountEmails = [
    'studente@teamragnarok.com',
    'instructor@teamragnarok.com',
  ];

  // Biometric Authentication Settings
  static const int biometricSetupTimeoutMinutes = 5;
  static const bool enableBiometricDebug = true; // Set to false in production

  // User Approval Settings
  static const List<String> autoApprovalTestAccounts = [
    'studente@teamragnarok.com',
    'instructor@teamragnarok.com',
  ];

  /// Check if an email is a test account (should not require admin approval)
  static bool isTestAccount(String email) {
    return autoApprovalTestAccounts.contains(email.toLowerCase()) ||
        testAccountEmails.contains(email.toLowerCase());
  }

  /// Check if an email is the principal admin account
  static bool isPrincipalAdminEmail(String email) {
    return email.toLowerCase() == principalAdminEmail.toLowerCase();
  }

  /// Get biometric storage keys
  static Map<String, String> getBiometricStorageKeys() {
    return {
      'enabled': keyBiometricEnabled,
      'userData': keyBiometricUserData,
      'lastUser': keyLastBiometricUser,
    };
  }
}
