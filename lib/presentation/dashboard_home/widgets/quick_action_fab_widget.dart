import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../widgets/role_based_content_widget.dart';

class QuickActionFabWidget extends StatefulWidget {
  final UserRole userRole;

  const QuickActionFabWidget({
    super.key,
    required this.userRole,
  });

  @override
  State<QuickActionFabWidget> createState() => _QuickActionFabWidgetState();
}

class _QuickActionFabWidgetState extends State<QuickActionFabWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Backdrop
        if (_isExpanded)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),

        // Action buttons
        ..._buildActionButtons(),

        // Main FAB
        FloatingActionButton(
          onPressed: _toggleExpanded,
          backgroundColor: AppTheme.secondaryLight,
          child: AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 2 * 3.14159,
                child: CustomIconWidget(
                  iconName: _isExpanded ? 'close' : 'add',
                  color: AppTheme.onSecondaryLight,
                  size: 28,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons() {
    final actions = _getActionsForRole();
    final List<Widget> buttons = [];

    for (int i = 0; i < actions.length; i++) {
      final action = actions[i];
      buttons.add(
        Positioned(
          bottom: 80.0 + (i * 70.0),
          right: 0,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                _toggleExpanded();
                action['onPressed']();
              },
              backgroundColor: action['color'] as Color,
              heroTag: 'fab_${action['label']}',
              child: CustomIconWidget(
                iconName: action['icon'] as String,
                color: AppTheme.onPrimaryLight,
                size: 20,
              ),
            ),
          ),
        ),
      );

      // Add label
      buttons.add(
        Positioned(
          bottom: 88.0 + (i * 70.0),
          right: 60,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: AppTheme.textPrimaryLight.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowLight,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                action['label'] as String,
                style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.onPrimaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  List<Map<String, dynamic>> _getActionsForRole() {
    switch (widget.userRole) {
      case UserRole.student:
        return [
          {
            'label': 'Prenota Lezione',
            'icon': 'book_online',
            'color': AppTheme.primaryLight,
            'onPressed': _handleBookClass,
          },
          {
            'label': 'Vedi Orari',
            'icon': 'schedule',
            'color': AppTheme.warningLight,
            'onPressed': _handleViewSchedule,
          },
          {
            'label': 'profile.upload_certificate'.tr(),
            'icon': 'medical_services',
            'color': AppTheme.successLight,
            'onPressed': _handleUploadCertificate,
          },
        ];

      case UserRole.instructor:
        return [
          {
            'label': 'Segna Presenze',
            'icon': 'how_to_reg',
            'color': AppTheme.primaryLight,
            'onPressed': _handleMarkAttendance,
          },
          {
            'label': 'Vedi Studenti',
            'icon': 'people',
            'color': AppTheme.warningLight,
            'onPressed': _handleViewStudents,
          },
          {
            'label': 'Programma Lezione',
            'icon': 'event',
            'color': AppTheme.successLight,
            'onPressed': _handleScheduleClass,
          },
        ];

      case UserRole.admin:
        return [
          {
            'label': 'Aggiungi Studente',
            'icon': 'person_add',
            'color': AppTheme.primaryLight,
            'onPressed': _handleAddStudent,
          },
          {
            'label': 'Gestisci Pagamenti',
            'icon': 'payment',
            'color': AppTheme.warningLight,
            'onPressed': _handleManagePayments,
          },
          {
            'label': 'Statistiche',
            'icon': 'analytics',
            'color': AppTheme.successLight,
            'onPressed': _handleViewAnalytics,
          },
        ];
    }
  }

  // Student actions
  void _handleBookClass() {
    Navigator.pushNamed(context, '/class-schedule');
  }

  void _handleViewSchedule() {
    Navigator.pushNamed(context, '/class-schedule');
  }

  void _handleUploadCertificate() {
    Navigator.pushNamed(context, '/medical-certificate-upload');
  }

  // Instructor actions
  void _handleMarkAttendance() {
    // Navigate to attendance marking
  }

  void _handleViewStudents() {
    // Navigate to students list
  }

  void _handleScheduleClass() {
    // Navigate to class scheduling
  }

  // Admin actions
  void _handleAddStudent() {
    Navigator.pushNamed(context, '/student-registration');
  }

  void _handleManagePayments() {
    Navigator.pushNamed(context, '/payment-history');
  }

  void _handleViewAnalytics() {
    // Navigate to analytics dashboard
  }
}
