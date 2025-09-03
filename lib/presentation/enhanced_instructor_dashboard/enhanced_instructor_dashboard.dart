import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import './widgets/class_history_section_widget.dart';
import './widgets/instructor_dashboard_header_widget.dart';
import './widgets/instructor_notification_center_widget.dart';
import './widgets/quick_actions_panel_widget.dart';
import './widgets/revenue_analytics_card_widget.dart';
import './widgets/student_progress_management_widget.dart';
import './widgets/todays_classes_section_widget.dart';

class EnhancedInstructorDashboard extends StatefulWidget {
  const EnhancedInstructorDashboard({Key? key}) : super(key: key);

  @override
  State<EnhancedInstructorDashboard> createState() =>
      _EnhancedInstructorDashboardState();
}

class _EnhancedInstructorDashboardState
    extends State<EnhancedInstructorDashboard> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isLoading = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeInstructorDashboard();
  }

  Future<void> _initializeInstructorDashboard() async {
    setState(() => _isLoading = true);
    try {
      // Initialize instructor dashboard data
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      print('Instructor dashboard initialization error: $e');
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
        // Stay on instructor dashboard
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.classSchedule);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.instructorDirectory);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.userProfile);
        break;
    }
  }

  void _onQuickAction() {
    HapticFeedback.mediumImpact();
    _showQuickActionDialog();
  }

  void _showQuickActionDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF404040) : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Azioni Rapide',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickActionItem(
                'Crea Nuova Classe', Icons.add_circle_outline, isDark),
            _buildQuickActionItem(
                'Aggiorna Progresso Studente', Icons.trending_up, isDark),
            _buildQuickActionItem(
                'Registra Presenze', Icons.check_circle_outline, isDark),
            _buildQuickActionItem(
                'Invia Messaggio', Icons.message_outlined, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem(String title, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFF0000).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFFF0000), size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[400],
        ),
        onTap: () {
          Navigator.pop(context);
          // Handle action
        },
      ),
    );
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
            // Header
            SliverToBoxAdapter(
              child: InstructorDashboardHeaderWidget(isLoading: _isLoading),
            ),

            // Main Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Today's Classes
                  TodaysClassesSectionWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Student Progress Management
                  StudentProgressManagementWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Revenue Analytics
                  RevenueAnalyticsCardWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Quick Actions Panel
                  QuickActionsPanelWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Notification Center
                  InstructorNotificationCenterWidget(isLoading: _isLoading),

                  const SizedBox(height: 24),

                  // Class History
                  ClassHistorySectionWidget(isLoading: _isLoading),
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
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Istruttori',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profilo',
            ),
          ],
        ),
      ),

      // Floating Action Button for Quick Actions
      floatingActionButton: FloatingActionButton(
        onPressed: _onQuickAction,
        backgroundColor: const Color(0xFFFF0000), // Team Ragnarok red
        foregroundColor: Colors.white,
        elevation: 4.0,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
