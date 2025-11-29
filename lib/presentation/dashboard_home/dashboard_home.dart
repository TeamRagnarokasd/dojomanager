import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import '../user_profile/widgets/team_certifications_widget.dart';
import './widgets/notification_banner_widget.dart';
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

  // SIMPLIFIED: Remove complex retry mechanism that was causing issues
  String? _errorMessage;

  final List<Map<String, dynamic>> _bottomNavItems = [
    {'label': 'Home', 'icon': 'home'},
    {'label': 'Classi', 'icon': 'school'},
    {'label': 'Pagamenti', 'icon': 'payment'},
    {'label': 'Profilo', 'icon': 'person'},
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
    _refreshController.dispose();
    super.dispose();
  }

  void _checkAuthState() {
    // Listen for auth state changes
    AuthService.instance.onAuthStateChange.listen((data) {
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
          _errorMessage = 'Alcuni dati potrebbero non essere aggiornati';
          // Set default values so dashboard can still display
          _userProfile ??= {
            'id': user.id,
            'email': user.email ?? '',
            'full_name': user.email?.split('@')[0] ?? 'Utente',
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
        'full_name': user.email?.split('@')[0] ?? 'Utente',
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

    setState(() {
      _isRefreshing = false;
    });

    // Show success feedback
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Dashboard aggiornato',
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
      greeting = 'Buongiorno';
    } else if (hour < 18) {
      greeting = 'Buon pomeriggio';
    } else {
      greeting = 'Buonasera';
    }

    final String roleTitle;
    switch (_currentUserRole) {
      case UserRole.student:
        roleTitle = 'Atleta';
        break;
      case UserRole.instructor:
        roleTitle = 'Istruttore';
        break;
      case UserRole.admin:
        roleTitle = 'Amministratore';
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
        quickActions = [
          {
            'title': 'Palinsesto Classi',
            'subtitle': 'Visualizza orari lezioni',
            'icon': Icons.event_note,
            'route': '/class-schedule',
            'color': Theme.of(context).colorScheme.secondary,
          },
          {
            'title': 'Archivio Ricevute',
            'subtitle': 'Le tue ricevute personali',
            'icon': Icons.receipt_long,
            'route': '/receipt-archive',
            'color': Theme.of(context).colorScheme.primary,
          },
          {
            'title': 'Storico Pagamenti',
            'subtitle': 'Visualizza pagamenti',
            'icon': Icons.payment,
            'route': '/payment-history',
            'color': Colors.green,
          },
          {
            'title': 'Profilo Utente',
            'subtitle': 'Gestisci il tuo profilo',
            'icon': Icons.person,
            'route': '/user-profile',
            'color': Colors.blue,
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
            'title': 'Gestione Sponsor',
            'subtitle': 'Amministra sponsor e partner',
            'icon': Icons.business,
            'route': '/admin-sponsor-management',
            'color': Colors.purple,
          },
          {
            'title': 'Palinsesto Stagionale',
            'subtitle': 'Configura stagioni e orari',
            'icon': Icons.calendar_view_month,
            'route': '/seasonal-schedule-management',
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
            'title': 'Centro Comunicazioni',
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
            'title': 'Archivio Ricevute',
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
                    ? 'Pannello di Controllo Admin'
                    : 'Accesso Rapido',
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
                    'AMMINISTRATORE',
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
                        Text(
                          action['title'],
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          action['subtitle'],
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
        return 'Studente';
      case 'instructor':
        return 'Istruttore';
      case 'admin':
        return 'Admin';
      case 'instructor_admin':
        return 'Istruttore Admin';
      case 'principal_admin':
        return 'Admin Principale';
      default:
        return 'Utente';
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
                  'Caricamento dashboard...',
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Benvenuto/a',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                _userProfile?['full_name'] ?? 'Utente',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            // Role Badge
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
                  await AuthService.instance.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  }
                } catch (error) {
                  print('Sign out error: $error');
                  // Force navigation even if sign out fails
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
                  // Error Banner (if any)
                  _buildErrorBanner(),

                  // Notification Banner
                  if (_showNotificationBanner)
                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      child: NotificationBannerWidget(
                        message: _getNotificationMessage(),
                        icon: Icons.info_outline,
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
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

                  // Instructor Access Section
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 2.h,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pushNamed(context, '/instructor-directory');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFF0000).withValues(alpha: 0.1),
                                Color(0xFFFF0000).withValues(alpha: 0.2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFFFF0000).withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).shadowColor.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(4, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(3.w),
                                decoration: BoxDecoration(
                                  color: Color(
                                    0xFFFF0000,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.group,
                                  color: Color(0xFFFF0000),
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'I Nostri Istruttori',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      'Scopri il team di esperti che ti guiderà nel tuo percorso marziale',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[300],
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: Color(
                                    0xFFFF0000,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFFFF0000),
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
