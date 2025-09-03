import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
// Add this import

import '../../constants/app_constants.dart';
import './widgets/attendance_tracking_widget.dart';
import './widgets/dashboard_header_widget.dart';
import './widgets/notification_center_widget.dart';
import './widgets/quick_actions_fab_widget.dart';
import './widgets/revenue_analytics_widget.dart';
import './widgets/student_progress_widget.dart';
import './widgets/today_classes_widget.dart';

class InstructorDashboard extends StatefulWidget {
  const InstructorDashboard({Key? key}) : super(key: key);

  @override
  State<InstructorDashboard> createState() => _InstructorDashboardState();
}

class _InstructorDashboardState extends State<InstructorDashboard>
    with TickerProviderStateMixin {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildInstructorQuickAccess() {
    final quickActions = [
      {
        'title': 'Palinsesto Classi',
        'subtitle': 'Gestisci le tue lezioni',
        'icon': Icons.event_note,
        'route': '/class-schedule',
        'color': Theme.of(context).colorScheme.secondary,
      },
      {
        'title': 'Presenze Studenti',
        'subtitle': 'Segna presenze oggi',
        'icon': Icons.how_to_reg,
        'route': '/attendance-tracking',
        'color': Colors.green,
      },
      {
        'title': 'Elenco Studenti',
        'subtitle': 'Visualizza i tuoi studenti',
        'icon': Icons.group,
        'route': '/instructor-directory',
        'color': Colors.blue,
      },
      {
        'title': 'Analisi Progressi',
        'subtitle': 'Monitora miglioramenti',
        'icon': Icons.trending_up,
        'route': '/student-progress',
        'color': Colors.orange,
      },
    ];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accesso Rapido Istruttore',
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
                    Navigator.pushNamed(context, action['route'] as String);
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
                            action['icon'] as IconData,
                            color: action['color'] as Color,
                            size: 24,
                          ),
                        ),
                        SizedBox(height: 1.5.h),
                        Text(
                          action['title'] as String,
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
                          action['subtitle'] as String,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard Istruttore',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            // Open drawer or navigation menu
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              _showNotificationCenter();
            },
          ),
          Image.asset(
            AppConstants.teamLogo,
            width: 8.w,
            height: 4.h,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _handleRefresh,
        color: Theme.of(context).colorScheme.secondary,
        backgroundColor: Theme.of(context).cardColor,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                // Quick Access Section
                _buildInstructorQuickAccess(),

                SizedBox(height: 2.h),

                DashboardHeaderWidget(),
                SizedBox(height: 3.h),
                TodayClassesWidget(),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Expanded(child: StudentProgressWidget()),
                    SizedBox(width: 3.w),
                    Expanded(child: AttendanceTrackingWidget()),
                  ],
                ),
                SizedBox(height: 3.h),
                RevenueAnalyticsWidget(),
                SizedBox(height: 3.h),
                NotificationCenterWidget(),
                SizedBox(height: 10.h), // Space for FAB
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: QuickActionsFabWidget(
        onClassCreated: _refreshDashboard,
        onProgressUpdated: _refreshDashboard,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    // Simulate API calls with haptic feedback
    await Future.delayed(Duration(milliseconds: 1500));

    // Add haptic feedback for successful refresh
    try {
      // In a real app, you would call: HapticFeedback.lightImpact();
    } catch (e) {
      // Handle platforms that don't support haptic feedback
    }

    setState(() {
      _isRefreshing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.onSecondary),
            SizedBox(width: 2.w),
            Text(
              'Dashboard aggiornata!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondary,
                  ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _refreshDashboard() {
    setState(() {
      // Trigger rebuild of dashboard widgets
    });
  }

  void _showNotificationCenter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Centro Notifiche',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Mark all as read
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Segna tutto letto',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationCenterWidget(isFullScreen: true),
            ),
          ],
        ),
      ),
    );
  }
}