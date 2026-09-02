import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and restores the user's selected app language.
class LocaleService {
  LocaleService._();

  static const String storageKey = 'app_locale_code';
  static const Locale defaultLocale = Locale('it');
  static const List<Locale> supportedLocales = [
    Locale('it'),
    Locale('en'),
  ];

  static Future<Locale?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(storageKey);
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, locale.languageCode);
  }

  static String languageLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'it':
      default:
        return 'Italiano';
    }
  }
}
