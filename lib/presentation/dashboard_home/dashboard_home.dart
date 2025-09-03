import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import '../user_profile/widgets/team_certifications_widget.dart';
import './widgets/admin_stats_widget.dart';
import './widgets/notification_banner_widget.dart';
import './widgets/recent_activity_widget.dart';
import './widgets/role_based_content_widget.dart';

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

  final List<Map<String, dynamic>> _bottomNavItems = [
    {'label': 'Home', 'icon': 'home'},
    {'label': 'Classi', 'icon': 'school'},
    {'label': 'Pagamenti', 'icon': 'payment'},
    {'label': 'Profilo', 'icon': 'person'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  Future<void> _loadUserData() async {
    if (!AuthService.instance.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    try {
      final profile = await AuthService.instance
          .getUserProfile(AuthService.instance.currentUser!.id);
      final role = await AuthService.instance.getUserRole();

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userRole = role;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: "Errore nel caricamento profilo utente",
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
          title: Text(
            'Conferma Disconnessione',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Text(
            'Sei sicuro di voler uscire?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annulla',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.instance.signOut();
              },
              child: Text(
                'Esci',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
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

    // Simulate network request
    await Future.delayed(const Duration(seconds: 2));

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
        quickActions = [
          {
            'title': 'Gestione Sistema',
            'subtitle': 'Amministrazione utenti',
            'icon': Icons.admin_panel_settings,
            'route': '/admin-management-system',
            'color': Theme.of(context).colorScheme.secondary,
          },
          {
            'title': 'Palinsesto & Eventi',
            'subtitle': 'Modifica programma',
            'icon': Icons.event_note,
            'route': '/admin-event-management',
            'color': Theme.of(context).colorScheme.primary,
          },
          {
            'title': 'Archivio Ricevute',
            'subtitle': 'Tutte le ricevute',
            'icon': Icons.receipt_long,
            'route': '/admin-receipt-management',
            'color': Colors.green,
          },
          {
            'title': 'Gestione Discipline',
            'subtitle': 'BJJ, MMA, SAMBO',
            'icon': Icons.sports_martial_arts,
            'route': '/admin-discipline-management',
            'color': Colors.orange,
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
          Text(
            'Accesso Rapido',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          SizedBox(height: 2.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 3.w,
              mainAxisSpacing: 2.h,
              childAspectRatio: 1.6,
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
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .shadowColor
                              .withValues(alpha: 0.1),
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
                            color: (action['color'] as Color)
                                .withValues(alpha: 0.1),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          action['subtitle'],
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MainNavigationWrapper(
        currentIndex: 0,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (_userProfile == null) {
      return MainNavigationWrapper(
        currentIndex: 0,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Errore nel caricamento profilo',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                SizedBox(height: 2.h),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                  child: Text('Torna al Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.2),
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
              onPressed: _handleSignOut,
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
                  // Notification Banner
                  if (_showNotificationBanner)
                    Container(
                      margin:
                          EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
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

                  // Admin stats for admin users
                  if (['admin', 'instructor_admin', 'principal_admin']
                      .contains(_userRole)) ...[
                    AdminStatsWidget(
                      totalStudents: 156,
                      activeInstructors: 8,
                      todayClasses: 12,
                      monthlyRevenue: '€4,250',
                      pendingPayments: 7,
                      certificateExpirations: 3,
                    ),
                    SizedBox(height: 3.h),
                  ],

                  // Role-based content
                  RoleBasedContentWidget(),

                  SizedBox(height: 3.h),

                  // Recent Activity
                  RecentActivityWidget(
                    onRefresh: _handleRefresh,
                  ),

                  SizedBox(height: 3.h),

                  // Team Certifications Section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    child: TeamCertificationsWidget(),
                  ),

                  // Instructor Access Section - NEW
                  Container(
                    margin:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
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
                                color: Theme.of(context)
                                    .shadowColor
                                    .withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Icon container
                              Container(
                                padding: EdgeInsets.all(3.w),
                                decoration: BoxDecoration(
                                  color:
                                      Color(0xFFFF0000).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.group,
                                  color: Color(0xFFFF0000),
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              // Text content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'I Nostri Istruttori',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      'Scopri il team di esperti che ti guiderà nel tuo percorso marziale',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.grey[300],
                                            height: 1.3,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Arrow icon
                              Container(
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color:
                                      Color(0xFFFF0000).withValues(alpha: 0.1),
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
