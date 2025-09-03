import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import './widgets/quick_access_cards_widget.dart';
import './widgets/recent_activity_feed_widget.dart';
import './widgets/subscription_status_widget.dart';
import './widgets/training_progress_widget.dart';
import './widgets/user_dashboard_header_widget.dart';

class EnhancedUserDashboard extends StatefulWidget {
  const EnhancedUserDashboard({Key? key}) : super(key: key);

  @override
  State<EnhancedUserDashboard> createState() => _EnhancedUserDashboardState();
}

class _EnhancedUserDashboardState extends State<EnhancedUserDashboard> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isLoading = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);
    try {
      // Initialize dashboard data
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      print('Dashboard initialization error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1200));
    } catch (e) {
      print('Refresh error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onBottomNavTap(int index) {
    setState(() => _selectedIndex = index);
    HapticFeedback.selectionClick();

    switch (index) {
      case 0:
        // Stay on dashboard
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.classSchedule);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.userProfile);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.receiptArchive);
        break;
    }
  }

  void _onQuickBooking() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, AppRoutes.classSchedule);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _onRefresh,
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : theme.cardColor,
        color: const Color(0xFFFF0000), // Team Ragnarok red
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App Bar Header
            SliverToBoxAdapter(
              child: UserDashboardHeaderWidget(isLoading: _isLoading),
            ),

            // Main Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Quick Access Cards
                  QuickAccessCardsWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Training Progress
                  TrainingProgressWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Subscription Status
                  SubscriptionStatusWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Recent Activity Feed
                  RecentActivityFeedWidget(isLoading: _isLoading),
                ]),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar with dark theme
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A1A1A)
              : theme.bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF404040) : theme.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFFF0000), // Team Ragnarok red
          unselectedItemColor: isDark
              ? const Color(0xFFE0E0E0)
              : theme.bottomNavigationBarTheme.unselectedItemColor,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Classi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profilo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Ricevute',
            ),
          ],
        ),
      ),

      // Floating Action Button for Quick Booking
      floatingActionButton: FloatingActionButton(
        onPressed: _onQuickBooking,
        backgroundColor: const Color(0xFFFF0000), // Team Ragnarok red
        foregroundColor: Colors.white,
        elevation: 4.0,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}