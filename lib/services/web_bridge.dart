/// Bridges a handful of calls from Dart to the hosting web page's JavaScript
/// (see web/index.html's loading screen). On a non-web build this resolves
/// to a no-op stub so `dart:js_interop` is never pulled into the Android
/// compilation at all.
export 'web_bridge_stub.dart' if (dart.library.html) 'web_bridge_web.dart';
