import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  // Fallback used only when the app is built without --dart-define values,
  // so Supabase.initialize() always succeeds and Supabase.instance never
  // throws (AuthService reads Supabase.instance.client eagerly at startup —
  // leaving Supabase uninitialized crashes the app before the first frame).
  static const String _placeholderUrl = 'https://placeholder.supabase.co';
  static const String _placeholderAnonKey = 'placeholder-anon-key';

  // Initialize Supabase - call this in main()
  static Future<void> initialize() async {
    final missingCredentials = supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;
    if (missingCredentials) {
      // ignore: avoid_print
      print(
          '⚠️ SUPABASE_URL/SUPABASE_ANON_KEY not provided via --dart-define. '
          'Initializing with placeholder credentials; backend features will '
          'not work until real values are configured.');
    }

    await Supabase.initialize(
      url: missingCredentials ? _placeholderUrl : supabaseUrl,
      anonKey: missingCredentials ? _placeholderAnonKey : supabaseAnonKey,
    );
  }

  // Get Supabase client
  SupabaseClient get client => Supabase.instance.client;

  // Get current user ID
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }
}
