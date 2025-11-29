import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import './widgets/enhanced_admin_header_widget.dart';
import './widgets/instructor_management_widget.dart';
import './widgets/management_cards_widget.dart';
import './widgets/notification_center_widget.dart';
import './widgets/realtime_statistics_widget.dart';
import './widgets/recent_activity_feed_widget.dart';
import './widgets/security_status_widget.dart';

class EnhancedAdminDashboard extends StatefulWidget {
  const EnhancedAdminDashboard({Key? key}) : super(key: key);

  @override
  State<EnhancedAdminDashboard> createState() => _EnhancedAdminDashboardState();
}

class _EnhancedAdminDashboardState extends State<EnhancedAdminDashboard>
    with SingleTickerProviderStateMixin {
  String? _userRole;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  late AnimationController _refreshController;
  bool _isRefreshing = false;
  final ScrollController _scrollController = ScrollController();

  // Admin Dashboard Statistics
  Map<String, dynamic> _dashboardStats = {
    'activeMemberships': 0,
    'monthlyRevenue': 0.0,
    'pendingApprovals': 0,
    'capacityMetrics': 0.0,
    'totalEvents': 0,
    'instructorCount': 0,
    'disciplineCount': 0,
    'systemHealth': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadAdminData();
    _loadDashboardStatistics(); // Load real stats from Supabase
    _checkAuthState();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAuthState() {
    AuthService.instance.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  Future<void> _loadAdminData() async {
    if (!AuthService.instance.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/');
      return;
    }

    try {
      final profile = await AuthService.instance.getUserProfile(
        AuthService.instance.currentUser!.id,
      );
      final role = await AuthService.instance.getUserRole();

      // Verify admin privileges
      if (!['admin', 'principal_admin', 'instructor_admin'].contains(role)) {
        Navigator.pushReplacementNamed(context, '/dashboard-home');
        return;
      }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Errore nel caricamento dati amministrativi",
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Load real-time statistics from Supabase database
  Future<void> _loadDashboardStatistics() async {
    try {
      final client = SupabaseService.instance.client;

      print('🔄 Starting dashboard statistics load...');
      print('  📥 Calling get_dashboard_statistics function...');

      // Use Supabase function to bypass RLS issues
      final response = await client.rpc('get_dashboard_statistics');

      print('  ✅ Function response received');

      final stats = response as Map<String, dynamic>;

      final activeMembersCount = stats['activeMemberships'] ?? 0;
      final pendingApprovalsCount = stats['pendingApprovals'] ?? 0;
      final totalEventsCount = stats['totalEvents'] ?? 0;
      final instructorCount = stats['instructorCount'] ?? 0;
      final sponsorCount = stats['sponsorCount'] ?? 0;
      final monthlyRevenue = (stats['monthlyRevenue'] ?? 0).toDouble();

      // Calculate capacity metrics (based on active users vs total capacity)
      double capacityMetrics = activeMembersCount > 0
          ? ((activeMembersCount / 200.0) * 100).clamp(0.0, 100.0)
          : 0.0;

      // System health (based on recent activity)
      double systemHealth =
          95.0 + (5.0 * (1.0 - (pendingApprovalsCount / 10.0).clamp(0.0, 1.0)));

      print('📊 Dashboard Stats Summary:');
      print('  ├─ Active Members: $activeMembersCount');
      print('  ├─ Monthly Revenue: €${monthlyRevenue.toStringAsFixed(2)}');
      print('  ├─ Pending Approvals: $pendingApprovalsCount');
      print('  ├─ Total Events: $totalEventsCount');
      print('  ├─ Instructors: $instructorCount');
      print('  ├─ Sponsors: $sponsorCount');
      print('  ├─ Capacity: ${capacityMetrics.toStringAsFixed(1)}%');
      print('  └─ System Health: ${systemHealth.toStringAsFixed(1)}%');

      if (mounted) {
        setState(() {
          _dashboardStats = {
            'activeMemberships': activeMembersCount,
            'monthlyRevenue': monthlyRevenue,
            'pendingApprovals': pendingApprovalsCount,
            'capacityMetrics': capacityMetrics,
            'totalEvents': totalEventsCount,
            'instructorCount': instructorCount,
            'disciplineCount': sponsorCount,
            'systemHealth': systemHealth,
          };
        });
        print('✅ Dashboard stats updated in UI');
      }
    } catch (error, stackTrace) {
      print('❌ Dashboard stats error: $error');
      print('📍 Stack trace: $stackTrace');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore nel caricamento delle statistiche: ${error.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Fallback to default values on error
      if (mounted) {
        setState(() {
          _dashboardStats = {
            'activeMemberships': 0,
            'monthlyRevenue': 0.0,
            'pendingApprovals': 0,
            'capacityMetrics': 0.0,
            'totalEvents': 0,
            'instructorCount': 0,
            'disciplineCount': 0,
            'systemHealth': 0.0,
          };
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    _refreshController.repeat();

    // Refresh both admin data and statistics
    await Future.wait([
      _loadAdminData(),
      _loadDashboardStatistics(),
      Future.delayed(const Duration(seconds: 2)), // Minimum loading time for UX
    ]);

    _refreshController.stop();
    _refreshController.reset();
    setState(() => _isRefreshing = false);

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Dashboard amministrativo aggiornato con dati Supabase',
          style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
          title: Text(
            'Disconnetti Amministratore',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Text(
            'Confermi la disconnessione dal pannello amministrativo?',
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
                'Disconnetti',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getAdminLevelIndicator() {
    switch (_userRole) {
      case 'principal_admin':
        return 'Admin Principale';
      case 'instructor_admin':
        return 'Istruttore Admin';
      case 'admin':
        return 'Amministratore';
      default:
        return 'Admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.secondary,
              ),
              SizedBox(height: 2.h),
              Text(
                'Caricamento pannello amministrativo...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_userProfile == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: 2.h),
              Text(
                'Errore di autenticazione amministrativa',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Impossibile accedere al pannello amministrativo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 3.h),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                child: Text('Torna al Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: Theme.of(context).colorScheme.secondary,
          backgroundColor: Theme.of(context).cardColor,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Enhanced Admin Header
              SliverToBoxAdapter(
                child: EnhancedAdminHeaderWidget(
                  adminLevel: _getAdminLevelIndicator(),
                  adminName: _userProfile?['full_name'] ?? 'Amministratore',
                  onSignOut: _handleSignOut,
                  stats: _dashboardStats,
                ),
              ),

              // Management Cards Section
              SliverToBoxAdapter(child: ManagementCardsWidget()),

              // Instructor Management Widget
              SliverToBoxAdapter(child: InstructorManagementWidget()),

              // Real-time Statistics
              SliverToBoxAdapter(
                child: RealtimeStatisticsWidget(stats: _dashboardStats),
              ),

              // Notification Center
              SliverToBoxAdapter(child: NotificationCenterWidget()),

              // Recent Activity Feed
              SliverToBoxAdapter(child: RecentActivityFeedWidget()),

              // Security Status
              SliverToBoxAdapter(
                child: SecurityStatusWidget(
                  systemHealth: _dashboardStats['systemHealth'],
                ),
              ),

              // Bottom padding for FAB
              SliverToBoxAdapter(child: SizedBox(height: 10.h)),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            // Show admin quick actions menu
            _showQuickActionsMenu();
          },
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
          elevation: 0,
          child: const Icon(Icons.admin_panel_settings, size: 28),
        ),
      ),
    );
  }

  void _showQuickActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Azioni Rapide Admin',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              SizedBox(height: 3.h),

              // Enhanced quick actions - removed registration management
              _buildQuickActionTile(
                'Gestione Istruttori',
                Icons.person_4,
                () => Navigator.pushNamed(
                  context,
                  '/instructor-management-system',
                ),
              ),
              _buildQuickActionTile(
                'Gestione Ricevute',
                Icons.receipt,
                () =>
                    Navigator.pushNamed(context, '/italian-receipt-generation'),
              ),
              _buildQuickActionTile(
                'Gestione Sponsor',
                Icons.business,
                () => Navigator.pushNamed(context, '/admin-sponsor-management'),
              ),
              _buildQuickActionTile(
                'Palinsesto Stagionale',
                Icons.calendar_today,
                () => Navigator.pushNamed(
                  context,
                  '/seasonal-schedule-management',
                ),
              ),
              _buildQuickActionTile(
                'Gestione Eventi',
                Icons.event_note,
                () => Navigator.pushNamed(context, '/admin-event-management'),
              ),

              SizedBox(height: 2.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionTile(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(4.w),
          margin: EdgeInsets.only(bottom: 1.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 24,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
