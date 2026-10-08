import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reports this client's app version/build to `report_app_version`, so the
/// admin "Versioni app" screen can see who hasn't updated yet. Called after
/// every login and on every app resume (including web). Never throws —
/// failures are swallowed since this is purely informational and must never
/// block or disrupt the app.
class AppVersionReportService {
  AppVersionReportService._();
  static final AppVersionReportService instance = AppVersionReportService._();

  Future<void> reportCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = kIsWeb ? 'web' : Platform.operatingSystem;
      await Supabase.instance.client.rpc('report_app_version', params: {
        'p_platform': platform,
        'p_version_name': packageInfo.version,
        'p_build': int.tryParse(packageInfo.buildNumber),
      });
    } catch (e) {
      debugPrint('⚠️ report_app_version failed (ignored): $e');
    }
  }
}
