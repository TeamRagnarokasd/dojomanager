import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';

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
  final List<Map<String, dynamic>> _bottomNavItems = [
    {
      'label': 'Home',
      'icon': 'home',
      'route': AppRoutes.dashboardHome,
    },
    {
      'label': 'Classi',
      'icon': 'school',
      'route': AppRoutes.classSchedule,
    },
    {
      'label': 'Pagamenti',
      'icon': 'payment',
      'route': AppRoutes.paymentHistory,
    },
    {
      'label': 'Profilo',
      'icon': 'person',
      'route': AppRoutes.userProfile,
    },
  ];

  void _handleBottomNavTap(int index) {
    if (index == widget.currentIndex) return;

    HapticFeedback.selectionClick();

    final route = _bottomNavItems[index]['route'] as String;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
          backgroundColor:
              Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          selectedItemColor:
              Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor:
              Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          elevation: 0,
          items: _bottomNavItems.map((item) {
            final index = _bottomNavItems.indexOf(item);
            return BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.symmetric(vertical: 0.5.h),
                child: CustomIconWidget(
                  iconName: item['icon'] as String,
                  color: index == widget.currentIndex
                      ? Theme.of(context)
                          .bottomNavigationBarTheme
                          .selectedItemColor!
                      : Theme.of(context)
                          .bottomNavigationBarTheme
                          .unselectedItemColor!,
                  size: 24,
                ),
              ),
              activeIcon: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.2),
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
    );
  }
}
