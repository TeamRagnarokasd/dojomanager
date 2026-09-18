import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

/// Launches the Android package-uninstall intent for this app itself.
/// This function must only be called on Android, and only *after* the APK
/// download has already been kicked off elsewhere (e.g. opened in the
/// browser) — once the uninstall flow starts, this app's process is killed
/// and it can no longer do anything.
Future<void> launchAndroidUninstallIntent() async {
  if (kIsWeb || !Platform.isAndroid) return;

  const packageName = 'com.teamragnarok.asd.app';

  final intent = AndroidIntent(
    action: 'android.intent.action.DELETE',
    data: 'package:$packageName',
    flags: <int>[268435456], // FLAG_ACTIVITY_NEW_TASK
  );
  await intent.launch();
}
