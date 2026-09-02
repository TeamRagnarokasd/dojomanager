import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../services/auth_service.dart';
import './realtime_notification_overlay.dart';

class MainNavigationWrapper extends StatefulWidget {
  final Widget child;
  final int currentIndex;

  const MainNavigationWrapper({
    Key? key,
    required this.child,
    required this.currentIndex,
  }) : super(key: key);

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  final AuthService _authService = AuthService.instance;

  List<Map<String, dynamic>> _bottomNavItems(BuildContext context) => [
        {
          'label': 'nav.home'.tr(),
          'icon': 'home',
          'route': AppRoutes.dashboardHome,
        },
        {
          'label': 'nav.classes'.tr(),
          'icon': 'school',
          'route': AppRoutes.classSchedule,
        },
        {
          'label': 'nav.payments'.tr(),
          'icon': 'payment',
          'route': AppRoutes.paymentHistory,
        },
        {
          'label': 'nav.profile'.tr(),
          'icon': 'person',
          'route': AppRoutes.userProfile,
        },
      ];

  int _currentIndex = 0;

  /// Handle bottom navigation tap with role-based home routing
  void _handleBottomNavTap(int index) async {
    if (index == widget.currentIndex) return;

    HapticFeedback.selectionClick();

    // Special handling for Home button (index 0) - route to appropriate dashboard based on user role
    if (index == 0) {
      await _navigateToRoleBasedDashboard();
    } else {
      final route = _bottomNavItems(context)[index]['route'] as String;
      Navigator.pushReplacementNamed(context, route);
    }
  }

  /// Navigate to the appropriate dashboard based on user role
  Future<void> _navigateToRoleBasedDashboard() async {
    try {
      // Get user role to determine correct dashboard
      final userRole = await _authService.getUserRole();

      String dashboardRoute;

      // Determine dashboard route based on role
      switch (userRole) {
        case 'principal_admin':
        case 'admin':
          dashboardRoute = AppRoutes.enhancedAdminDashboard;
          break;
        case 'instructor':
        case 'instructor_admin':
          dashboardRoute = AppRoutes.instructorMainDashboard;
          break;
        case 'student':
        default:
          dashboardRoute = AppRoutes.dashboardHome;
          break;
      }

      // Navigate to the appropriate dashboard
      Navigator.pushReplacementNamed(context, dashboardRoute);
    } catch (error) {
      print('Error determining dashboard route: $error');
      Navigator.pushReplacementNamed(context, AppRoutes.dashboardHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RealtimeNotificationOverlay(
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: widget.currentIndex,
            onTap: _handleBottomNavTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.backgroundColor,
            selectedItemColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.selectedItemColor,
            unselectedItemColor: Theme.of(
              context,
            ).bottomNavigationBarTheme.unselectedItemColor,
            selectedLabelStyle: GoogleFonts.inter(
              fontSize: 13.sp < 13 ? 13 : 13.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 13.sp < 13 ? 13 : 13.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
            elevation: 0,
            items: _bottomNavItems(context).map((item) {
              final index = _bottomNavItems(context).indexOf(item);
              return BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.symmetric(vertical: 0.5.h),
                  child: CustomIconWidget(
                    iconName: item['icon'] as String,
                    color: index == widget.currentIndex
                        ? Theme.of(
                            context,
                          ).bottomNavigationBarTheme.selectedItemColor!
                        : Theme.of(
                            context,
                          ).bottomNavigationBarTheme.unselectedItemColor!,
                    size: 24,
                  ),
                ),
                activeIcon: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 0.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CustomIconWidget(
                    iconName: item['icon'] as String,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 24,
                  ),
                ),
                label: item['label'] as String,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
