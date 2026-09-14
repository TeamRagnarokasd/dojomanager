import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Holds the update information fetched from the remote `app_version` table.
class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String releaseNotes;
  final bool mandatory;

  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.releaseNotes,
    required this.mandatory,
  });
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String _confirmedVersionKey = 'confirmed_version_code';

  /// Saves the given [versionCode] as the locally confirmed version.
  /// Call this right after a successful APK download, before launching the
  /// install intent.
  Future<void> saveConfirmedVersionCode(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_confirmedVersionKey, versionCode);
  }

  /// Checks whether a newer APK is available on the server.
  ///
  /// Returns [AppUpdateInfo] when a newer version exists, or `null` when the
  /// app is already up-to-date or the check cannot be performed.
  ///
  /// Must only be called on Android (i.e. when `!kIsWeb`).
  Future<AppUpdateInfo?> checkForUpdate() async {
    // Safety guard — this should never be called on web, but just in case.
    if (kIsWeb) return null;

    try {
      // 1. Read the remote version row.
      final response = await Supabase.instance.client
          .from('app_version')
          .select(
            'version_code, version_name, apk_url, release_notes, mandatory',
          )
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final remoteVersionCode =
          (response['version_code'] as num?)?.toInt() ?? 0;
      final versionName = (response['version_name'] as String?) ?? '';
      final apkUrl = (response['apk_url'] as String?) ?? '';
      final releaseNotes = (response['release_notes'] as String?) ?? '';
      final mandatory = (response['mandatory'] as bool?) ?? false;

      if (apkUrl.isEmpty) return null;

      // 2. Read the locally stored confirmed version code.
      final prefs = await SharedPreferences.getInstance();
      final localVersionCode = prefs.getInt(_confirmedVersionKey) ?? 0;

      // 3. Compare — only return info when remote is strictly newer.
      if (remoteVersionCode > localVersionCode) {
        return AppUpdateInfo(
          versionCode: remoteVersionCode,
          versionName: versionName,
          apkUrl: apkUrl,
          releaseNotes: releaseNotes,
          mandatory: mandatory,
        );
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ AppUpdateService.checkForUpdate error: $e');
      return null;
    }
  }
}
