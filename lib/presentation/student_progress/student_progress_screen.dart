import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({super.key});

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;

  // Belt data: list of {discipline, belt_color, strips, assigned_at}
  List<Map<String, dynamic>> _belts = [];

  // Bookings per discipline
  // { discipline: { 'total': int, 'monthly': { 'YYYY-MM': int }, 'annual': { 'YYYY': int } } }
  Map<String, Map<String, dynamic>> _bookingStats = {};

  late TabController _tabController;

  static const List<Map<String, dynamic>> _beltColors = [
    {
      'key': 'white',
      'label': 'Bianca',
      'color': Color(0xFFF5F5F5),
      'textColor': Color(0xFF333333),
    },
    {
      'key': 'yellow',
      'label': 'Gialla',
      'color': Color(0xFFFFD600),
      'textColor': Color(0xFF333333),
    },
    {
      'key': 'orange',
      'label': 'Arancione',
      'color': Color(0xFFFF6D00),
      'textColor': Colors.white,
    },
    {
      'key': 'green',
      'label': 'Verde',
      'color': Color(0xFF2E7D32),
      'textColor': Colors.white,
    },
    {
      'key': 'blue',
      'label': 'Blu',
      'color': Color(0xFF1565C0),
      'textColor': Colors.white,
    },
    {
      'key': 'purple',
      'label': 'Viola',
      'color': Color(0xFF6A1B9A),
      'textColor': Colors.white,
    },
    {
      'key': 'brown',
      'label': 'Marrone',
      'color': Color(0xFF5D4037),
      'textColor': Colors.white,
    },
    {
      'key': 'black',
      'label': 'Nera',
      'color': Color(0xFF212121),
      'textColor': Colors.white,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final userId = AuthService.instance.currentUser?.id;
      if (userId == null) throw Exception('Utente non autenticato');

      // Load belts
      final beltsRaw = await _client
          .from('member_belts')
          .select('discipline, belt_color, strips, assigned_at')
          .eq('user_id', userId)
          .order('discipline');

      final List<Map<String, dynamic>> belts = List<Map<String, dynamic>>.from(
        beltsRaw,
      );

      // Load bookings (class_registrations joined with schedule instances)
      // We fetch all bookings for this user
      final bookingsRaw = await _client
          .from('class_registrations')
          .select(
            'id, created_at, schedule_instance_id, schedule_instances(discipline, class_date)',
          )
          .eq('user_id', userId)
          .eq('registration_status', 'registered');

      final Map<String, Map<String, dynamic>> stats = {};

      for (final booking in bookingsRaw) {
        final instance = booking['schedule_instances'];
        if (instance == null) continue;
        final discipline = (instance['discipline'] ?? 'altro')
            .toString()
            .toLowerCase();
        final dateStr = instance['class_date']?.toString() ?? '';

        stats.putIfAbsent(
          discipline,
          () => {
            'total': 0,
            'monthly': <String, int>{},
            'annual': <String, int>{},
          },
        );

        stats[discipline]!['total'] = (stats[discipline]!['total'] as int) + 1;

        if (dateStr.isNotEmpty) {
          try {
            final date = DateTime.parse(dateStr);
            final monthKey =
                '${date.year}-${date.month.toString().padLeft(2, '0')}';
            final yearKey = '${date.year}';

            final monthly = stats[discipline]!['monthly'] as Map<String, int>;
            monthly[monthKey] = (monthly[monthKey] ?? 0) + 1;

            final annual = stats[discipline]!['annual'] as Map<String, int>;
            annual[yearKey] = (annual[yearKey] ?? 0) + 1;
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _belts = belts;
          _bookingStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getBeltColor(String key) {
    final found = _beltColors.firstWhere(
      (b) => b['key'] == key,
      orElse: () => _beltColors.first,
    );
    return found['color'] as Color;
  }

  Color _getBeltTextColor(String key) {
    final found = _beltColors.firstWhere(
      (b) => b['key'] == key,
      orElse: () => _beltColors.first,
    );
    return found['textColor'] as Color;
  }

  String _getBeltLabel(String key) {
    final found = _beltColors.firstWhere(
      (b) => b['key'] == key,
      orElse: () => _beltColors.first,
    );
    return found['label'] as String;
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '—';
    }
  }

  String _monthLabel(String key) {
    // key = YYYY-MM
    final parts = key.split('-');
    if (parts.length < 2) return key;
    const months = [
      '',
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${months[m]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryRed = const Color(0xFFCC0000);
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Progressi Studente',
          style: GoogleFonts.dmSans(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryRed,
          labelColor: primaryRed,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Lezioni'),
            Tab(text: 'Cinture & Strips'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryRed))
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [_buildLessonsTab(isDark), _buildBeltsTab(isDark)],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text('Errore nel caricamento', style: GoogleFonts.dmSans()),
          TextButton(onPressed: _loadData, child: const Text('Riprova')),
        ],
      ),
    );
  }

  // ─── LESSONS TAB ────────────────────────────────────────────────────────────

  Widget _buildLessonsTab(bool isDark) {
    if (_bookingStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_martial_arts,
              size: 48,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 2.h),
            Text(
              'Nessuna lezione prenotata',
              style: GoogleFonts.dmSans(fontSize: 14.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFCC0000),
      child: ListView(
        padding: EdgeInsets.all(3.w),
        children: [
          _buildTotalSummaryCard(isDark),
          SizedBox(height: 2.h),
          ..._bookingStats.entries.map(
            (e) => _buildDisciplineCard(e.key, e.value, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard(bool isDark) {
    final total = _bookingStats.values.fold<int>(
      0,
      (sum, v) => sum + (v['total'] as int),
    );
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCC0000), Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC0000).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sports_martial_arts,
              color: Colors.white,
              size: 7.w,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lezioni Totali',
                  style: GoogleFonts.dmSans(
                    fontSize: 12.sp,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '$total',
                  style: GoogleFonts.dmSans(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_bookingStats.length} discipline',
                  style: GoogleFonts.dmSans(
                    fontSize: 11.sp,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplineCard(
    String discipline,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final total = data['total'] as int;
    final monthly = Map<String, int>.from(data['monthly'] as Map);
    final annual = Map<String, int>.from(data['annual'] as Map);

    // Sort monthly descending
    final sortedMonthly = monthly.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final sortedAnnual = annual.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          childrenPadding: EdgeInsets.only(left: 4.w, right: 4.w, bottom: 2.h),
          leading: Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: const Color(0xFFCC0000).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(
              Icons.sports_martial_arts,
              color: const Color(0xFFCC0000),
              size: 5.w,
            ),
          ),
          title: Text(
            discipline.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            '$total lezioni totali',
            style: GoogleFonts.dmSans(fontSize: 11.sp, color: Colors.grey),
          ),
          children: [
            // Monthly breakdown
            if (sortedMonthly.isNotEmpty) ...[
              _sectionTitle('Resoconto Mensile', isDark),
              SizedBox(height: 1.h),
              ...sortedMonthly.map(
                (e) =>
                    _statRow(_monthLabel(e.key), '${e.value} lezioni', isDark),
              ),
              SizedBox(height: 1.5.h),
            ],
            // Annual breakdown
            if (sortedAnnual.isNotEmpty) ...[
              _sectionTitle('Resoconto Annuale', isDark),
              SizedBox(height: 1.h),
              ...sortedAnnual.map(
                (e) => _statRow(e.key, '${e.value} lezioni', isDark),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFCC0000),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _statRow(String label, String value, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ─── BELTS TAB ───────────────────────────────────────────────────────────────

  Widget _buildBeltsTab(bool isDark) {
    if (_belts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.military_tech, size: 48, color: Colors.grey.shade400),
            SizedBox(height: 2.h),
            Text(
              'Nessuna cintura assegnata',
              style: GoogleFonts.dmSans(fontSize: 14.sp, color: Colors.grey),
            ),
            SizedBox(height: 1.h),
            Text(
              'Il tuo coach assegnerà le cinture dopo la valutazione',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFCC0000),
      child: ListView(
        padding: EdgeInsets.all(3.w),
        children: _belts.map((belt) => _buildBeltCard(belt, isDark)).toList(),
      ),
    );
  }

  Widget _buildBeltCard(Map<String, dynamic> belt, bool isDark) {
    final discipline = (belt['discipline'] ?? '').toString();
    final colorKey = (belt['belt_color'] ?? 'white').toString();
    final strips = (belt['strips'] ?? 0) as int;
    final assignedAt = belt['assigned_at']?.toString();

    final beltColor = _getBeltColor(colorKey);
    final beltTextColor = _getBeltTextColor(colorKey);
    final beltLabel = _getBeltLabel(colorKey);
    final isWhite = beltColor == const Color(0xFFF5F5F5);

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          // Belt color header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: beltColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16.0),
              ),
              border: isWhite
                  ? Border.all(color: Colors.grey.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.military_tech,
                  color: isWhite ? Colors.black54 : Colors.white,
                  size: 6.w,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discipline.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: isWhite ? Colors.black54 : Colors.white70,
                        ),
                      ),
                      Text(
                        'Cintura $beltLabel',
                        style: GoogleFonts.dmSans(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: beltTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Strips visual
                if (strips > 0)
                  Row(
                    children: List.generate(
                      strips,
                      (_) => Container(
                        width: 5,
                        height: 24,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          color: isWhite
                              ? Colors.black38
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                _detailRow(
                  Icons.local_police,
                  'Strips',
                  strips == 0
                      ? 'Nessuna strip'
                      : '$strips strip${strips > 1 ? 's' : ''}',
                  isDark,
                ),
                SizedBox(height: 1.5.h),
                _detailRow(
                  Icons.calendar_today,
                  'Data Promozione',
                  _formatDate(assignedAt),
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 4.w, color: const Color(0xFFCC0000)),
        SizedBox(width: 2.w),
        Text(
          '$label:',
          style: GoogleFonts.dmSans(
            fontSize: 12.sp,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
