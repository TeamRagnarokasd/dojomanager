import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../widgets/compliance_banner_widget.dart';
import '../../widgets/main_navigation_wrapper.dart';
import '../user_profile/widgets/team_certifications_widget.dart';
import './widgets/admin_compliance_alert_widget.dart';
import './widgets/notification_banner_widget.dart';
import './widgets/profile_switcher_widget.dart';
import './widgets/role_based_content_widget.dart';
import './widgets/sponsor_shop_section_widget.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({Key? key}) : super(key: key);

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome>
    with SingleTickerProviderStateMixin {
  String? _userRole;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _showNotificationBanner = true;
  late AnimationController _refreshController;
  bool _isRefreshing = false;
  UserRole _currentUserRole = UserRole.student;
  StreamSubscription? _authSubscription;

  // SIMPLIFIED: Remove complex retry mechanism that was causing issues
  String? _errorMessage;

  // Next upcoming booking data
  Map<String, dynamic>? _nextBooking;

  final List<Map<String, dynamic>> _bottomNavItems = [
    {'label': 'nav.home'.tr(), 'icon': 'home'},
    {'label': 'nav.classes'.tr(), 'icon': 'school'},
    {'label': 'nav.payments'.tr(), 'icon': 'payment'},
    {'label': 'nav.profile'.tr(), 'icon': 'person'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _checkAuthState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  void _checkAuthState() {
    // Listen for auth state changes
    _authSubscription = AuthService.instance.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
  }

  // COMPLETELY REWRITTEN: Simplified and more robust authentication check
  Future<void> _initializeDashboard() async {
    print('🔄 Initializing dashboard...');

    // STEP 1: Check if user is authenticated (simple check)
    if (!AuthService.instance.isAuthenticated) {
      print('❌ User not authenticated, redirecting to login');
      _navigateToLogin();
      return;
    }

    final user = AuthService.instance.currentUser;
    if (user == null) {
      print('❌ No current user found, redirecting to login');
      _navigateToLogin();
      return;
    }

    print('✅ User is authenticated: ${user.email}');

    // STEP 2: Load user data with graceful error handling
    try {
      await _loadUserDataSafely();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        print('✅ Dashboard initialized successfully');
      }
    } catch (error) {
      print('⚠️ Error loading user data: $error');

      // CRITICAL FIX: Don't redirect on data loading errors - show dashboard anyway
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'dashboard.limited_data'.tr();
          // Set default values so dashboard can still display
          _userProfile ??= {
            'id': user.id,
            'email': user.email ?? '',
            'full_name': user.email?.split('@')[0] ?? 'common.user'.tr(),
            'role': 'student',
            'status': 'approved',
            'is_active': true,
          };
          _userRole ??= 'student';
        });
        print('⚠️ Dashboard showing with limited data');
      }
    }
  }

  // SIMPLIFIED: Load user data without complex retry logic
  Future<void> _loadUserDataSafely() async {
    final user = AuthService.instance.currentUser!;

    // Load user profile with graceful error handling
    Map<String, dynamic>? profile;
    try {
      profile = await AuthService.instance.getUserProfile(user.id);
    } catch (profileError) {
      print('⚠️ Profile loading failed: $profileError');
      // Create basic profile instead of failing
      profile = {
        'id': user.id,
        'email': user.email ?? '',
        'full_name': user.email?.split('@')[0] ?? 'common.user'.tr(),
        'role': 'student',
        'status': 'approved',
        'is_active': true,
      };
    }

    // Load user role with graceful error handling
    String role = 'student';
    try {
      role = await AuthService.instance.getUserRole();
    } catch (roleError) {
      print('⚠️ Role loading failed: $roleError');
      // Determine role from email or profile as fallback
      if (profile?['role'] != null) {
        role = profile!['role'].toString();
      } else {
        final email = user.email?.toLowerCase() ?? '';
        if (email.contains('admin') ||
            email == 'lutadordeeliteravenna@gmail.com') {
          role = 'principal_admin';
        } else if (email.contains('instructor')) {
          role = 'instructor';
        } else {
          role = 'student';
        }
      }
    }

    // Update state with loaded data
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _userRole = role;
      });

      print('✅ User data loaded:');
      print('  - Email: ${profile?['email']}');
      print('  - Role: $role');
      print('  - Full Name: ${profile?['full_name']}');
    }

    // Load next upcoming booking for the notification banner
    await _loadNextUpcomingBooking(user.id);
  }

  /// Queries the next upcoming confirmed booking for the current user.
  /// Shows the red banner only when a real future booking exists.
  Future<void> _loadNextUpcomingBooking(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final nowTimeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

      // Query confirmed bookings with their schedule instance details
      final response = await supabase
          .from('class_registrations')
          .select('''
            id,
            registration_status,
            schedule_instances!inner (
              id,
              discipline,
              class_date,
              start_time,
              end_time
            )
          ''')
          .eq('user_id', userId)
          .eq('registration_status', 'registered')
          .gte('schedule_instances.class_date', todayStr)
          .order('schedule_instances(class_date)', ascending: true)
          .limit(10);

      if (response.isEmpty) {
        if (mounted) setState(() => _nextBooking = null);
        return;
      }

      // Find the next booking that hasn't started yet
      Map<String, dynamic>? nextBooking;
      for (final row in response) {
        final instance = row['schedule_instances'];
        if (instance == null) continue;
        final classDateStr = instance['class_date'] as String?;
        final startTimeStr = instance['start_time'] as String?;
        if (classDateStr == null || startTimeStr == null) continue;

        // Parse date and time
        DateTime? classDateTime;
        try {
          final timeParts = startTimeStr.split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          final dateParts = classDateStr.split('-');
          classDateTime = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            hour,
            minute,
          );
        } catch (_) {
          continue;
        }

        // Only show if the class is in the future
        if (classDateTime.isAfter(now)) {
          nextBooking = {
            'discipline': instance['discipline'] ?? '',
            'class_date': classDateStr,
            'start_time': startTimeStr,
            'datetime': classDateTime,
          };
          break;
        }
      }

      if (mounted) {
        setState(() {
          _nextBooking = nextBooking;
          // Reset banner visibility when new data is loaded
          if (nextBooking != null) {
            _showNotificationBanner = true;
          }
        });
      }
    } catch (e) {
      print('⚠️ Error loading next booking: $e');
      if (mounted) setState(() => _nextBooking = null);
    }
  }

  /// Formats the upcoming booking into a human-readable Italian message.
  String _getUpcomingBookingMessage() {
    if (_nextBooking == null) return '';

    final discipline = _nextBooking!['discipline'] as String? ?? '';
    final classDateStr = _nextBooking!['class_date'] as String? ?? '';
    final startTimeStr = _nextBooking!['start_time'] as String? ?? '';
    final classDateTime = _nextBooking!['datetime'] as DateTime?;

    // Format time (HH:MM)
    String timeFormatted = '';
    if (startTimeStr.isNotEmpty) {
      final parts = startTimeStr.split(':');
      if (parts.length >= 2) {
        timeFormatted = '${parts[0]}:${parts[1]}';
      }
    }

    // Format date label
    String dateLabel = '';
    if (classDateTime != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final classDay = DateTime(
        classDateTime.year,
        classDateTime.month,
        classDateTime.day,
      );

      if (classDay == today) {
        dateLabel = 'oggi';
      } else if (classDay == tomorrow) {
        dateLabel = 'domani';
      } else {
        // Italian weekday names
        const weekdays = [
          'lunedì',
          'martedì',
          'mercoledì',
          'giovedì',
          'venerdì',
          'sabato',
          'domenica',
        ];
        dateLabel = weekdays[classDateTime.weekday - 1];
      }
    }

    if (discipline.isNotEmpty &&
        timeFormatted.isNotEmpty &&
        dateLabel.isNotEmpty) {
      return 'Ricorda: il tuo prossimo allenamento di $discipline è $dateLabel alle $timeFormatted';
    } else if (discipline.isNotEmpty && timeFormatted.isNotEmpty) {
      return 'Ricorda: il tuo prossimo allenamento di $discipline è alle $timeFormatted';
    }
    return 'Hai un allenamento prenotato in arrivo';
  }

  // SIMPLIFIED: Clean navigation to login
  Future<void> _navigateToLogin() async {
    try {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (error) {
      print('Error during navigation to login: $error');
    }
  }

  void _simulateUserRole() {
    // Simulate different user roles for demo purposes
    // In real app, this would come from authentication/user service
    final roles = [UserRole.student, UserRole.instructor, UserRole.admin];
    setState(() {
      _currentUserRole = roles[DateTime.now().second % 3];
    });
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Start refresh animation
    _refreshController.repeat();

    // SIMPLIFIED: Just reload user data
    try {
      await _loadUserDataSafely();
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (error) {
      print('Refresh error: $error');
    }

    // Stop animation and update state
    _refreshController.stop();
    _refreshController.reset();

    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
    });

    // Show success feedback
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'dashboard.refreshed'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSecondary,
          ),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == _currentIndex) return;

    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
    });

    // Navigate to different screens based on index
    switch (index) {
      case 0:
        // Already on home
        break;
      case 1:
        Navigator.pushNamed(context, '/class-schedule');
        break;
      case 2:
        Navigator.pushNamed(context, '/payment-history');
        break;
      case 3:
        Navigator.pushNamed(context, '/user-profile');
        break;
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    final String greeting;

    if (hour < 12) {
      greeting = 'dashboard.greeting_morning'.tr();
    } else if (hour < 18) {
      greeting = 'dashboard.greeting_afternoon'.tr();
    } else {
      greeting = 'dashboard.greeting_evening'.tr();
    }

    final String roleTitle;
    switch (_currentUserRole) {
      case UserRole.student:
        roleTitle = 'dashboard.role_athlete'.tr();
        break;
      case UserRole.instructor:
        roleTitle = 'dashboard.role_instructor'.tr();
        break;
      case UserRole.admin:
        roleTitle = 'dashboard.role_admin'.tr();
        break;
    }

    return '$greeting, $roleTitle!';
  }

  String _getNotificationMessage() {
    switch (_currentUserRole) {
      case UserRole.student:
        return 'Ricorda: il tuo prossimo allenamento di BJJ è oggi alle 18:00';
      case UserRole.instructor:
        return 'Hai 2 allenamenti programmati per oggi. Controlla le presenze.';
      case UserRole.admin:
        return '3 certificati medici in scadenza richiedono la tua attenzione';
    }
  }

  Widget _buildQuickAccessSection() {
    List<Map<String, dynamic>> quickActions = [];

    switch (_userRole) {
      case 'student':
      case 'instructor_student':
        quickActions = [
          {
            'title': 'Le Mie Lezioni',
            'subtitle': 'Visualizza e prenota lezioni',
            'icon': Icons.calendar_today,
            'route': '/class-schedule',
            'color': Colors.blue,
          },
          {
            'title': 'instructor_directory.title'.tr(),
            'subtitle': 'Scopri il team di esperti',
            'icon': Icons.group,
            'route': '/instructor-directory',
            'color': Color(0xFFFF0000),
          },
          {
            'title': 'Pagamenti',
            'subtitle': 'Visualizza pagamenti',
            'icon': Icons.payment,
            'route': '/payment-history',
            'color': Colors.green,
          },
          {
            'title': 'Profilo',
            'subtitle': 'Gestisci i tuoi dati',
            'icon': Icons.person,
            'route': '/user-profile',
            'color': Colors.purple,
          },
        ];
        break;
      case 'instructor':
      case 'instructor_admin':
        quickActions = [
          {
            'title': 'Dashboard Istruttore',
            'subtitle': 'Le tue classi di oggi',
            'icon': Icons.dashboard,
            'route': '/instructor-dashboard',
            'color': Theme.of(context).colorScheme.secondary,
          },
          {
            'title': 'Palinsesto Classi',
            'subtitle': 'Gestisci le tue lezioni',
            'icon': Icons.event_note,
            'route': '/class-schedule',
            'color': Theme.of(context).colorScheme.primary,
          },
          {
            'title': 'Elenco Studenti',
            'subtitle': 'Visualizza studenti',
            'icon': Icons.group,
            'route': '/instructor-directory',
            'color': Colors.orange,
          },
          {
            'title': 'Ricevute & Pagamenti',
            'subtitle': 'Gestione finanziaria',
            'icon': Icons.receipt_long,
            'route': '/receipt-management',
            'color': Colors.green,
          },
        ];
        break;
      case 'admin':
      case 'principal_admin':
        // COMPLETELY NEW ADMIN CONTROL PANEL
        quickActions = [
          {
            'title': 'admin_sponsor.title'.tr(),
            'subtitle': 'Amministra sponsor e partner',
            'icon': Icons.business,
            'route': '/admin-sponsor-management',
            'color': Colors.purple,
          },
          {
            'title': 'Palinsesto Stagionale',
            'subtitle': 'Configura stagioni e orari',
            'icon': Icons.calendar_view_month,
            'route': '/seasonal-schedule-creation',
            'color': Theme.of(context).colorScheme.primary,
          },
          {
            'title': 'Generazione Ricevute',
            'subtitle': 'Sistema ricevute avanzato',
            'icon': Icons.receipt_long,
            'route': '/italian-receipt-generation',
            'color': Colors.green,
          },
          {
            'title': 'Gestione Registrazioni',
            'subtitle': 'Approva nuove iscrizioni',
            'icon': Icons.how_to_reg,
            'route': '/registration-management-system',
            'color': Colors.orange,
          },
          {
            'title': 'Gestione Utenti',
            'subtitle': 'Amministra tutti gli utenti',
            'icon': Icons.group,
            'route': '/user-management-system',
            'color': Colors.blue,
          },
          {
            'title': 'communication.title'.tr(),
            'subtitle': 'Messaggi e notifiche',
            'icon': Icons.message,
            'route': '/communication-center',
            'color': Colors.teal,
          },
          {
            'title': 'Creazione Eventi',
            'subtitle': 'Organizza eventi e corsi',
            'icon': Icons.event,
            'route': '/admin-event-management',
            'color': Colors.red,
          },
          {
            'title': 'Sistema Amministrazione',
            'subtitle': 'Gestione piattaforma',
            'icon': Icons.admin_panel_settings,
            'route': '/admin-management-system',
            'color': Theme.of(context).colorScheme.secondary,
          },
        ];
        break;
      default:
        quickActions = [
          {
            'title': 'Palinsesto Classi',
            'subtitle': 'Visualizza orari lezioni',
            'icon': Icons.event_note,
            'route': '/class-schedule',
            'color': Theme.of(context).colorScheme.secondary,
          },
          {
            'title': 'receipt.archive_title'.tr(),
            'subtitle': 'Le tue ricevute',
            'icon': Icons.receipt_long,
            'route': '/receipt-archive',
            'color': Theme.of(context).colorScheme.primary,
          },
        ];
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _userRole == 'admin' || _userRole == 'principal_admin'
                    ? 'dashboard.admin_panel'.tr()
                    : 'dashboard.quick_access'.tr(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (_userRole == 'admin' || _userRole == 'principal_admin')
                Container(
                  margin: EdgeInsets.only(left: 2.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'dashboard.administrator_badge'.tr(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 2.h,
              childAspectRatio:
                  _userRole == 'admin' || _userRole == 'principal_admin'
                  ? 1.4 // Slightly taller for admin cards
                  : 1.6,
            ),
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              final action = quickActions[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, action['route']);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).shadowColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: (action['color'] as Color).withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            action['icon'],
                            color: action['color'],
                            size: 24,
                          ),
                        ),
                        SizedBox(height: 1.5.h),
                        Flexible(
                          child: FittedBox(
                            alignment: Alignment.topLeft,
                            fit: BoxFit.scaleDown,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  action['title'],
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  action['subtitle'],
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'student':
        return 'dashboard.role_student'.tr();
      case 'instructor':
        return 'dashboard.role_instructor'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      case 'instructor_admin':
        return 'dashboard.role_instructor_admin'.tr();
      case 'instructor_student':
        return 'Istruttore Allievo';
      case 'principal_admin':
        return 'dashboard.role_principal_admin'.tr();
      default:
        return 'common.user'.tr();
    }
  }

  // SIMPLIFIED: Show error message as banner instead of breaking entire UI
  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.orange[800], fontSize: 12.sp),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
            icon: Icon(Icons.close, color: Colors.orange, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // SIMPLIFIED: Show loading state
    if (_isLoading) {
      return MainNavigationWrapper(
        currentIndex: 0,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: 2.h),
                Text(
                  'dashboard.loading'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // CRITICAL FIX: Always show dashboard for authenticated users, even with incomplete data
    return MainNavigationWrapper(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _userProfile?['full_name'] ?? 'common.user'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
          actions: [
            // Profile Switcher (only for students and instructor_student)
            if (_userRole == 'student' ||
                _userRole == 'instructor_student' ||
                _userRole == null)
              ProfileSwitcherWidget(
                adultProfile: _userProfile,
                onProfileChanged: () {
                  if (mounted) setState(() {});
                },
              ),
            // Switch to Instructor view button (for instructor_student)
            if (_userRole == 'instructor_student')
              Tooltip(
                message: 'Passa a Vista Istruttore',
                child: InkWell(
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.instructorMainDashboard,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ),
            // Role Badge — hidden for instructor_student to save space (shown in body)
            if (_userRole != 'instructor_student')
              Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getRoleDisplayName(_userRole ?? 'student'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Sign out button
            IconButton(
              onPressed: () async {
                try {
                  await AuthService.instance.logout();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  }
                } catch (error) {
                  print('Sign out error: $error');
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  }
                }
              },
              icon: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Theme.of(context).colorScheme.secondary,
            backgroundColor: Theme.of(context).cardColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome header row for instructor_student (full width, no truncation)
                  if (_userRole == 'instructor_student')
                    Container(
                      margin: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'dashboard.welcome'.tr(),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  _userProfile?['full_name'] ??
                                      'common.user'.tr(),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getRoleDisplayName(_userRole ?? 'student'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Error Banner (if any)
                  _buildErrorBanner(),

                  // Compliance banner (documenti minori 14-17 / certificato
                  // medico) — only relevant for student-facing roles.
                  if (_userRole == 'student' ||
                      _userRole == 'instructor_student' ||
                      _userRole == null)
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      child: const ComplianceBannerWidget(),
                    ),

                  // Compliance alert for admins: overdue students not yet
                  // blocked, decides whether to block bookings.
                  if (_userRole == 'admin' || _userRole == 'principal_admin')
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      child: const AdminComplianceAlertWidget(),
                    ),

                  // Notification Banner — only shown when user has a real upcoming booking
                  if (_showNotificationBanner && _nextBooking != null)
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      child: NotificationBannerWidget(
                        message: _getUpcomingBookingMessage(),
                        icon: Icons.info_outline,
                        backgroundColor: Colors.red,
                        onDismiss: () {
                          setState(() {
                            _showNotificationBanner = false;
                          });
                        },
                      ),
                    ),

                  // Quick Access Section
                  _buildQuickAccessSection(),

                  // Role-based content (only for non-admin users)
                  if (!(['admin', 'principal_admin'].contains(_userRole)))
                    RoleBasedContentWidget(),

                  SizedBox(height: 3.h),

                  // Sponsor & Shop Section
                  const SponsorShopSectionWidget(),

                  SizedBox(height: 3.h),

                  // Team Certifications Section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    child: TeamCertificationsWidget(),
                  ),

                  // Bottom padding for navigation bar
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Extension to convert SizedBox to Sliver
extension SizedBoxSliver on SizedBox {
  Widget toSliver() {
    return SliverToBoxAdapter(child: this);
  }
}
