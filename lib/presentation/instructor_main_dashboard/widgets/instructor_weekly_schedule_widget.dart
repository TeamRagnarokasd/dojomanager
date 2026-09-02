import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InstructorWeeklyScheduleWidget extends StatefulWidget {
  final String instructorId;
  const InstructorWeeklyScheduleWidget({Key? key, required this.instructorId})
    : super(key: key);

  @override
  State<InstructorWeeklyScheduleWidget> createState() =>
      _InstructorWeeklyScheduleWidgetState();
}

class _InstructorWeeklyScheduleWidgetState
    extends State<InstructorWeeklyScheduleWidget> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _weekClasses = [];
  DateTime _selectedWeekStart = DateTime.now();
  String? _error;
  bool _reminderDismissed = false;

  // Dynamic discipline colors fetched from DB (custom_disciplines.color_hex)
  Map<String, Color> _disciplineColors = {};

  // Fallback colors for built-in disciplines not in custom_disciplines
  static const Map<String, Color> _fallbackColors = {
    'bjj': Color(0xFF1565C0),
    'mma': Color(0xFFB71C1C),
    'grappling': Color(0xFF2E7D32),
    'sambo': Color(0xFF6A1B9A),
    'fitness': Color(0xFFE65100),
    'kickboxing': Color(0xFFE65100),
  };

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _getWeekStart(DateTime.now());
    _loadDisciplineColors().then((_) => _loadWeekSchedule());
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _loadDisciplineColors() async {
    try {
      final response = await _client
          .from('custom_disciplines')
          .select('name, color_hex')
          .eq('is_active', true);
      final Map<String, Color> colors = {};
      for (final row in response) {
        final name = (row['name'] ?? '').toString().toLowerCase().trim();
        final hex = (row['color_hex'] ?? '').toString();
        if (name.isNotEmpty && hex.isNotEmpty) {
          final color = _parseColor(hex);
          // Store under original name (e.g. "total submission kids")
          colors[name] = color;
          // Also store under underscore variant (e.g. "total_submission_kids")
          final underscoreKey = name.replaceAll(' ', '_');
          if (underscoreKey != name) colors[underscoreKey] = color;
          // Also store under space variant in case DB uses underscores
          final spaceKey = name.replaceAll('_', ' ');
          if (spaceKey != name) colors[spaceKey] = color;
        }
      }
      if (mounted) {
        setState(() {
          _disciplineColors = colors;
        });
      }
    } catch (_) {
      // Silently fall back to static colors
    }
  }

  Color _parseColor(String colorHex) {
    try {
      final hexCode = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (_) {
      return const Color(0xFF757575);
    }
  }

  Color _getColorForDiscipline(String discipline) {
    final key = discipline.toLowerCase().trim();
    // Try exact match
    if (_disciplineColors.containsKey(key)) return _disciplineColors[key]!;
    // Try replacing underscores with spaces (e.g. "total_submission_kids" → "total submission kids")
    final spaceKey = key.replaceAll('_', ' ');
    if (_disciplineColors.containsKey(spaceKey))
      return _disciplineColors[spaceKey]!;
    // Try replacing spaces with underscores
    final underscoreKey = key.replaceAll(' ', '_');
    if (_disciplineColors.containsKey(underscoreKey))
      return _disciplineColors[underscoreKey]!;
    // Fallback to static colors
    return _fallbackColors[key] ??
        _fallbackColors[spaceKey] ??
        _fallbackColors[underscoreKey] ??
        const Color(0xFF757575);
  }

  Future<void> _loadWeekSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final start = _selectedWeekStart;
      final end = start.add(const Duration(days: 6));
      final startStr = DateFormat('yyyy-MM-dd').format(start);
      final endStr = DateFormat('yyyy-MM-dd').format(end);

      // Query ALL schedule instances for the week (not just instructor's own)
      // so the schedule is fully synchronized with the real palinsesto
      final response = await _client
          .from('schedule_instances')
          .select(
            'id, class_date, start_time, end_time, discipline, location, max_capacity, is_cancelled, instructor_id',
          )
          .gte('class_date', startStr)
          .lte('class_date', endStr)
          .order('class_date', ascending: true)
          .order('start_time', ascending: true);

      if (mounted) {
        setState(() {
          _weekClasses = List<Map<String, dynamic>>.from(response);
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

  void _changeWeek(int delta) {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.add(Duration(days: 7 * delta));
      _reminderDismissed = false;
    });
    _loadWeekSchedule();
  }

  /// Returns today's lessons assigned to this instructor
  List<Map<String, dynamic>> get _todayInstructorLessons {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _weekClasses.where((cls) {
      return cls['class_date'] == today &&
          cls['instructor_id'] == widget.instructorId;
    }).toList();
  }

  bool get _isCurrentWeek {
    final currentWeekStart = _getWeekStart(DateTime.now());
    return _selectedWeekStart.isAtSameMomentAs(currentWeekStart);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryRed = const Color(0xFFCC0000);

    return RefreshIndicator(
      onRefresh: _loadWeekSchedule,
      color: primaryRed,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildWeekNavigator(isDark, primaryRed)),

          // In-app reminder banner for today's lessons
          if (_isCurrentWeek &&
              !_reminderDismissed &&
              _todayInstructorLessons.isNotEmpty)
            SliverToBoxAdapter(child: _buildReminderBanner(isDark)),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFCC0000)),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 40),
                    SizedBox(height: 8),
                    Text('Errore nel caricamento', style: GoogleFonts.dmSans()),
                    TextButton(
                      onPressed: _loadWeekSchedule,
                      child: Text('Riprova'),
                    ),
                  ],
                ),
              ),
            )
          else if (_weekClasses.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'Nessuna lezione questa settimana',
                      style: GoogleFonts.dmSans(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.all(3.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildClassCard(_weekClasses[i], isDark),
                  childCount: _weekClasses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderBanner(bool isDark) {
    final lessons = _todayInstructorLessons;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCC0000), Color(0xFFFF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFCC0000).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Promemoria: Hai ${lessons.length} lezione${lessons.length > 1 ? 'i' : ''} oggi!',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _reminderDismissed = true),
                child: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lessons.map((lesson) {
            final discipline = (lesson['discipline'] ?? '')
                .toString()
                .toUpperCase();
            final startTime = lesson['start_time'] ?? '';
            final endTime = lesson['end_time'] ?? '';
            final location = lesson['location'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sports_martial_arts,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discipline,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$startTime – $endTime',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator(bool isDark, Color primaryRed) {
    final endOfWeek = _selectedWeekStart.add(const Duration(days: 6));
    final label =
        '${DateFormat('d MMM', 'it_IT').format(_selectedWeekStart)} – ${DateFormat('d MMM yyyy', 'it_IT').format(endOfWeek)}';
    return Container(
      margin: EdgeInsets.all(3.w),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: primaryRed),
            onPressed: () => _changeWeek(-1),
          ),
          Column(
            children: [
              Text(
                'Settimana',
                style: GoogleFonts.dmSans(fontSize: 11.sp, color: Colors.grey),
              ),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: primaryRed),
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls, bool isDark) {
    final discipline = (cls['discipline'] ?? '').toString().toLowerCase();
    final color = _getColorForDiscipline(discipline);
    final date = DateTime.tryParse(cls['class_date'] ?? '') ?? DateTime.now();
    final dayLabel = DateFormat('EEEE d MMMM', 'it_IT').format(date);
    final isCancelled = cls['is_cancelled'] == true;
    final isMyLesson = cls['instructor_id'] == widget.instructorId;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: isMyLesson ? 5 : 4),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isMyLesson ? 0.18 : 0.06),
            blurRadius: isMyLesson ? 12 : 8,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(3.w),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          discipline.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      if (isMyLesson) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFCC0000,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFFCC0000,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 10,
                                color: Color(0xFFCC0000),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'La tua lezione',
                                style: GoogleFonts.dmSans(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFCC0000),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isCancelled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ANNULLATA',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    dayLabel.capitalize(),
                    style: GoogleFonts.dmSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey),
                      SizedBox(width: 1.w),
                      Text(
                        '${cls['start_time'] ?? ''} – ${cls['end_time'] ?? ''}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(Icons.location_on, size: 14, color: Colors.grey),
                      SizedBox(width: 1.w),
                      Expanded(
                        child: Text(
                          cls['location'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Icon(Icons.group, size: 18, color: color),
                SizedBox(height: 0.5.h),
                Text(
                  '${cls['max_capacity'] ?? 0}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  'max',
                  style: GoogleFonts.dmSans(fontSize: 9.sp, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
