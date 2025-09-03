import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';

enum UserRole { student, instructor, admin }

class RoleBasedContentWidget extends StatefulWidget {
  const RoleBasedContentWidget({super.key});

  @override
  State<RoleBasedContentWidget> createState() => _RoleBasedContentWidgetState();
}

class _RoleBasedContentWidgetState extends State<RoleBasedContentWidget> {
  String? _userRole;
  bool _isLoading = true;
  bool _isAdmin = false;
  Map<String, dynamic>? _adminStatus;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    if (!AuthService.instance.isAuthenticated) {
      if (mounted) {
        setState(() {
          _userRole = 'guest';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Enhanced role loading with better error handling
      final role = await AuthService.instance.getUserRole();
      final isAdminResult = await AuthService.instance.isAdmin();

      print('Loaded user role: $role, isAdmin: $isAdminResult');

      if (mounted) {
        setState(() {
          _userRole = role;
          _isAdmin = isAdminResult;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading user role: $error');

      // Try fallback method for role detection
      try {
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          final profile =
              await AuthService.instance.getUserProfile(currentUser.id);
          final fallbackRole = profile?['role']?.toString() ?? 'student';
          final fallbackIsAdmin = [
            'admin',
            'instructor_admin',
            'principal_admin'
          ].contains(fallbackRole);

          if (mounted) {
            setState(() {
              _userRole = fallbackRole;
              _isAdmin = fallbackIsAdmin;
              _isLoading = false;
            });
          }

          print('Fallback role loading successful: $fallbackRole');
          return;
        }
      } catch (fallbackError) {
        print('Fallback role loading failed: $fallbackError');
      }

      // Final fallback to student role
      if (mounted) {
        setState(() {
          _userRole = 'student';
          _isAdmin = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoleHeader(),
        SizedBox(height: 3.w),
        _buildRoleSpecificContent(),
      ],
    );
  }

  Widget _buildRoleHeader() {
    String roleDisplayName = '';
    Color roleColor = Colors.grey;
    IconData roleIcon = Icons.person;

    switch (_userRole) {
      case 'student':
        roleDisplayName = 'Studente';
        roleColor = Colors.blue;
        roleIcon = Icons.school;
        break;
      case 'instructor':
        roleDisplayName = 'Istruttore';
        roleColor = Colors.green;
        roleIcon = Icons.sports_martial_arts;
        break;
      case 'admin':
        roleDisplayName = 'Amministratore';
        roleColor = Colors.orange;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'instructor_admin':
        roleDisplayName = 'Istruttore Admin';
        roleColor = Colors.orange;
        roleIcon = Icons.supervisor_account;
        break;
      case 'principal_admin':
        roleDisplayName = 'Amministratore Principale';
        roleColor = Colors.red;
        roleIcon = Icons.shield;
        break;
      default:
        roleDisplayName = 'Ruolo non definito';
        roleColor = Colors.grey;
        roleIcon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleColor.withAlpha(26), roleColor.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: roleColor.withAlpha(51)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: roleColor.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(roleIcon, color: roleColor, size: 6.w),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleDisplayName,
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: roleColor,
                  ),
                ),
                if (_adminStatus != null)
                  Text(
                    _getAdminStatusText(),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAdminStatusText() {
    if (_adminStatus == null) return '';

    final isVerified = _adminStatus!['is_verified'] as bool? ?? false;
    final sessionActive = _adminStatus!['session_active'] as bool? ?? false;

    if (isVerified && sessionActive) {
      return 'Sessione attiva e verificata';
    } else if (isVerified) {
      return 'Account verificato';
    } else {
      return 'In attesa di verifica';
    }
  }

  Widget _buildRoleSpecificContent() {
    switch (_userRole) {
      case 'student':
        return _buildStudentContent();
      case 'instructor':
        return _buildInstructorContent();
      case 'admin':
      case 'instructor_admin':
      case 'principal_admin':
        return _buildAdminContent();
      default:
        return _buildDefaultContent();
    }
  }

  Widget _buildStudentContent() {
    return Column(
      children: [
        _buildQuickActionCard(
          'Le Mie Lezioni',
          'Visualizza e prenota lezioni',
          Icons.calendar_today,
          Colors.blue,
          () => Navigator.pushNamed(context, AppRoutes.classSchedule),
        ),
        SizedBox(height: 2.w),
        _buildQuickActionCard(
          'Profilo',
          'Gestisci i tuoi dati',
          Icons.person,
          Colors.green,
          () => Navigator.pushNamed(context, AppRoutes.userProfile),
        ),
      ],
    );
  }

  Widget _buildInstructorContent() {
    return Column(
      children: [
        _buildQuickActionCard(
          'Dashboard Istruttore',
          'Gestisci le tue classi',
          Icons.dashboard,
          Colors.green,
          () => Navigator.pushNamed(context, AppRoutes.instructorDashboard),
        ),
        SizedBox(height: 2.w),
        _buildQuickActionCard(
          'Calendario Lezioni',
          'Visualizza programma',
          Icons.schedule,
          Colors.blue,
          () => Navigator.pushNamed(context, AppRoutes.classSchedule),
        ),
      ],
    );
  }

  Widget _buildAdminContent() {
    return Column(
      children: [
        _buildQuickActionCard(
          'Dashboard Admin',
          'Pannello di controllo',
          Icons.admin_panel_settings,
          Colors.orange,
          () => Navigator.pushNamed(context, AppRoutes.enhancedAdminDashboard),
        ),
        SizedBox(height: 2.w),
        _buildQuickActionCard(
          'Gestione Sistema',
          'Configura piattaforma',
          Icons.settings,
          Colors.red,
          () => Navigator.pushNamed(context, AppRoutes.adminManagementSystem),
        ),
      ],
    );
  }

  Widget _buildDefaultContent() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(77)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 8.w),
          SizedBox(height: 2.w),
          Text(
            'Ruolo non riconosciuto',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
          SizedBox(height: 1.w),
          Text(
            'Contatta l\'amministratore per verificare il tuo account',
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(26),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 6.w),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 1.w),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade600,
              size: 4.w,
            ),
          ],
        ),
      ),
    );
  }
}
