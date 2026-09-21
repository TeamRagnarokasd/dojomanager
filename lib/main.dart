import 'dart:async';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import './routes/app_routes.dart';
import './services/app_update_service.dart';
import './services/android_install_intent.dart';
import './services/android_uninstall_intent.dart';
import './services/auth_service.dart';
import './services/locale_service.dart';
import './services/paid_intents_service.dart';
import './services/realtime_notification_service.dart';
import './services/supabase_service.dart';
import './services/child_profile_service.dart';
import './theme/app_theme.dart';

// Global navigator key — must be top-level so it is never re-created
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final savedLocale = await LocaleService.getSavedLocale();

  // Initialize Supabase - single initialization
  try {
    await SupabaseService.initialize();
    print('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize Supabase: $e');
  }

  // Initialize authentication system (includes session restoration)
  try {
    await AuthService.instance.initializeAuthSystem().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint(
          '⚠️ Auth system initialization timed out — continuing with current session state',
        );
      },
    );
    print('✅ Auth system initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize auth system: $e');
  }

  // Load persisted active child profile (if any)
  try {
    await ChildProfileService.loadActiveProfile();
    print('✅ Child profile context loaded');
  } catch (e) {
    debugPrint('⚠️ Could not load child profile context: $e');
  }

  // Force portrait orientation
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  runApp(
    EasyLocalization(
      supportedLocales: LocaleService.supportedLocales,
      path: 'assets/translations',
      fallbackLocale: LocaleService.defaultLocale,
      startLocale: savedLocale ?? LocaleService.defaultLocale,
      child: const TeamRagnarokAsdApp(),
    ),
  );
}

/// Navigator observer to track route changes for state restoration
class AppRouteObserver extends NavigatorObserver {
  final AuthService _authService = AuthService.instance;
  String? _lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _saveCurrentRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _saveCurrentRoute(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _saveCurrentRoute(previousRoute);
    }
  }

  void _saveCurrentRoute(Route<dynamic> route) {
    if (route.settings.name != null) {
      _lastRouteName = route.settings.name;
      if (_authService.isAuthenticated) {
        _authService.saveLastVisitedRoute(route.settings.name!);
      }
    }
  }
}

class TeamRagnarokAsdApp extends StatefulWidget {
  const TeamRagnarokAsdApp({super.key});

  @override
  State<TeamRagnarokAsdApp> createState() => _TeamRagnarokAsdAppState();
}

class _TeamRagnarokAsdAppState extends State<TeamRagnarokAsdApp>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService.instance;
  final AppRouteObserver _routeObserver = AppRouteObserver();
  String? _initialRoute;
  String? _defaultDashboardRoute;
  bool _isRestoringState = false;
  bool _routeResolved = false;
  bool _updateChecked = false;

  // Auth state stream subscription — cancelled on dispose to prevent leaks
  StreamSubscription<AuthState>? _authStateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Update last active timestamp when app starts
    _updateLastActiveOnStart();
    // Determine initial route based on session state
    _determineInitialRoute();
    // Wire real-time notifications (wrapped in try-catch to prevent startup crash)
    _initRealtimeSubscription();

    // Hard fallback: if route is not resolved within 10 seconds, force login
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !_routeResolved) {
        debugPrint('⚠️ Hard fallback triggered — forcing login route');
        setState(() {
          _initialRoute = AppRoutes.login;
          _routeResolved = true;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStateSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed from background');
      _handleAppResume();
      // 🆕 Reconcile Satispay payment_intents on every foreground return —
      // this is how activation happens even hours after the payment.
      _runPaidIntentsCheck();
    } else if (state == AppLifecycleState.paused) {
      print('📱 App moved to background');
    }
  }

  Future<void> _updateLastActiveOnStart() async {
    try {
      if (_authService.isAuthenticated) {
        await _authService.updateLastActiveTimestamp();
        print('✅ Last active timestamp updated on app start/resume');
      }
    } catch (e) {
      debugPrint('❌ Error updating last active timestamp: $e');
    }
  }

  /// Determine initial route based on authentication state.
  /// Blocks unapproved / inactive users from entering the app.
  Future<void> _determineInitialRoute() async {
    try {
      // Hard 6-second timeout — if anything hangs, fall through to login
      await Future.any([
        _doRouteResolution(),
        Future.delayed(const Duration(seconds: 6), () {
          debugPrint(
            '⚠️ _determineInitialRoute timed out — defaulting to login',
          );
        }),
      ]);
    } catch (e) {
      debugPrint('❌ Error determining initial route: $e');
    }

    if (!mounted) return;
    // If _doRouteResolution didn't set _initialRoute, default to login
    if (_initialRoute == null) {
      setState(() {
        _initialRoute = AppRoutes.login;
        _routeResolved = true;
      });
    }
  }

  Future<void> _doRouteResolution() async {
    try {
      if (_authService.isAuthenticated) {
        final isAllowed = await _isUserApprovedAndActive();
        if (!mounted) return;
        if (!isAllowed) {
          await _authService.signOut();
          if (!mounted) return;
          setState(() {
            _initialRoute = AppRoutes.login;
            _defaultDashboardRoute = AppRoutes.login;
            _routeResolved = true;
          });
          return;
        }

        final defaultRoute = await _getDefaultRouteForRole();
        if (!mounted) return;

        final savedRoute = await _authService.getLastVisitedRoute();
        if (!mounted) return;
        if (savedRoute != null && savedRoute != AppRoutes.login) {
          // Validate that the saved route is appropriate for the user's role
          final isRouteAllowed = await _isRouteAllowedForUser(savedRoute);
          if (!mounted) return;
          if (isRouteAllowed) {
            setState(() {
              _initialRoute = savedRoute;
              _defaultDashboardRoute = defaultRoute;
              _isRestoringState = true;
              _routeResolved = true;
            });
            return;
          } else {
            // Saved route is not allowed for this user's role — clear it
            await _authService.clearLastVisitedRoute();
            // Fall through to role-based default route below
          }
        }

        // No valid saved route — determine default route by role
        if (!mounted) return;
        setState(() {
          _initialRoute = defaultRoute;
          _defaultDashboardRoute = defaultRoute;
          _routeResolved = true;
        });
        return;
      }
    } catch (e) {
      debugPrint('❌ Error in _doRouteResolution: $e');
    }

    if (!mounted) return;
    setState(() {
      _initialRoute = AppRoutes.login;
      _defaultDashboardRoute = AppRoutes.login;
      _routeResolved = true;
    });
  }

  /// Returns the default dashboard route for the current user's role.
  Future<String> _getDefaultRouteForRole() async {
    try {
      final userRole = await _authService.getUserRole();
      final isPrincipalAdmin = await _authService.isPrincipalAdmin();
      final userEmail = _authService.currentUser?.email?.toLowerCase();
      final isPrincipalByEmail = userEmail == 'lutadordeeliteravenna@gmail.com';

      if (isPrincipalAdmin || isPrincipalByEmail) {
        return AppRoutes.enhancedAdminDashboard;
      } else if (['admin', 'instructor_admin'].contains(userRole)) {
        return AppRoutes.enhancedAdminDashboard;
      } else if (userRole == 'instructor') {
        return AppRoutes.instructorMainDashboard;
      } else {
        return AppRoutes.dashboardHome;
      }
    } catch (e) {
      debugPrint('❌ Error getting default route for role: $e');
      return AppRoutes.dashboardHome;
    }
  }

  /// Returns true if the given route is permitted for the current user's role.
  Future<bool> _isRouteAllowedForUser(String route) async {
    try {
      final userRole = await _authService.getUserRole();
      final isPrincipalAdmin = await _authService.isPrincipalAdmin();
      final userEmail = _authService.currentUser?.email?.toLowerCase();
      final isPrincipalByEmail = userEmail == 'lutadordeeliteravenna@gmail.com';

      // Routes exclusively for admins
      const adminOnlyRoutes = [
        AppRoutes.enhancedAdminDashboard,
        AppRoutes.adminManagementSystem,
        AppRoutes.adminDisciplineManagement,
        AppRoutes.adminEventManagement,
        AppRoutes.adminReceiptManagement,
        AppRoutes.adminSponsorManagement,
        AppRoutes.adminProfile,
        AppRoutes.instructorManagementSystem,
        AppRoutes.seasonalScheduleCreation,
        AppRoutes.italianReceiptGeneration,
      ];

      // Routes exclusively for instructors (and above)
      const instructorOnlyRoutes = [
        AppRoutes.instructorDashboard,
        AppRoutes.instructorMainDashboard,
      ];

      final isAdminUser =
          isPrincipalAdmin ||
          isPrincipalByEmail ||
          ['admin', 'instructor_admin'].contains(userRole);
      final isInstructorUser = userRole == 'instructor';

      if (adminOnlyRoutes.contains(route)) {
        return isAdminUser;
      }
      if (instructorOnlyRoutes.contains(route)) {
        return isAdminUser || isInstructorUser;
      }

      // All other routes are accessible to any authenticated user
      return true;
    } catch (e) {
      debugPrint('❌ Error checking route permission: $e');
      return false; // Deny on error — safer default
    }
  }

  /// Returns false if the user's profile status is not approved/active.
  Future<bool> _isUserApprovedAndActive() async {
    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) return false;

      final profileData = await Supabase.instance.client
          .from('user_profiles')
          .select('status, is_active')
          .eq('id', userId)
          .maybeSingle()
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              debugPrint(
                '⚠️ _isUserApprovedAndActive timed out — allowing user through',
              );
              return null;
            },
          );

      if (profileData == null)
        return true; // timeout or missing profile — allow through

      final status = (profileData['status'] as String?)?.trim().toLowerCase();
      final isActive = profileData['is_active'] == true;

      if (status == 'pending' || status == 'rejected' || !isActive) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking user approval on startup: $e');
      return true;
    }
  }

  /// Handle app resume - check 1-hour inactivity then restore navigation state.
  Future<void> _handleAppResume() async {
    try {
      if (!_authService.isAuthenticated) return;

      // ── 1-hour inactivity check ────────────────────────────────────────────
      final timedOut = await _authService.checkHourlyInactivityTimeout();
      if (timedOut) {
        print('⏱️ User inactive for 1+ hour — redirecting to login');
        final nav = appNavigatorKey.currentState;
        if (nav != null && mounted) {
          nav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        }
        return;
      }

      // Still active — update timestamp and restore route (non-web only)
      await _updateLastActiveOnStart();

      if (kIsWeb) return;

      final lastRoute = await _authService.getLastVisitedRoute();

      if (lastRoute != null &&
          lastRoute != AppRoutes.login &&
          lastRoute != AppRoutes.initial &&
          lastRoute != '/') {
        // Validate that the saved route is appropriate for the user's role
        final isRouteAllowed = await _isRouteAllowedForUser(lastRoute);
        if (!isRouteAllowed) {
          // Clear the invalid saved route and redirect to role-appropriate default
          await _authService.clearLastVisitedRoute();
          final defaultRoute = await _getDefaultRouteForRole();
          final nav = appNavigatorKey.currentState;
          if (nav != null && mounted) {
            nav.pushNamedAndRemoveUntil(defaultRoute, (route) => false);
          }
          return;
        }

        final nav = appNavigatorKey.currentState;
        if (nav != null && mounted) {
          final currentRoute = _routeObserver._lastRouteName;
          if (currentRoute == lastRoute) return;

          debugPrint('Restoring navigation to: $lastRoute');
          final defaultRoute = await _getDefaultRouteForRole();
          nav.pushNamedAndRemoveUntil(defaultRoute, (route) => false);
          if (lastRoute != defaultRoute) {
            nav.pushNamed(lastRoute);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling app resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'app.title'.tr(),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          initialRoute: AppRoutes.initial,
          routes: {
            ...AppRoutes.routes,
            AppRoutes.initial: (context) => _SplashGate(
              resolved: _routeResolved,
              targetRoute: _initialRoute ?? AppRoutes.login,
              defaultDashboardRoute:
                  _defaultDashboardRoute ?? _initialRoute ?? AppRoutes.login,
              onCheckMandatoryUpdate: _checkForMandatoryUpdate,
            ),
          },
          navigatorObservers: [_routeObserver, AppRoutes.routeObserver],
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: child!,
            );
          },
        );
      },
    );
  }

  /// Start real-time subscription if user is already authenticated on launch.
  void _initRealtimeSubscription() {
    try {
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        RealtimeNotificationService.instance.subscribe(userId);
        // 🆕 Reconcile any Satispay payment_intents on startup for an
        // already-authenticated session (e.g. app was killed and reopened).
        _runPaidIntentsCheck();
      }

      // React to future sign-in / sign-out events
      _authStateSub = _authService.onAuthStateChange.listen(
        (data) {
          try {
            if (data.event == AuthChangeEvent.signedIn) {
              final uid = data.session?.user.id;
              if (uid != null) {
                RealtimeNotificationService.instance.subscribe(uid);
                // 🆕 Reconcile right after login too.
                _runPaidIntentsCheck();
              }
            } else if (data.event == AuthChangeEvent.signedOut) {
              RealtimeNotificationService.instance.unsubscribe();
            }
          } catch (e) {
            debugPrint('❌ Error handling auth state change in realtime: $e');
          }
        },
        onError: (e) {
          debugPrint('❌ Auth state stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to initialize realtime subscription: $e');
    }
  }

  /// 🆕 Reconciles any pending/matched Satispay payment_intents and activates
  /// the corresponding subscription automatically. Safe to call repeatedly —
  /// PaidIntentsService itself guards against overlapping runs — and safe on
  /// any platform (web included), since it relies only on backend data.
  /// Shows a confirmation toast for each subscription actually activated by
  /// this call: "Abbonamento attivato" if it's still valid, or a "payment
  /// registered but already expired" message otherwise.
  Future<void> _runPaidIntentsCheck() async {
    try {
      final results = await PaidIntentsService.instance.processPaidIntents();
      for (final result in results) {
        Fluttertoast.showToast(
          msg: result.stillValid
              ? 'Abbonamento attivato'
              : 'Ultimo pagamento effettuato, correttamente registrato, ma '
                  'l\'abbonamento risulta già scaduto.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: result.stillValid ? Colors.green : Colors.orange,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('⚠️ PaidIntents check failed: $e');
    }
  }

  /// Called by _SplashGate after navigation has completed (non-blocking path).
  /// Runs from the root state so `mounted` is always true after navigation.
  Future<void> _checkForUpdateAfterNav() async {
    if (kIsWeb || _updateChecked) return;
    _updateChecked = true;
    try {
      final updateInfo = await AppUpdateService.instance.checkForUpdate();
      if (updateInfo == null) return;
      // 800 ms delay so the destination screen finishes rendering first.
      await Future.delayed(const Duration(milliseconds: 800));
      final ctx = appNavigatorKey.currentContext;
      if (ctx != null) {
        await showAppUpdateDialog(ctx, updateInfo);
      }
    } catch (e) {
      debugPrint('⚠️ Update check failed: $e');
    }
  }

  /// Called by _SplashGate BEFORE navigation when a mandatory update is
  /// detected. Returns true if the update was installed (navigation may
  /// proceed), false if the check found no update (navigation may proceed),
  /// or loops until the user installs (mandatory = true, never returns false
  /// while an update is pending).
  ///
  /// For the mandatory path the dialog is shown over the splash screen itself,
  /// so we pass the splash context directly.
  Future<bool> _checkForMandatoryUpdate(BuildContext splashContext) async {
    if (kIsWeb) return true;
    try {
      final updateInfo = await AppUpdateService.instance.checkForUpdate();
      if (updateInfo == null) return true; // no update — proceed
      if (!updateInfo.mandatory) {
        // Non-mandatory: let navigation happen first, then show dialog from root.
        _updateChecked = true;
        Future.microtask(() async {
          await Future.delayed(const Duration(milliseconds: 800));
          final ctx = appNavigatorKey.currentContext;
          if (ctx != null) {
            await showAppUpdateDialog(ctx, updateInfo);
          }
        });
        return true; // allow navigation to proceed immediately
      }
      // Mandatory: show dialog over the splash screen and do NOT return until
      // the user has installed the update (dialog is not dismissible).
      if (splashContext.mounted) {
        await showAppUpdateDialog(splashContext, updateInfo);
      }
      // After the dialog closes (only possible once install intent fires),
      // allow navigation.
      return true;
    } catch (e) {
      debugPrint('⚠️ Mandatory update check failed: $e');
      return true; // on error, allow navigation rather than blocking forever
    }
  }
}

/// Splash gate widget: shows a loading indicator until the route is resolved,
/// then immediately navigates to the target route.
class _SplashGate extends StatefulWidget {
  final bool resolved;
  final String targetRoute;
  final String defaultDashboardRoute;
  final Future<bool> Function(BuildContext) onCheckMandatoryUpdate;

  const _SplashGate({
    required this.resolved,
    required this.targetRoute,
    required this.defaultDashboardRoute,
    required this.onCheckMandatoryUpdate,
  });

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _navigated = false;

  Future<void> _navigate() async {
    if (!mounted) return;

    // Run the update check BEFORE navigating away.
    // For mandatory updates this will block here (dialog shown over splash)
    // until the user installs. For non-mandatory updates it schedules the
    // dialog to appear after navigation and returns immediately.
    final canProceed = await widget.onCheckMandatoryUpdate(context);
    if (!canProceed) return; // safety — currently always true

    if (!mounted) return;

    final target = widget.targetRoute;
    final defaultDashboard = widget.defaultDashboardRoute;
    if (target == defaultDashboard) {
      // Target IS the default dashboard — single replacement, existing behaviour
      Navigator.of(context).pushReplacementNamed(target);
    } else {
      // Target is a restored route different from the default dashboard:
      // push the default dashboard first so the back button works, then
      // push the restored route on top of it.
      Navigator.of(context).pushReplacementNamed(defaultDashboard);
      Navigator.of(context).pushNamed(target);
    }
  }

  @override
  void didUpdateWidget(_SplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resolved && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigate();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.resolved && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/146804-1762122410365.jpg',
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) =>
                  const SizedBox(width: 100, height: 100),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-app update dialog — Android / non-web only
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the update dialog. Must be called with a valid [BuildContext] that has
/// a [Navigator] ancestor (i.e. after the initial route has been pushed).
Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
) async {
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: !info.mandatory,
    builder: (ctx) => _AppUpdateDialog(info: info),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _AppUpdateDialog({required this.info});

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      if (!kIsWeb &&
          Platform.isAndroid &&
          widget.info.requiresSignatureChange) {
        // The new APK is signed with a different key: Android refuses to
        // install it over the currently-installed app, so a normal
        // in-place update is impossible. Open the download link in the
        // browser FIRST — the browser's download runs independently of
        // this app's process — and only THEN uninstall this app, since
        // after that this app can no longer do anything at all.
        final opened = await launchUrl(
          Uri.parse(widget.info.apkUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          setState(() {
            _isDownloading = false;
            _errorMessage = 'Impossibile aprire il link di download.';
          });
          return;
        }
        // Give the browser a moment to actually start the download before
        // this app disappears from under it.
        await Future.delayed(const Duration(seconds: 2));
        await launchAndroidUninstallIntent();
        return;
      }

      // Request install-packages permission at runtime.
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          setState(() {
            _isDownloading = false;
            _errorMessage =
                'Permesso di installazione negato. Abilitalo nelle impostazioni.';
          });
          return;
        }
      }

      // Download APK to temp directory.
      final tempDir = await getTemporaryDirectory();
      final apkPath = '${tempDir.path}/update.apk';

      final dio = Dio();
      await dio.download(
        widget.info.apkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      // Launch install intent via android_intent_plus.
      if (!kIsWeb && Platform.isAndroid) {
        // Save the confirmed version code BEFORE launching the install intent,
        // so the app remembers it has already moved to this version.
        await AppUpdateService.instance.saveConfirmedVersionCode(
          widget.info.versionCode,
        );

        // Use android_intent_plus to fire ACTION_VIEW with the APK URI.
        // We import it conditionally so it never compiles on web.
        await _launchInstallIntent(apkPath);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('❌ APK download/install error: $e');
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Download fallito. Controlla la connessione e riprova.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.info.mandatory,
      child: AlertDialog(
        title: const Text('Aggiornamento disponibile'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.info.releaseNotes),
              if (widget.info.requiresSignatureChange) ...[
                const SizedBox(height: 12),
                Text(
                  'Questo aggiornamento richiede di disinstallare e '
                  'reinstallare l\'app. Al tocco su "Aggiorna ora" si aprirà '
                  'il download nel browser e poi l\'app verrà disinstallata: '
                  'al termine apri il file scaricato per reinstallarla.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_isDownloading && !widget.info.requiresSignatureChange) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text(
                  'Download: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_isDownloading && widget.info.requiresSignatureChange) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Apertura del download in corso…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.info.mandatory && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Più tardi'),
            ),
          ElevatedButton(
            onPressed: _isDownloading ? null : _downloadAndInstall,
            child: const Text('Aggiorna ora'),
          ),
        ],
      ),
    );
  }
}

/// Launches the Android install intent for the downloaded APK.
/// Extracted to a separate function so it can be guarded at call-site.
Future<void> _launchInstallIntent(String apkPath) async {
  // android_intent_plus is only available on Android — this function is only
  // ever called when Platform.isAndroid is true.
  try {
    // Use the android_intent_plus package to fire the install intent.
    // We use a dynamic import workaround via a conditional import at the top.
    final intent = _AndroidIntentHelper(apkPath);
    await intent.launch();
  } catch (e) {
    debugPrint('❌ Install intent error: $e');
    rethrow;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin wrapper so android_intent_plus is only referenced in non-web builds.
// ─────────────────────────────────────────────────────────────────────────────
class _AndroidIntentHelper {
  final String apkPath;
  _AndroidIntentHelper(this.apkPath);

  Future<void> launch() async {
    // android_intent_plus import — only compiled on non-web.
    // We use a late import pattern via a helper to avoid web compilation issues.
    if (kIsWeb) return;
    await launchAndroidInstallIntent(apkPath);
  }
}
