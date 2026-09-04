import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './routes/app_routes.dart';
import './services/auth_service.dart';
import './services/locale_service.dart';
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
            '⚠️ Auth system initialization timed out — continuing with current session state');
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
  bool _isRestoringState = false;
  bool _routeResolved = false;

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
              '⚠️ _determineInitialRoute timed out — defaulting to login');
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
            _routeResolved = true;
          });
          return;
        }

        final savedRoute = await _authService.getLastVisitedRoute();
        if (!mounted) return;
        if (savedRoute != null && savedRoute != AppRoutes.login) {
          // Validate that the saved route is appropriate for the user's role
          final isRouteAllowed = await _isRouteAllowedForUser(savedRoute);
          if (!mounted) return;
          if (isRouteAllowed) {
            setState(() {
              _initialRoute = savedRoute;
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
        final defaultRoute = await _getDefaultRouteForRole();
        if (!mounted) return;
        setState(() {
          _initialRoute = defaultRoute;
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

      final isAdminUser = isPrincipalAdmin ||
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
          .timeout(const Duration(seconds: 4), onTimeout: () {
        debugPrint(
            '⚠️ _isUserApprovedAndActive timed out — allowing user through');
        return null;
      });

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
          nav.pushNamedAndRemoveUntil(lastRoute, (route) => false);
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
      }

      // React to future sign-in / sign-out events
      _authStateSub = _authService.onAuthStateChange.listen(
        (data) {
          try {
            if (data.event == AuthChangeEvent.signedIn) {
              final uid = data.session?.user.id;
              if (uid != null) {
                RealtimeNotificationService.instance.subscribe(uid);
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
}

/// Splash gate widget: shows a loading indicator until the route is resolved,
/// then immediately navigates to the target route.
class _SplashGate extends StatefulWidget {
  final bool resolved;
  final String targetRoute;

  const _SplashGate({required this.resolved, required this.targetRoute});

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  bool _navigated = false;

  @override
  void didUpdateWidget(_SplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resolved && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(widget.targetRoute);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.resolved && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(widget.targetRoute);
        }
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
              'assets/images/team_ragnarok_icon.png',
              width: 100,
              height: 100,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
