// Web implementation of web_bridge.dart. Only ever compiled into the web
// build (see web_bridge.dart's conditional export) — dart:js_interop never
// reaches the Android build.
import 'dart:js_interop';

@JS('__appStarted')
external set _appStartedFlag(JSBoolean value);

@JS('location.reload')
external void _reloadLocation();

/// Sets `window.__appStarted = true`, which the loading screen injected by
/// web/index.html polls for to hide itself. Called once Flutter has
/// actually painted something to the user — the real app's first frame, or
/// our own startup-error screen — so the loading screen never outlives its
/// purpose and, on a genuine startup failure, never hides a message that
/// would otherwise be left stuck behind it until the 12-second timeout.
void markAppStarted() {
  _appStartedFlag = true.toJS;
}

/// Reloads the current page — used by the "Riprova" button on the Flutter
/// startup-error screen, mirroring the one in web/index.html's own
/// JavaScript fallback.
void reloadPage() {
  _reloadLocation();
}
