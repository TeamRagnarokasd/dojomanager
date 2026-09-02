import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InstructorAttendanceStatsWidget extends StatefulWidget {
  final String instructorId;
  const InstructorAttendanceStatsWidget({Key? key, required this.instructorId})
    : super(key: key);

  @override
  State<InstructorAttendanceStatsWidget> createState() =>
      _InstructorAttendanceStatsWidgetState();
}

class _InstructorAttendanceStatsWidgetState
    extends State<InstructorAttendanceStatsWidget> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _memberStats = [];
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAttendanceStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Get all active members
      final members = await _client
          .from('user_profiles')
          .select(
            'id, full_name, first_name, last_name, profile_image_url, status',
          )
          .inFilter('role', ['student', 'instructor_student'])
          .eq('status', 'approved')
          .order('full_name');

      final List<Map<String, dynamic>> membersList =
          List<Map<String, dynamic>>.from(members);

      // Get class registrations for the last 90 days
      final since = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().subtract(const Duration(days: 90)));

      final registrations = await _client
          .from('class_registrations')
          .select(
            'user_id, registration_status, registered_at, schedule_instances!class_registrations_schedule_instance_id_fkey(class_date, discipline, instructor_id)',
          )
          .eq('registration_status', 'registered')
          .gte('registered_at', since);

      final List<Map<String, dynamic>> regList =
          List<Map<String, dynamic>>.from(registrations);

      // Compute stats per member
      final stats = membersList.map((member) {
        final userId = member['id'] as String;
        final userRegs = regList.where((r) => r['user_id'] == userId).toList();
        final total = userRegs.length;

        // Last attendance
        DateTime? lastAttendance;
        for (final r in userRegs) {
          final instance = r['schedule_instances'] as Map<String, dynamic>?;
          if (instance != null) {
            final d = DateTime.tryParse(instance['class_date'] ?? '');
            if (d != null &&
                (lastAttendance == null || d.isAfter(lastAttendance))) {
              lastAttendance = d;
            }
          }
        }

        // Monthly breakdown (last 3 months)
        final now = DateTime.now();
        final monthly = <String, int>{};
        for (int m = 2; m >= 0; m--) {
          final month = DateTime(now.year, now.month - m, 1);
          final key = DateFormat('MMM', 'it_IT').format(month);
          monthly[key] = userRegs.where((r) {
            final instance = r['schedule_instances'] as Map<String, dynamic>?;
            if (instance == null) return false;
            final d = DateTime.tryParse(instance['class_date'] ?? '');
            return d != null && d.year == month.year && d.month == month.month;
          }).length;
        }

        return {
          ...member,
          'total_attendances': total,
          'last_attendance': lastAttendance,
          'monthly_stats': monthly,
        };
      }).toList();

      // Sort by total attendances descending
      stats.sort(
        (a, b) => (b['total_attendances'] as int).compareTo(
          a['total_attendances'] as int,
        ),
      );

      if (mounted) {
        setState(() {
          _memberStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  String _getUserName(Map<String, dynamic> member) {
    final full = member['full_name'] ?? '';
    if (full.isNotEmpty) return full;
    final first = member['first_name'] ?? '';
    final last = member['last_name'] ?? '';
    return '$first $last'.trim().isNotEmpty ? '$first $last'.trim() : 'Utente';
  }

  List<Map<String, dynamic>> get _filteredStats {
    if (_searchQuery.isEmpty) return _memberStats;
    return _memberStats.where((m) {
      final name = _getUserName(m).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryRed = const Color(0xFFCC0000);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryRed));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 40),
            SizedBox(height: 8),
            Text('Errore nel caricamento', style: GoogleFonts.dmSans()),
            TextButton(onPressed: _loadAttendanceStats, child: Text('Riprova')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendanceStats,
      color: primaryRed,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.dmSans(fontSize: 13.sp),
                    decoration: InputDecoration(
                      hintText: 'Cerca membro...',
                      hintStyle: GoogleFonts.dmSans(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.5.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    '${_filteredStats.length} membri – ultimi 90 giorni',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_filteredStats.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'Nessun membro trovato',
                  style: GoogleFonts.dmSans(color: Colors.grey),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildMemberCard(_filteredStats[i], isDark, i),
                  childCount: _filteredStats.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, bool isDark, int rank) {
    final name = _getUserName(member);
    final total = member['total_attendances'] as int;
    final lastAttendance = member['last_attendance'] as DateTime?;
    final monthly = member['monthly_stats'] as Map<String, int>? ?? {};
    final maxMonthly = monthly.values.isEmpty
        ? 1
        : monthly.values.reduce((a, b) => a > b ? a : b);
    final primaryRed = const Color(0xFFCC0000);

    Color rankColor;
    if (rank == 0)
      rankColor = const Color(0xFFFFD700);
    else if (rank == 1)
      rankColor = const Color(0xFFC0C0C0);
    else if (rank == 2)
      rankColor = const Color(0xFFCD7F32);
    else
      rankColor = Colors.grey;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rankColor.withValues(alpha: 0.15),
                  border: Border.all(color: rankColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${rank + 1}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: rankColor,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lastAttendance != null)
                      Text(
                        'Ultima presenza: ${DateFormat('d MMM yyyy', 'it_IT').format(lastAttendance)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.sp,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: GoogleFonts.dmSans(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: primaryRed,
                    ),
                  ),
                  Text(
                    'presenze',
                    style: GoogleFonts.dmSans(
                      fontSize: 9.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          // Monthly bars
          Row(
            children: monthly.entries.map((entry) {
              final barHeight = maxMonthly > 0
                  ? (entry.value / maxMonthly)
                  : 0.0;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1.w),
                  child: Column(
                    children: [
                      Text(
                        '${entry.value}',
                        style: GoogleFonts.dmSans(
                          fontSize: 9.sp,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Container(
                        height: 4.h,
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: barHeight > 0 ? barHeight : 0.05,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barHeight > 0
                                  ? primaryRed.withValues(
                                      alpha: 0.7 + barHeight * 0.3,
                                    )
                                  : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        entry.key,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
