import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class InstructorClassBookingsWidget extends StatefulWidget {
  final String instructorId;
  const InstructorClassBookingsWidget({Key? key, required this.instructorId})
      : super(key: key);

  @override
  State<InstructorClassBookingsWidget> createState() =>
      _InstructorClassBookingsWidgetState();
}

class _InstructorClassBookingsWidgetState
    extends State<InstructorClassBookingsWidget> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingClasses = [];
  Map<String, List<Map<String, dynamic>>> _bookingsByClass = {};
  String? _selectedClassId;
  String? _error;

  // Dynamic discipline colors fetched from DB
  Map<String, Color> _disciplineColors = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadDisciplineColors();
    await _loadUpcomingClasses();
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
        final hex = (row['color_hex'] ?? '').toString().trim();
        if (name.isNotEmpty && hex.isNotEmpty) {
          final color = _hexToColor(hex);
          colors[name] = color;
          colors[name.replaceAll(' ', '_')] = color;
          colors[name.replaceAll('_', ' ')] = color;
        }
      }
      if (mounted) setState(() => _disciplineColors = colors);
    } catch (e) {
      // fallback: keep empty map, _getColor will use grey
    }
  }

  Color _hexToColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF757575);
  }

  Color _getColor(String discipline) {
    final key = discipline.toLowerCase().trim();
    if (_disciplineColors.containsKey(key)) return _disciplineColors[key]!;
    final spaceKey = key.replaceAll('_', ' ');
    if (_disciplineColors.containsKey(spaceKey))
      return _disciplineColors[spaceKey]!;
    final underKey = key.replaceAll(' ', '_');
    if (_disciplineColors.containsKey(underKey))
      return _disciplineColors[underKey]!;
    return const Color(0xFF757575);
  }

  Future<void> _loadUpcomingClasses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final endDate = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime.now().add(const Duration(days: 14)));

      // Il capo istruttore (principal_admin) vede le lezioni di tutti gli
      // istruttori e tutte le discipline, senza filtro per instructor_id.
      var isPrincipalAdmin = false;
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId != null) {
        try {
          final currentUserProfile = await _client
              .from('user_profiles')
              .select('role')
              .eq('id', currentUserId)
              .maybeSingle();
          isPrincipalAdmin = currentUserProfile?['role'] == 'principal_admin';
        } catch (_) {
          isPrincipalAdmin = false;
        }
      }

      final baseQuery = _client
          .from('schedule_instances')
          .select(
            'id, class_date, start_time, end_time, discipline, location, max_capacity, is_cancelled',
          )
          .eq('is_cancelled', false)
          .gte('class_date', today)
          .lte('class_date', endDate);
      final scopedQuery = isPrincipalAdmin
          ? baseQuery
          : baseQuery.eq('instructor_id', widget.instructorId);

      final classes = await scopedQuery
          .order('class_date', ascending: true)
          .order('start_time', ascending: true);

      final List<Map<String, dynamic>> classesList =
          List<Map<String, dynamic>>.from(classes);

      // Load bookings for each class
      final Map<String, List<Map<String, dynamic>>> bookings = {};
      for (final cls in classesList) {
        final classId = cls['id'] as String;
        try {
          final regs = await _client
              .from('class_registrations')
              .select(
                'id, registration_status, registered_at, user_profiles!class_registrations_user_id_fkey(full_name, first_name, last_name, profile_image_url)',
              )
              .eq('schedule_instance_id', classId)
              .eq('registration_status', 'registered');
          bookings[classId] = List<Map<String, dynamic>>.from(regs);
        } catch (_) {
          bookings[classId] = [];
        }
      }

      if (mounted) {
        setState(() {
          _upcomingClasses = classesList;
          _bookingsByClass = bookings;
          if (classesList.isNotEmpty)
            _selectedClassId = classesList.first['id'] as String;
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

  String _getUserName(Map<String, dynamic> profile) {
    final full = profile['full_name'] ?? '';
    if (full.isNotEmpty) return full;
    final first = profile['first_name'] ?? '';
    final last = profile['last_name'] ?? '';
    final combined = '$first $last'.trim();
    return combined.isNotEmpty ? combined : 'Utente';
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
            TextButton(onPressed: _loadData, child: Text('Riprova')),
          ],
        ),
      );
    }
    if (_upcomingClasses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Nessuna lezione nei prossimi 14 giorni',
              style: GoogleFonts.dmSans(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final selectedClass = _upcomingClasses.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => _upcomingClasses.first,
    );
    final bookings = _bookingsByClass[_selectedClassId] ?? [];
    final maxCapacity = selectedClass['max_capacity'] ?? 0;
    final discipline = (selectedClass['discipline'] ?? '').toString();
    final color = _getColor(discipline);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primaryRed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(3.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class selector
            Text(
              'Seleziona lezione',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            SizedBox(height: 1.h),
            SizedBox(
              height: 10.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _upcomingClasses.length,
                itemBuilder: (ctx, i) {
                  final cls = _upcomingClasses[i];
                  final isSelected = cls['id'] == _selectedClassId;
                  final d = (cls['discipline'] ?? '').toString();
                  final c = _getColor(d);
                  final date = DateTime.tryParse(cls['class_date'] ?? '') ??
                      DateTime.now();
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedClassId = cls['id'] as String),
                    child: Container(
                      width: 28.w,
                      margin: EdgeInsets.only(right: 2.w),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? c
                            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? c : c.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(2.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            d.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : c,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            DateFormat('d MMM', 'it_IT').format(date),
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: isSelected ? Colors.white70 : Colors.grey,
                            ),
                          ),
                          Text(
                            cls['start_time']?.toString().substring(0, 5) ?? '',
                            style: GoogleFonts.dmSans(
                              fontSize: 10.sp,
                              color: isSelected ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 2.h),

            // Booking summary
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: color, width: 4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('EEEE d MMMM', 'it_IT').format(DateTime.tryParse(selectedClass['class_date'] ?? '') ?? DateTime.now())} – ${selectedClass['start_time']?.toString().substring(0, 5) ?? ''}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          selectedClass['location'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${bookings.length}/$maxCapacity',
                        style: GoogleFonts.dmSans(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      Text(
                        'prenotati',
                        style: GoogleFonts.dmSans(
                          fontSize: 10.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 2.h),

            // Capacity bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: maxCapacity > 0 ? bookings.length / maxCapacity : 0,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            SizedBox(height: 2.h),

            // Bookings list
            Text(
              'Iscritti (${bookings.length})',
              style: GoogleFonts.dmSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            SizedBox(height: 1.h),
            if (bookings.isEmpty)
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Nessuna prenotazione per questa lezione',
                    style: GoogleFonts.dmSans(color: Colors.grey),
                  ),
                ),
              )
            else
              ...bookings.asMap().entries.map((entry) {
                final i = entry.key;
                final booking = entry.value;
                final profile =
                    booking['user_profiles'] as Map<String, dynamic>? ?? {};
                final name = _getUserName(profile);
                return Container(
                  margin: EdgeInsets.only(bottom: 1.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 1.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.dmSans(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
