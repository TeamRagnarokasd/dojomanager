import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/instructor_service.dart';
import '../../services/sponsor_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/instructor_attendance_stats_widget.dart';
import './widgets/instructor_belt_management_widget.dart';
import './widgets/instructor_class_bookings_widget.dart';
import './widgets/instructor_weekly_schedule_widget.dart';

class InstructorMainDashboard extends StatefulWidget {
  const InstructorMainDashboard({Key? key}) : super(key: key);

  @override
  State<InstructorMainDashboard> createState() =>
      _InstructorMainDashboardState();
}

class _InstructorMainDashboardState extends State<InstructorMainDashboard>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _instructorProfile;
  String _instructorName = '';
  String _instructorId = '';
  String? _profileImageUrl;
  String? _roleTitle;
  String? _userRole;

  // Stats
  int _totalClassesThisWeek = 0;
  int _totalStudentsBooked = 0;
  int _totalActiveMembers = 0;

  // Sponsors
  List<Map<String, dynamic>> _sponsors = [];
  bool _sponsorsLoading = true;

  // Team instructors
  List<InstructorProfile> _teamInstructors = [];
  bool _instructorsLoading = true;

  // Realtime subscription
  RealtimeChannel? _scheduleChannel;

  static const Color _primaryRed = Color(0xFFCC0000);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAll();
    _subscribeToScheduleChanges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scheduleChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadInstructorData(),
      _loadSponsors(),
      _loadTeamInstructors(),
    ]);
  }

  void _subscribeToScheduleChanges() {
    _scheduleChannel = _client
        .channel('instructor_schedule_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'schedule_instances',
          callback: (payload) {
            if (mounted) {
              _loadStats();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'weekly_schedule_templates',
          callback: (payload) {
            if (mounted) {
              _loadStats();
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadInstructorData() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }
      _instructorId = userId;

      final profile = await _client
          .from('user_profiles')
          .select(
            'full_name, first_name, last_name, profile_image_url, role_title, role',
          )
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _instructorProfile = profile;
          _instructorName =
              profile?['full_name'] ??
              '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'
                  .trim();
          if (_instructorName.isEmpty) _instructorName = 'Istruttore';
          _profileImageUrl = profile?['profile_image_url'];
          _roleTitle = profile?['role_title'];
          _userRole = profile?['role'];
          _isLoading = false;
        });
      }
      await _loadStats();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final weekStart = _getWeekStart(DateTime.now());
      final weekEnd = weekStart.add(const Duration(days: 6));
      final startStr = DateFormat('yyyy-MM-dd').format(weekStart);
      final endStr = DateFormat('yyyy-MM-dd').format(weekEnd);

      // Il capo istruttore (principal_admin) vede le lezioni e le
      // statistiche di tutti gli istruttori e tutte le discipline, senza
      // filtro per instructor_id. _userRole è già stato letto da
      // user_profiles in _loadInstructorData prima di ogni chiamata a
      // _loadStats.
      final isPrincipalAdmin = _userRole == 'principal_admin';

      // Classes this week for this instructor (or all, for principal_admin)
      final baseClassesQuery = _client
          .from('schedule_instances')
          .select('id')
          .gte('class_date', startStr)
          .lte('class_date', endStr)
          .eq('is_cancelled', false);
      final classes = isPrincipalAdmin
          ? await baseClassesQuery
          : await baseClassesQuery.eq('instructor_id', _instructorId);

      final classIds = (classes as List).map((c) => c['id'] as String).toList();

      int bookedCount = 0;
      if (classIds.isNotEmpty) {
        final bookings = await _client
            .from('class_registrations')
            .select('id')
            .inFilter('schedule_instance_id', classIds)
            .eq('registration_status', 'registered');
        bookedCount = (bookings as List).length;
      }

      // Active members
      final members = await _client
          .from('user_profiles')
          .select('id')
          .inFilter('role', ['student', 'instructor_student'])
          .eq('status', 'approved');

      if (mounted) {
        setState(() {
          _totalClassesThisWeek = (classes as List).length;
          _totalStudentsBooked = bookedCount;
          _totalActiveMembers = (members as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSponsors() async {
    try {
      final sponsors = await SponsorService.getActiveSponsors();
      if (mounted) {
        setState(() {
          _sponsors = sponsors;
          _sponsorsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sponsorsLoading = false);
    }
  }

  Future<void> _loadTeamInstructors() async {
    try {
      final instructors = await InstructorService.getInstructors();
      if (mounted) {
        setState(() {
          _teamInstructors = instructors
              .where((i) => i.isActive)
              .take(6)
              .toList();
          _instructorsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _instructorsLoading = false);
    }
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Logout',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Sei sicuro di voler uscire?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Esci', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (r) => false,
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MainNavigationWrapper(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF111111)
            : const Color(0xFFF5F5F5),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: _primaryRed))
            : RefreshIndicator(
                onRefresh: _onRefresh,
                color: _primaryRed,
                backgroundColor: isDark
                    ? const Color(0xFF1A1A1A)
                    : Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(child: _buildHeader(isDark)),

                    // Stats Row
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _buildStatsRow(isDark),
                      ),
                    ),

                    // Quick Actions
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _buildQuickActions(isDark),
                      ),
                    ),

                    // Schedule Section (with tabs)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _buildScheduleSection(isDark),
                      ),
                    ),

                    // Instructor Team Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _buildInstructorTeamSection(isDark),
                      ),
                    ),

                    // Sponsors Section
                    if (_sponsors.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: _buildSponsorsSection(isDark),
                        ),
                      ),

                    // Bottom padding
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF404040) : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF404040) : Colors.grey[200],
              border: Border.all(color: _primaryRed, width: 2),
            ),
            child: ClipOval(
              child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _profileImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.sports_martial_arts,
                        size: 24,
                        color: _primaryRed,
                      ),
                    )
                  : Icon(
                      Icons.sports_martial_arts,
                      size: 24,
                      color: _primaryRed,
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciao, $_instructorName',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _roleTitle ?? 'Istruttore',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _primaryRed,
                  ),
                ),
              ],
            ),
          ),

          // Date + Logout
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('EEE d MMM', 'it_IT').format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_userRole == 'principal_admin' ||
                      _userRole == 'instructor_admin') ...[
                    Tooltip(
                      message: 'Torna a Vista Admin',
                      child: InkWell(
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          '/enhanced-admin-dashboard',
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _primaryRed.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            size: 16,
                            color: _primaryRed,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_userRole == 'instructor_student') ...[
                    Tooltip(
                      message: 'Passa a Vista Allievo',
                      child: InkWell(
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          '/dashboard-home',
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.teal.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 16,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 14,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Esci',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            icon: Icons.calendar_today,
            label: 'Lezioni\nSettimana',
            value: '$_totalClassesThisWeek',
            color: _primaryRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            icon: Icons.people,
            label: 'Prenotati\nSettimana',
            value: '$_totalStudentsBooked',
            color: const Color(0xFF2ECC71),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            icon: Icons.sports_martial_arts,
            label: 'Membri\nAttivi',
            value: '$_totalActiveMembers',
            color: const Color(0xFF3498DB),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey[600],
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Actions ────────────────────────────────────────────────────────
  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accesso Rapido',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                title: 'Palinsesto',
                subtitle: 'Settimana corrente',
                icon: Icons.calendar_month,
                color: _primaryRed,
                onTap: () => _tabController.animateTo(0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                title: 'Prenotati',
                subtitle: 'Chi si è iscritto',
                icon: Icons.how_to_reg,
                color: const Color(0xFF2ECC71),
                onTap: () => _tabController.animateTo(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                title: 'Frequenze',
                subtitle: 'Statistiche presenze',
                icon: Icons.bar_chart,
                color: const Color(0xFF3498DB),
                onTap: () => _tabController.animateTo(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                isDark: isDark,
                title: 'Cinture',
                subtitle: 'Gestione gradi',
                icon: Icons.military_tech,
                color: const Color(0xFF9B59B6),
                onTap: () => _tabController.animateTo(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const Spacer(),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Schedule Section with Tabs ───────────────────────────────────────────
  Widget _buildScheduleSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primaryRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.event_note, color: _primaryRed, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Gestione Classi',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF27AE60),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Live',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF404040) : Colors.grey[200]!,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF222222)
                      : const Color(0xFFF8F8F8),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: _primaryRed,
                  indicatorWeight: 3,
                  labelColor: _primaryRed,
                  unselectedLabelColor: isDark
                      ? Colors.white54
                      : Colors.black45,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.calendar_view_week, size: 18),
                      text: 'Palinsesto',
                    ),
                    Tab(
                      icon: Icon(Icons.how_to_reg, size: 18),
                      text: 'Prenotati',
                    ),
                    Tab(
                      icon: Icon(Icons.bar_chart, size: 18),
                      text: 'Frequenze',
                    ),
                    Tab(
                      icon: Icon(Icons.military_tech, size: 18),
                      text: 'Cinture',
                    ),
                  ],
                ),
              ),
              // Tab Content
              SizedBox(
                height: 55.h,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    InstructorWeeklyScheduleWidget(instructorId: _instructorId),
                    InstructorClassBookingsWidget(instructorId: _instructorId),
                    InstructorAttendanceStatsWidget(
                      instructorId: _instructorId,
                    ),
                    InstructorBeltManagementWidget(instructorId: _instructorId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Instructor Team Section ──────────────────────────────────────────────
  Widget _buildInstructorTeamSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.groups,
                color: Color(0xFF2ECC71),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Team Istruttori',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.instructorDirectory),
              style: TextButton.styleFrom(
                foregroundColor: _primaryRed,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Vedi tutti',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_instructorsLoading)
          Container(
            height: 100,
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: _primaryRed),
          )
        else if (_teamInstructors.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF404040) : Colors.grey[200]!,
              ),
            ),
            child: Center(
              child: Text(
                'Nessun istruttore trovato',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _teamInstructors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final instructor = _teamInstructors[index];
                return _buildInstructorChip(instructor, isDark);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildInstructorChip(InstructorProfile instructor, bool isDark) {
    final isMe = instructor.userId == _instructorId;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.instructorDirectory),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe
                ? _primaryRed
                : isDark
                ? const Color(0xFF404040)
                : Colors.grey[200]!,
            width: isMe ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF333333) : Colors.grey[100],
                border: Border.all(
                  color: isMe ? _primaryRed : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: instructor.displayImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: instructor.displayImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.person,
                          size: 24,
                          color: isDark ? Colors.white54 : Colors.grey[500],
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 24,
                        color: isDark ? Colors.white54 : Colors.grey[500],
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                instructor.fullName?.split(' ').first ?? 'N/A',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (isMe)
              Text(
                'Tu',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: _primaryRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Sponsors Section ─────────────────────────────────────────────────────
  Widget _buildSponsorsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF39C12).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.store,
                color: Color(0xFFF39C12),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I Nostri Sponsor e Partner',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Partner ufficiali del Team Ragnarok',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 14),
        ..._sponsors.map((sponsor) => _buildSponsorCard(sponsor, isDark)),
      ],
    );
  }

  Widget _buildSponsorCard(Map<String, dynamic> sponsor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final url = sponsor['external_url'] as String?;
            if (url != null && url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        sponsor['image_url'] != null &&
                            (sponsor['image_url'] as String).isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: sponsor['image_url'] as String,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.store,
                              color: Colors.grey[400],
                              size: 28,
                            ),
                          )
                        : Icon(Icons.store, color: Colors.grey[400], size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sponsor['name'] ?? 'Sponsor',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (sponsor['description'] != null &&
                          (sponsor['description'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          sponsor['description'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
