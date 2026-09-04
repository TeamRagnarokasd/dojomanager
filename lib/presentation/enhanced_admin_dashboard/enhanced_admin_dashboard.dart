import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
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
    'registeredMembers': 0,
    'subscribedMembers': 0,
    'courseSubscribers': 0,
    'monthlyRevenue': 0.0,
    'pendingApprovals': 0,
    'passwordResetRequests': 0,
    'capacityMetrics': 0.0,
    'totalEvents': 0,
    'instructorCount': 0,
    'disciplineCount': 0,
    'systemHealth': 0.0,
  };

  // Key to force RealtimeStatisticsWidget rebuild on refresh
  int _statsRefreshKey = 0;

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

      // --- Registered members: count ALL users in user_profiles (all roles: student, instructor, staff, etc.) ---
      final registeredResponse =
          await client.from('user_profiles').select('id').neq(
                'role',
                'principal_admin',
              ); // exclude only the main admin account
      final adultUsersCount = (registeredResponse as List).length;

      // Also count active child profiles
      final childProfilesResponse = await client
          .from('child_profiles')
          .select('id')
          .eq('is_active', true);
      final childProfilesCount = (childProfilesResponse as List).length;

      final registeredMembersCount = adultUsersCount + childProfilesCount;

      // --- Subscribed members (Iscrizione Annuale): unique users with active annual subscription ---
      // from the most recent August 28th onwards
      final now = DateTime.now();
      DateTime mostRecentAugust28 = DateTime(now.year, 8, 28);
      if (now.isBefore(mostRecentAugust28)) {
        mostRecentAugust28 = DateTime(now.year - 1, 8, 28);
      }

      final annualReceiptsResponse = await client
          .from('non_fiscal_receipts')
          .select('customer_tax_code')
          .ilike('description', '%Iscrizione Annuale%')
          .eq('deleted_by_user', false)
          .gte('issue_date', mostRecentAugust28.toIso8601String().split('T')[0])
          .order('issue_date', ascending: false);

      final uniqueAnnualMembers = <String>{};
      for (final receipt in annualReceiptsResponse) {
        final taxCode = receipt['customer_tax_code'];
        if (taxCode != null && taxCode.toString().isNotEmpty) {
          uniqueAnnualMembers.add(taxCode.toString());
        }
      }
      final subscribedMembersCount = uniqueAnnualMembers.length;

      // Keep activeMemberships as same value for backward compat
      final activeMembersCount = subscribedMembersCount;

      // --- Course subscribers: users with active course subscription (NOT annual) ---
      // Count unique users in user_subscriptions that are active and linked to a course plan
      int courseSubscribersCount = 0;
      try {
        final courseSubsResponse = await client
            .from('user_subscriptions')
            .select('user_id')
            .eq('status', 'active');

        // Get all active user_subscriptions, then filter out annual ones
        // by checking subscription_plans or custom_subscription_plans for non-annual plans
        final activeSubUserIds = <String>{};
        for (final sub in courseSubsResponse) {
          final userId = sub['user_id'];
          if (userId != null) {
            activeSubUserIds.add(userId.toString());
          }
        }

        // Now exclude users whose ONLY active subscription is annual
        // We check non_fiscal_receipts for course subscriptions (not Iscrizione Annuale)
        final courseReceiptsResponse = await client
            .from('non_fiscal_receipts')
            .select('customer_tax_code')
            .not('description', 'ilike', '%Iscrizione Annuale%')
            .eq('deleted_by_user', false)
            .gte(
              'issue_date',
              mostRecentAugust28.toIso8601String().split('T')[0],
            );

        final uniqueCourseMembers = <String>{};
        for (final receipt in courseReceiptsResponse) {
          final taxCode = receipt['customer_tax_code'];
          if (taxCode != null && taxCode.toString().isNotEmpty) {
            uniqueCourseMembers.add(taxCode.toString());
          }
        }
        courseSubscribersCount = uniqueCourseMembers.length;
      } catch (e) {
        print('⚠️ Course subscribers query error: $e');
        // Fallback: count active user_subscriptions with non-null subscription_plan_id
        try {
          final fallbackResponse = await client
              .from('user_subscriptions')
              .select('user_id')
              .eq('status', 'active');
          final uniqueIds = <String>{};
          for (final sub in fallbackResponse) {
            final uid = sub['user_id'];
            if (uid != null) uniqueIds.add(uid.toString());
          }
          courseSubscribersCount = uniqueIds.length;
        } catch (_) {}
      }

      // --- Pending approvals: user_profiles with status='pending' (regardless of is_active) ---
      final pendingResponse = await client
          .from('user_profiles')
          .select('id')
          .eq('status', 'pending');
      final pendingApprovalsCount = (pendingResponse as List).length;

      // --- Password reset requests: pending requests in password_reset_requests ---
      int passwordResetRequestsCount = 0;
      try {
        final passwordResetResponse = await client
            .from('password_reset_requests')
            .select('id')
            .eq('status', 'pending');
        passwordResetRequestsCount = (passwordResetResponse as List).length;
      } catch (e) {
        print('⚠️ Password reset requests query error: $e');
      }

      print(
        '  ✅ Pending approvals (user_profiles only): $pendingApprovalsCount',
      );

      // --- Instructors ---
      final instructorsResponse = await client
          .from('user_profiles')
          .select('id')
          .inFilter('role', ['instructor', 'instructor_admin']);
      final instructorCount = (instructorsResponse as List).length;

      // --- Events ---
      int totalEventsCount = 0;
      try {
        final eventsResponse = await client.from('events').select('id');
        totalEventsCount = (eventsResponse as List).length;
      } catch (_) {}

      // --- Sponsors ---
      int sponsorCount = 0;
      try {
        final sponsorsResponse = await client.from('sponsors').select('id');
        sponsorCount = (sponsorsResponse as List).length;
      } catch (_) {}

      // --- Monthly revenue from non_fiscal_receipts (current month) ---
      final startOfMonthStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextMonthYear = now.month == 12 ? now.year + 1 : now.year;
      final startOfNextMonthStr =
          '$nextMonthYear-${nextMonth.toString().padLeft(2, '0')}-01';

      double monthlyRevenue = 0.0;
      try {
        final receiptsResponse = await SupabaseService.instance.client
            .from('non_fiscal_receipts')
            .select('amount')
            .gte('issue_date', startOfMonthStr)
            .lt('issue_date', startOfNextMonthStr);

        for (var receipt in receiptsResponse) {
          monthlyRevenue += (receipt['amount'] as num? ?? 0).toDouble();
        }
      } catch (e) {
        print('⚠️ Monthly revenue query error (non-blocking): $e');
        // monthlyRevenue stays 0.0 — non-critical, don't fail entire stats load
      }

      // Capacity metrics
      double capacityMetrics = activeMembersCount > 0
          ? ((activeMembersCount / 200.0) * 100).clamp(0.0, 100.0)
          : 0.0;

      // System health
      double systemHealth =
          95.0 + (5.0 * (1.0 - (pendingApprovalsCount / 10.0).clamp(0.0, 1.0)));

      print('📊 Dashboard Stats Summary:');
      print('  ├─ Registered Members: $registeredMembersCount');
      print('  ├─ Subscribed Members (Annual): $subscribedMembersCount');
      print('  ├─ Course Subscribers: $courseSubscribersCount');
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
            'registeredMembers': registeredMembersCount,
            'subscribedMembers': subscribedMembersCount,
            'courseSubscribers': courseSubscribersCount,
            'monthlyRevenue': monthlyRevenue,
            'pendingApprovals': pendingApprovalsCount,
            'passwordResetRequests': passwordResetRequestsCount,
            'capacityMetrics': capacityMetrics,
            'totalEvents': totalEventsCount,
            'instructorCount': instructorCount,
            'disciplineCount': sponsorCount,
            'systemHealth': systemHealth,
          };
          _statsRefreshKey++;
        });
        print('✅ Dashboard stats updated in UI');
      }
    } catch (error, stackTrace) {
      print('❌ Dashboard stats error: $error');
      print('📍 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore nel caricamento statistiche: ${error.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _dashboardStats = {
            'activeMemberships': 0,
            'registeredMembers': 0,
            'subscribedMembers': 0,
            'courseSubscribers': 0,
            'monthlyRevenue': 0.0,
            'pendingApprovals': 0,
            'passwordResetRequests': 0,
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

  Future<void> _showPasswordResetRequestsSheet() async {
    final client = SupabaseService.instance.client;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _PasswordResetRequestsSheet(
          client: client,
          onDismiss: () {
            Navigator.of(ctx).pop();
            _loadDashboardStatistics();
          },
          onCountChanged: (int newCount) {
            if (mounted) {
              setState(() {
                _dashboardStats['passwordResetRequests'] = newCount;
              });
            }
          },
        );
      },
    ).then((_) => _loadDashboardStatistics());
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
                'common.cancel'.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService.instance.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                }
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
        return 'dashboard.role_principal_admin'.tr();
      case 'instructor_admin':
        return 'dashboard.role_instructor_admin'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      default:
        return 'roles.admin'.tr();
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
                'admin_dashboard.loading_panel'.tr(),
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
                'admin_dashboard.auth_error'.tr(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'admin_dashboard.auth_error_detail'.tr(),
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
                child: Text('student_registration.go_to_login'.tr()),
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
                  adminName: _userProfile?['full_name'] ?? 'roles.admin'.tr(),
                  onSignOut: _handleSignOut,
                  stats: _dashboardStats,
                  onPendingTap:
                      (_dashboardStats['pendingApprovals'] as int? ?? 0) > 0
                          ? () => Navigator.pushNamed(
                                context,
                                '/admin-management-system',
                              )
                          : null,
                  onSwitchToInstructor: _userRole == 'principal_admin' ||
                          _userRole == 'instructor_admin'
                      ? () => Navigator.pushNamed(
                            context,
                            '/instructor-main-dashboard',
                          )
                      : null,
                  onPasswordResetTap: _showPasswordResetRequestsSheet,
                ),
              ),

              // Management Cards Section
              SliverToBoxAdapter(
                child: ManagementCardsWidget(
                  onNavigateReturn: _loadDashboardStatistics,
                ),
              ),

              // Instructor Management Widget
              SliverToBoxAdapter(child: InstructorManagementWidget()),

              // Real-time Statistics
              SliverToBoxAdapter(
                  child: RealtimeStatisticsWidget(
                      key: ValueKey(_statsRefreshKey))),

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
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.25,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return CustomScrollView(
              controller: scrollController,
              shrinkWrap: true,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
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
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        SizedBox(height: 3.h),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildQuickActionTile(
                        'instructor_management.title'.tr(),
                        Icons.person_4,
                        () => Navigator.pushNamed(
                          context,
                          '/instructor-management-system',
                        ),
                      ),
                      _buildQuickActionTile(
                        'receipt.management_title'.tr(),
                        Icons.receipt,
                        () => Navigator.pushNamed(
                          context,
                          '/italian-receipt-generation',
                        ),
                      ),
                      _buildQuickActionTile(
                        'admin_sponsor.title'.tr(),
                        Icons.business,
                        () => Navigator.pushNamed(
                          context,
                          '/admin-sponsor-management',
                        ),
                      ),
                      _buildQuickActionTile(
                        'Palinsesto Stagionale',
                        Icons.calendar_today,
                        () => Navigator.pushNamed(
                          context,
                          '/seasonal-schedule-creation',
                        ),
                      ),
                      _buildQuickActionTile(
                        'admin_event.title'.tr(),
                        Icons.event_note,
                        () => Navigator.pushNamed(
                          context,
                          '/admin-event-management',
                        ),
                      ),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 2.h)),
              ],
            );
          },
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

class _PasswordResetRequestsSheet extends StatefulWidget {
  final dynamic client;
  final VoidCallback onDismiss;
  final void Function(int count)? onCountChanged;

  const _PasswordResetRequestsSheet({
    required this.client,
    required this.onDismiss,
    this.onCountChanged,
  });

  @override
  State<_PasswordResetRequestsSheet> createState() =>
      _PasswordResetRequestsSheetState();
}

class _PasswordResetRequestsSheetState
    extends State<_PasswordResetRequestsSheet> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.client
          .from('password_reset_requests')
          .select(
            'id, user_id, requested_at, status, user_full_name, user_email',
          )
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
        widget.onCountChanged?.call(_requests.length);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRequest(String id) async {
    try {
      final result = await widget.client
          .from('password_reset_requests')
          .delete()
          .eq('id', id)
          .select();
      if (mounted) {
        setState(() => _requests.removeWhere((r) => r['id'].toString() == id));
        widget.onCountChanged?.call(_requests.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'eliminazione')),
        );
      }
    }
  }

  Future<void> _deleteAllRequests() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina tutte le richieste'),
        content: const Text(
          'Sei sicuro di voler eliminare tutte le richieste di reset password?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Elimina tutto',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client
          .from('password_reset_requests')
          .delete()
          .eq('status', 'pending');
      if (mounted) {
        setState(() => _requests.clear());
        widget.onCountChanged?.call(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante l\'eliminazione')),
        );
      }
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_reset, color: Colors.orange, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Richieste Reset Password',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (_requests.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '${_requests.length}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: widget.onDismiss,
                      tooltip: 'Chiudi',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Delete all button
              if (_requests.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deleteAllRequests,
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      label: const Text(
                        'Elimina tutte le richieste',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              // List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.secondary,
                        ),
                      )
                    : _requests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Nessuna richiesta pendente',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _requests.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final req = _requests[index];
                              final fullName =
                                  req['user_full_name'] as String? ??
                                      'Utente sconosciuto';
                              final email = req['user_email'] as String? ?? '';
                              final createdAt = _formatDate(
                                req['requested_at'] as String?,
                              );
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (email.isNotEmpty)
                                            Text(
                                              email,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          Text(
                                            createdAt,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: Colors.orange.withValues(
                                                alpha: 0.8,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Elimina richiesta',
                                      onPressed: () =>
                                          _deleteRequest(req['id'].toString()),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
