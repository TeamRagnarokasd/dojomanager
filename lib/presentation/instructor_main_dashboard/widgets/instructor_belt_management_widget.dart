import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstructorBeltManagementWidget extends StatefulWidget {
  final String instructorId;
  const InstructorBeltManagementWidget({Key? key, required this.instructorId})
    : super(key: key);

  @override
  State<InstructorBeltManagementWidget> createState() =>
      _InstructorBeltManagementWidgetState();
}

class _InstructorBeltManagementWidgetState
    extends State<InstructorBeltManagementWidget> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _members = [];
  Map<String, Map<String, dynamic>> _beltsByUser = {};
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  // Disciplines this instructor is allowed to assign belts for
  List<String> _allowedDisciplines = [];
  bool _isPrincipalAdmin = false;

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

  // All possible disciplines (fallback if instructor profile has none)
  static const List<String> _allDisciplines = [
    'bjj',
    'mma',
    'grappling',
    'sambo',
    'kickboxing',
    'fitness',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Step 1: Determine instructor's role and allowed disciplines
      await _loadInstructorDisciplines();

      // Step 2: Load members
      final members = await _client
          .from('user_profiles')
          .select('id, full_name, first_name, last_name, profile_image_url')
          .inFilter('role', ['student', 'instructor_student'])
          .eq('status', 'approved')
          .order('full_name');

      final List<Map<String, dynamic>> membersList =
          List<Map<String, dynamic>>.from(members);

      // Step 3: Load belts
      final belts = await _client
          .from('member_belts')
          .select('user_id, discipline, belt_color, strips, assigned_at');

      final Map<String, Map<String, dynamic>> beltMap = {};
      for (final b in belts) {
        final userId = b['user_id'] as String;
        final discipline = b['discipline'] as String;
        beltMap['${userId}_$discipline'] = Map<String, dynamic>.from(b);
      }

      if (mounted) {
        setState(() {
          _members = membersList;
          _beltsByUser = beltMap;
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

  /// Loads the instructor's profile to determine which disciplines they can
  /// assign belts for. Principal admins can assign for all disciplines.
  Future<void> _loadInstructorDisciplines() async {
    try {
      // Check user role first
      final userProfile = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', widget.instructorId)
          .maybeSingle();

      final role = userProfile?['role'] as String? ?? '';
      _isPrincipalAdmin = role == 'principal_admin';

      if (_isPrincipalAdmin) {
        // Principal admin (Daniele Prizzi) can assign belts for ALL disciplines
        _allowedDisciplines = List<String>.from(_allDisciplines);
        return;
      }

      // For instructors, load their instructor_profiles to get disciplines
      final instructorProfile = await _client
          .from('instructor_profiles')
          .select('disciplines, primary_discipline')
          .eq('user_id', widget.instructorId)
          .maybeSingle();

      if (instructorProfile != null) {
        final disciplines = List<String>.from(
          instructorProfile['disciplines'] ?? [],
        );
        final primary = instructorProfile['primary_discipline'] as String?;

        // Combine primary + disciplines list, deduplicate
        final Set<String> disciplineSet = {};
        if (primary != null && primary.isNotEmpty) {
          disciplineSet.add(primary.toLowerCase());
        }
        for (final d in disciplines) {
          if (d.isNotEmpty) disciplineSet.add(d.toLowerCase());
        }

        _allowedDisciplines = disciplineSet.toList();
      }

      // Fallback: if no disciplines found in profile, use all (shouldn't happen)
      if (_allowedDisciplines.isEmpty) {
        _allowedDisciplines = List<String>.from(_allDisciplines);
      }
    } catch (e) {
      // On error, fallback to all disciplines
      _allowedDisciplines = List<String>.from(_allDisciplines);
    }
  }

  String _getUserName(Map<String, dynamic> member) {
    final full = member['full_name'] ?? '';
    if (full.isNotEmpty) return full;
    final first = member['first_name'] ?? '';
    final last = member['last_name'] ?? '';
    return '$first $last'.trim().isNotEmpty ? '$first $last'.trim() : 'Utente';
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    return _members.where((m) {
      final name = _getUserName(m).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Map<String, dynamic>? _getBeltForUser(String userId, String discipline) {
    return _beltsByUser['${userId}_$discipline'];
  }

  Color _getBeltColor(String colorKey) {
    final found = _beltColors.firstWhere(
      (b) => b['key'] == colorKey,
      orElse: () => _beltColors.first,
    );
    return found['color'] as Color;
  }

  String _getBeltLabel(String colorKey) {
    final found = _beltColors.firstWhere(
      (b) => b['key'] == colorKey,
      orElse: () => _beltColors.first,
    );
    return found['label'] as String;
  }

  Future<void> _showBeltEditor(Map<String, dynamic> member) async {
    final userId = member['id'] as String;
    final name = _getUserName(member);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BeltEditorSheet(
        memberName: name,
        userId: userId,
        instructorId: widget.instructorId,
        disciplines: _allowedDisciplines,
        beltColors: _beltColors,
        existingBelts: _beltsByUser,
        onSaved: _loadData,
      ),
    );
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

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primaryRed,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show which disciplines this instructor can assign belts for
                  if (!_isPrincipalAdmin && _allowedDisciplines.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: 1.5.h),
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryRed.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryRed, size: 16),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'Puoi assegnare cinture per: ${_allowedDisciplines.map((d) => d.toUpperCase()).join(', ')}',
                              style: GoogleFonts.dmSans(
                                fontSize: 11.sp,
                                color: primaryRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    '${_filteredMembers.length} membri – tocca per assegnare cintura',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_filteredMembers.isEmpty)
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
                  (ctx, i) => _buildMemberBeltCard(_filteredMembers[i], isDark),
                  childCount: _filteredMembers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberBeltCard(Map<String, dynamic> member, bool isDark) {
    final userId = member['id'] as String;
    final name = _getUserName(member);

    // Get all belts for this user
    final userBelts = _beltsByUser.entries
        .where((e) => e.key.startsWith('${userId}_'))
        .map((e) => e.value)
        .toList();

    return GestureDetector(
      onTap: () => _showBeltEditor(member),
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCC0000).withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.dmSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFCC0000),
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
                  SizedBox(height: 0.5.h),
                  if (userBelts.isEmpty)
                    Text(
                      'Nessuna cintura assegnata',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        color: Colors.grey,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 1.w,
                      runSpacing: 0.5.h,
                      children: userBelts.map((belt) {
                        final colorKey = belt['belt_color'] ?? 'white';
                        final strips = belt['strips'] ?? 0;
                        final beltColor = _getBeltColor(colorKey);
                        final discipline = belt['discipline'] ?? '';
                        return _BeltBadge(
                          discipline: discipline,
                          beltColor: beltColor,
                          strips: strips,
                          label: _getBeltLabel(colorKey),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              color: isDark ? Colors.white38 : Colors.black26,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _BeltBadge extends StatelessWidget {
  final String discipline;
  final Color beltColor;
  final int strips;
  final String label;

  const _BeltBadge({
    required this.discipline,
    required this.beltColor,
    required this.strips,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: beltColor,
        borderRadius: BorderRadius.circular(6),
        border: beltColor == const Color(0xFFF5F5F5)
            ? Border.all(color: Colors.grey.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            discipline.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: beltColor == const Color(0xFFF5F5F5)
                  ? Colors.black54
                  : Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              color: beltColor == const Color(0xFFF5F5F5)
                  ? Colors.black54
                  : Colors.white70,
            ),
          ),
          if (strips > 0) ...[
            const SizedBox(width: 4),
            ...List.generate(
              strips,
              (_) => Container(
                width: 4,
                height: 12,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BeltEditorSheet extends StatefulWidget {
  final String memberName;
  final String userId;
  final String instructorId;
  final List<String> disciplines;
  final List<Map<String, dynamic>> beltColors;
  final Map<String, Map<String, dynamic>> existingBelts;
  final VoidCallback onSaved;

  const _BeltEditorSheet({
    required this.memberName,
    required this.userId,
    required this.instructorId,
    required this.disciplines,
    required this.beltColors,
    required this.existingBelts,
    required this.onSaved,
  });

  @override
  State<_BeltEditorSheet> createState() => _BeltEditorSheetState();
}

class _BeltEditorSheetState extends State<_BeltEditorSheet> {
  final _client = Supabase.instance.client;
  late String _selectedDiscipline;
  late String _selectedBelt;
  late int _selectedStrips;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDiscipline = widget.disciplines.isNotEmpty
        ? widget.disciplines.first
        : 'bjj';
    _loadExistingForDiscipline();
  }

  void _loadExistingForDiscipline() {
    final key = '${widget.userId}_$_selectedDiscipline';
    final existing = widget.existingBelts[key];
    _selectedBelt = existing?['belt_color'] ?? 'white';
    _selectedStrips = existing?['strips'] ?? 0;
  }

  Future<void> _saveBelt() async {
    setState(() => _isSaving = true);
    try {
      await _client.from('member_belts').upsert({
        'user_id': widget.userId,
        'discipline': _selectedDiscipline,
        'belt_color': _selectedBelt,
        'strips': _selectedStrips,
        'assigned_by': widget.instructorId,
        'assigned_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,discipline');

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cintura aggiornata per ${widget.memberName}',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore nel salvataggio',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryRed = const Color(0xFFCC0000);
    final selectedBeltData = widget.beltColors.firstWhere(
      (b) => b['key'] == _selectedBelt,
      orElse: () => widget.beltColors.first,
    );
    final beltColor = selectedBeltData['color'] as Color;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 4.w,
        right: 4.w,
        top: 2.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 2.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 10.w,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Assegna Cintura',
              style: GoogleFonts.dmSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              widget.memberName,
              style: GoogleFonts.dmSans(fontSize: 13.sp, color: primaryRed),
            ),
            SizedBox(height: 2.h),

            // Discipline selector — only shows allowed disciplines
            Text(
              'Disciplina',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            SizedBox(height: 1.h),
            widget.disciplines.isEmpty
                ? Text(
                    'Nessuna disciplina disponibile',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  )
                : Wrap(
                    spacing: 2.w,
                    runSpacing: 1.h,
                    children: widget.disciplines.map((d) {
                      final isSelected = d == _selectedDiscipline;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDiscipline = d;
                            _loadExistingForDiscipline();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryRed
                                : (isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF5F5F5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            d.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            SizedBox(height: 2.h),

            // Belt color selector
            Text(
              'Colore Cintura',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: widget.beltColors.map((b) {
                final isSelected = b['key'] == _selectedBelt;
                final bc = b['color'] as Color;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedBelt = b['key'] as String;
                    _selectedStrips = 0;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bc,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: primaryRed, width: 3)
                          : (bc == const Color(0xFFF5F5F5)
                                ? Border.all(
                                    color: Colors.grey.withValues(alpha: 0.4),
                                  )
                                : null),
                    ),
                    child: Text(
                      b['label'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: b['textColor'] as Color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 2.h),

            // Strips selector
            Text(
              'Strips (0–4)',
              style: GoogleFonts.dmSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            SizedBox(height: 1.h),
            Row(
              children: List.generate(5, (i) {
                final isSelected = i == _selectedStrips;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStrips = i),
                  child: Container(
                    margin: EdgeInsets.only(right: 2.w),
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? beltColor
                          : (isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF5F5F5)),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: primaryRed, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$i',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? (beltColor == const Color(0xFFF5F5F5)
                                        ? Colors.black87
                                        : Colors.white)
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                          if (i > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                i,
                                (_) => Container(
                                  width: 3,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (beltColor == const Color(0xFFF5F5F5)
                                              ? Colors.black38
                                              : Colors.white70)
                                        : Colors.grey.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 3.h),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSaving || widget.disciplines.isEmpty)
                    ? null
                    : _saveBelt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Salva Cintura',
                        style: GoogleFonts.dmSans(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
