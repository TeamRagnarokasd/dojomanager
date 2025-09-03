import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import './widgets/enhanced_admin_header_widget.dart';
import './widgets/management_cards_widget.dart';
import './widgets/realtime_statistics_widget.dart';
import './widgets/quick_actions_panel_widget.dart';
import './widgets/notification_center_widget.dart';
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
  final Map<String, dynamic> _dashboardStats = {
    'activeMemberships': 156,
    'monthlyRevenue': 4250.00,
    'pendingApprovals': 7,
    'capacityMetrics': 85.5,
    'totalEvents': 24,
    'instructorCount': 8,
    'disciplineCount': 5,
    'systemHealth': 98.7,
  };

  @override
  void initState() {
    super.initState();
    _loadAdminData();
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
      final profile = await AuthService.instance
          .getUserProfile(AuthService.instance.currentUser!.id);
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

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    _refreshController.repeat();

    await Future.delayed(const Duration(seconds: 2));

    _refreshController.stop();
    _refreshController.reset();
    setState(() => _isRefreshing = false);

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Dashboard amministrativo aggiornato',
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
              SliverToBoxAdapter(
                child: ManagementCardsWidget(),
              ),

              // Real-time Statistics
              SliverToBoxAdapter(
                child: RealtimeStatisticsWidget(stats: _dashboardStats),
              ),

              // Quick Actions Panel
              SliverToBoxAdapter(
                child: QuickActionsPanelWidget(),
              ),

              // Notification Center
              SliverToBoxAdapter(
                child: NotificationCenterWidget(),
              ),

              // Recent Activity Feed
              SliverToBoxAdapter(
                child: RecentActivityFeedWidget(),
              ),

              // Security Status
              SliverToBoxAdapter(
                child: SecurityStatusWidget(
                  systemHealth: _dashboardStats['systemHealth'],
                ),
              ),

              // Bottom padding for FAB
              SliverToBoxAdapter(
                child: SizedBox(height: 10.h),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.4),
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
              _buildQuickActionTile(
                'Approva Registrazione',
                Icons.how_to_reg,
                () => Navigator.pushNamed(context, '/admin-management-system'),
              ),
              _buildQuickActionTile(
                'Genera Ricevuta',
                Icons.receipt_long,
                () =>
                    Navigator.pushNamed(context, '/receipt-generation-system'),
              ),
              _buildQuickActionTile(
                'Invia Comunicazione',
                Icons.announcement,
                () =>
                    Navigator.pushNamed(context, '/automatic-reminder-system'),
              ),
              _buildQuickActionTile(
                'Aggiorna Programma',
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
      String title, IconData icon, VoidCallback onTap) {
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
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.1),
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
