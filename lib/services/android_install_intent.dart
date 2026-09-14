import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

/// Launches the Android APK install intent for the given [apkPath].
/// This function must only be called on Android.
Future<void> launchAndroidInstallIntent(String apkPath) async {
  if (kIsWeb || !Platform.isAndroid) return;

  // On Android 7+ (API 24+) we must use a content:// URI via FileProvider.
  // The authority matches the one declared in AndroidManifest.xml.
  const authority = 'com.teamragnarok.asd.app.fileprovider';
  final contentUri = 'content://$authority/cache/${apkPath.split('/').last}';

  final intent = AndroidIntent(
    action: 'action_view',
    data: contentUri,
    type: 'application/vnd.android.package-archive',
    flags: <int>[
      268435456, // FLAG_ACTIVITY_NEW_TASK
      1, // FLAG_GRANT_READ_URI_PERMISSION
    ],
  );
  await intent.launch();
}
