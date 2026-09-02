import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_export.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/discipline_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model for a single grid cell entry
// ─────────────────────────────────────────────────────────────────────────────
class _GridEntry {
  final String id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String? disciplineId;
  final String? disciplineName;
  final String? instructorId;
  final String? instructorName;
  final String location;

  _GridEntry({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.disciplineId,
    this.disciplineName,
    this.instructorId,
    this.instructorName,
    this.location = 'Sala 1° piano',
  });

  _GridEntry copyWith({
    String? disciplineId,
    String? disciplineName,
    String? instructorId,
    String? instructorName,
    String? location,
    String? startTime,
    String? endTime,
  }) {
    return _GridEntry(
      id: id,
      dayOfWeek: dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      disciplineId: disciplineId ?? this.disciplineId,
      disciplineName: disciplineName ?? this.disciplineName,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toSlotMap() => {
    'id': id,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'location': location,
    'discipline_id': disciplineId,
    'discipline_name': disciplineName,
    'instructor_id': instructorId,
    'instructor_name': instructorName,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Resize drag state
// ─────────────────────────────────────────────────────────────────────────────
class _ResizeDragState {
  final String entryId;
  final bool isBottom; // true = dragging bottom border, false = top border
  double accumulatedDelta = 0.0;

  _ResizeDragState({required this.entryId, required this.isBottom});
}

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class SeasonalScheduleCreation extends StatefulWidget {
  const SeasonalScheduleCreation({Key? key}) : super(key: key);

  @override
  State<SeasonalScheduleCreation> createState() =>
      _SeasonalScheduleCreationState();
}

class _SeasonalScheduleCreationState extends State<SeasonalScheduleCreation>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();

  // Season period
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));

  // Grid entries (replaces _weeklySlots)
  final List<_GridEntry> _entries = [];

  // Data from DB
  List<Map<String, dynamic>> _disciplines = [];
  bool _isLoadingDisciplines = true;
  bool _isGenerating = false;

  // Existing schedules
  List<Map<String, dynamic>> _existingSchedules = [];
  bool _isLoadingSchedules = false;

  String? _editingScheduleId;

  // Resize drag tracking
  _ResizeDragState? _resizeDrag;

  // Tab controller for switching between grid and list views
  late TabController _tabController;

  // ── Grid visible time range ──────────────────────────────────────────────
  String _gridStartTime = '07:00';
  String _gridEndTime = '22:00';

  List<String> get _visibleTimeSlots {
    final startIdx = _timeSlots.indexOf(_gridStartTime);
    final endIdx = _timeSlots.indexOf(_gridEndTime);
    if (startIdx < 0 || endIdx < 0 || startIdx >= endIdx) return _timeSlots;
    return _timeSlots.sublist(startIdx, endIdx);
  }

  // ── Time slots shown in the grid (left column) ──────────────────────────
  static const List<String> _timeSlots = [
    '07:00',
    '07:30',
    '08:00',
    '08:30',
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00',
    '18:30',
    '19:00',
    '19:30',
    '20:00',
    '20:30',
    '21:00',
    '21:30',
    '22:00',
  ];

  static const List<String> _orderedDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  Map<String, String> get _dayLabels => {
    'monday': 'Lun',
    'tuesday': 'Mar',
    'wednesday': 'Mer',
    'thursday': 'Gio',
    'friday': 'Ven',
    'saturday': 'Sab',
    'sunday': 'Dom',
  };

  Map<String, String> get _dayLabelsFull => {
    'monday': 'Lunedì',
    'tuesday': 'Martedì',
    'wednesday': 'Mercoledì',
    'thursday': 'Giovedì',
    'friday': 'Venerdì',
    'saturday': 'Sabato',
    'sunday': 'Domenica',
  };

  // Italian public holidays
  static const List<Map<String, int>> _fixedHolidays = [
    {'month': 1, 'day': 1},
    {'month': 1, 'day': 6},
    {'month': 4, 'day': 25},
    {'month': 5, 'day': 1},
    {'month': 6, 'day': 2},
    {'month': 8, 'day': 15},
    {'month': 11, 'day': 1},
    {'month': 12, 'day': 8},
    {'month': 12, 'day': 25},
    {'month': 12, 'day': 26},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAdminAccess();
    _loadDisciplines();
    _loadExistingSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hScrollController.dispose();
    _vScrollController.dispose();
    super.dispose();
  }

  // ── Auth ─────────────────────────────────────────────────────────────────
  Future<void> _checkAdminAccess() async {
    if (!AuthService.instance.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/login-screen');
      return;
    }
    final role = await AuthService.instance.getUserRole();
    if (!['admin', 'principal_admin', 'instructor_admin'].contains(role)) {
      Navigator.pushReplacementNamed(context, '/dashboard-home');
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────
  Future<void> _loadDisciplines() async {
    try {
      final disciplines = await DisciplineService.instance
          .getActiveDisciplines();
      if (mounted) {
        setState(() {
          _disciplines = disciplines
              .map(
                (d) => <String, dynamic>{
                  'id': d['id'] as String,
                  'name': (d['name'] ?? d['id']) as String,
                  'color': d['color'],
                },
              )
              .toList();
          _disciplines.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
          _isLoadingDisciplines = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDisciplines = false);
    }
  }

  Future<void> _loadExistingSchedules() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final response = await _supabase
          .from('seasonal_schedules')
          .select('id, title, start_date, end_date, status, created_at')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _existingSchedules = List<Map<String, dynamic>>.from(response);
          _isLoadingSchedules = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSchedules = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadInstructorsForDiscipline(
    String disciplineId,
  ) async {
    try {
      final response = await _supabase
          .from('instructor_profiles')
          .select('user_id, user_profiles!inner(id, full_name)')
          .eq('is_active', true)
          .contains('disciplines', [disciplineId]);
      return (response as List<dynamic>).map((item) {
        final up = item['user_profiles'];
        return <String, dynamic>{
          'id': up['id'] as String,
          'full_name': up['full_name'] as String? ?? 'Istruttore',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Grid helpers ─────────────────────────────────────────────────────────

  /// Returns entries for a specific day+time cell
  List<_GridEntry> _entriesForCell(String day, String time) {
    return _entries
        .where((e) => e.dayOfWeek == day && e.startTime == time)
        .toList();
  }

  /// Open popup to add/edit a cell
  Future<void> _openCellDialog(
    String day,
    String time, {
    _GridEntry? existing,
  }) async {
    final theme = Theme.of(context);

    // Pre-fill values
    String selectedDisciplineId =
        existing?.disciplineId ??
        (_disciplines.isNotEmpty ? _disciplines.first['id'] as String : '');
    String selectedDisciplineName =
        existing?.disciplineName ??
        (_disciplines.isNotEmpty ? _disciplines.first['name'] as String : '');
    String selectedLocation = existing?.location ?? 'Sala 1° piano';
    String? selectedInstructorId = existing?.instructorId;
    String? selectedInstructorName = existing?.instructorName;
    String selectedEndTime = existing?.endTime ?? _nextTimeSlot(time);

    List<Map<String, dynamic>> instructors = [];
    bool loadingInstructors = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Load instructors on first build
          if (loadingInstructors && selectedDisciplineId.isNotEmpty) {
            _loadInstructorsForDiscipline(selectedDisciplineId).then((list) {
              if (ctx.mounted) {
                setDialogState(() {
                  instructors = list;
                  loadingInstructors = false;
                  // Reset instructor if not in list
                  if (selectedInstructorId != null &&
                      !list.any((i) => i['id'] == selectedInstructorId)) {
                    selectedInstructorId = null;
                    selectedInstructorName = null;
                  }
                });
              }
            });
          }

          return AlertDialog(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing != null ? 'Modifica Lezione' : 'Nuova Lezione',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_dayLabelsFull[day]} • $time',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Orario fine
                  _dialogLabel(theme, 'Orario fine', Icons.access_time),
                  const SizedBox(height: 6),
                  _dialogDropdown<String>(
                    theme: theme,
                    value: selectedEndTime,
                    items: _timeSlots
                        .where((t) => t.compareTo(time) > 0)
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null)
                        setDialogState(() => selectedEndTime = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Disciplina
                  _dialogLabel(theme, 'Disciplina', Icons.sports_martial_arts),
                  const SizedBox(height: 6),
                  _dialogDropdown<String>(
                    theme: theme,
                    value: selectedDisciplineId.isNotEmpty
                        ? selectedDisciplineId
                        : null,
                    items: _disciplines
                        .map(
                          (d) => DropdownMenuItem(
                            value: d['id'] as String,
                            child: Text(d['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final disc = _disciplines.firstWhere(
                          (d) => d['id'] == val,
                        );
                        setDialogState(() {
                          selectedDisciplineId = val;
                          selectedDisciplineName = disc['name'] as String;
                          selectedInstructorId = null;
                          selectedInstructorName = null;
                          instructors = [];
                          loadingInstructors = true;
                        });
                        _loadInstructorsForDiscipline(val).then((list) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              instructors = list;
                              loadingInstructors = false;
                            });
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Sala
                  _dialogLabel(theme, 'Sala', Icons.location_on_outlined),
                  const SizedBox(height: 6),
                  _dialogDropdown<String>(
                    theme: theme,
                    value: selectedLocation,
                    items: const [
                      DropdownMenuItem(
                        value: 'Sala 1° piano',
                        child: Text('Sala 1° piano'),
                      ),
                      DropdownMenuItem(
                        value: 'Sala 2° piano',
                        child: Text('Sala 2° piano'),
                      ),
                      DropdownMenuItem(
                        value: 'Palestra',
                        child: Text('Palestra'),
                      ),
                      DropdownMenuItem(
                        value: 'Sala Tatami',
                        child: Text('Sala Tatami'),
                      ),
                      DropdownMenuItem(
                        value: 'Esterno',
                        child: Text('Esterno'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null)
                        setDialogState(() => selectedLocation = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Istruttore
                  _dialogLabel(theme, 'Istruttore', Icons.person_outline),
                  const SizedBox(height: 6),
                  loadingInstructors
                      ? Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        )
                      : _dialogDropdown<String?>(
                          theme: theme,
                          value: selectedInstructorId,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('— Nessun istruttore —'),
                            ),
                            ...instructors.map(
                              (i) => DropdownMenuItem<String?>(
                                value: i['id'] as String,
                                child: Text(i['full_name'] as String),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedInstructorId = val;
                              selectedInstructorName = val == null
                                  ? null
                                  : instructors.firstWhere(
                                          (i) => i['id'] == val,
                                          orElse: () => {'full_name': null},
                                        )['full_name']
                                        as String?;
                            });
                          },
                        ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _entries.remove(existing));
                    Navigator.pop(ctx);
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 16,
                  ),
                  label: Text(
                    'Elimina',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: selectedDisciplineId.isEmpty
                    ? null
                    : () {
                        final entry = _GridEntry(
                          id:
                              existing?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          dayOfWeek: day,
                          startTime: time,
                          endTime: selectedEndTime,
                          disciplineId: selectedDisciplineId,
                          disciplineName: selectedDisciplineName,
                          instructorId: selectedInstructorId,
                          instructorName: selectedInstructorName,
                          location: selectedLocation,
                        );
                        setState(() {
                          if (existing != null) {
                            final idx = _entries.indexOf(existing);
                            if (idx >= 0) _entries[idx] = entry;
                          } else {
                            _entries.add(entry);
                          }
                        });
                        Navigator.pop(ctx);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(existing != null ? 'Aggiorna' : 'Aggiungi'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogLabel(ThemeData theme, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _dialogDropdown<T>({
    required ThemeData theme,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(8.0),
        color: theme.scaffoldBackgroundColor,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: theme.cardColor,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _nextTimeSlot(String time) {
    final idx = _timeSlots.indexOf(time);
    if (idx >= 0 && idx + 2 < _timeSlots.length) return _timeSlots[idx + 2];
    if (idx >= 0 && idx + 1 < _timeSlots.length) return _timeSlots[idx + 1];
    return time;
  }

  // ── Time range dialog ─────────────────────────────────────────────────────
  Future<void> _showTimeRangeDialog() async {
    final theme = Theme.of(context);
    String tempStart = _gridStartTime;
    String tempEnd = _gridEndTime;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: theme.colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Orario colonna palinsesto',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inizio',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempStart,
                        isExpanded: true,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        items: _timeSlots
                            .where((t) => t.compareTo(tempEnd) < 0)
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => tempStart = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Fine',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempEnd,
                        isExpanded: true,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        items: _timeSlots
                            .where((t) => t.compareTo(tempStart) > 0)
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => tempEnd = v);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Annulla',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _gridStartTime = tempStart;
                      _gridEndTime = tempEnd;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Applica'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Schedule management ───────────────────────────────────────────────────
  Future<void> _deleteSchedule(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Elimina palinsesto',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Sei sicuro di voler eliminare "$title"?\nVerranno eliminate anche tutte le lezioni generate.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase
          .from('schedule_instances')
          .delete()
          .eq('seasonal_schedule_id', id);
      await _supabase
          .from('weekly_schedule_templates')
          .delete()
          .eq('seasonal_schedule_id', id);
      await _supabase.from('seasonal_schedules').delete().eq('id', id);
      _showSuccess('Palinsesto eliminato con successo');
      _loadExistingSchedules();
    } catch (e) {
      _showError('Errore: $e');
    }
  }

  Future<void> _editScheduleFull(Map<String, dynamic> schedule) async {
    final scheduleId = schedule['id'] as String;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Caricamento in corso...'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final templates = await _supabase
          .from('weekly_schedule_templates')
          .select('*')
          .eq('seasonal_schedule_id', scheduleId)
          .order('day_of_week');

      final startDate =
          DateTime.tryParse(schedule['start_date'] as String? ?? '') ??
          DateTime.now();
      final endDate =
          DateTime.tryParse(schedule['end_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 90));

      final List<_GridEntry> loadedEntries = [];
      for (final t in templates) {
        final disciplineId = t['discipline'] as String?;
        String? disciplineName;
        if (disciplineId != null) {
          final disc = _disciplines.firstWhere(
            (d) => d['id'] == disciplineId,
            orElse: () => <String, dynamic>{
              'id': disciplineId,
              'name': disciplineId,
            },
          );
          disciplineName = disc['name'] as String?;
        }
        String startTime = (t['start_time'] as String? ?? '19:00');
        String endTime = (t['end_time'] as String? ?? '20:30');
        if (startTime.length > 5) startTime = startTime.substring(0, 5);
        if (endTime.length > 5) endTime = endTime.substring(0, 5);

        loadedEntries.add(
          _GridEntry(
            id:
                t['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            dayOfWeek: t['day_of_week'] as String? ?? 'monday',
            startTime: startTime,
            endTime: endTime,
            location: t['location'] as String? ?? 'Sala 1° piano',
            disciplineId: disciplineId,
            disciplineName: disciplineName,
            instructorId: t['instructor_id'] as String?,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _startDate = startDate;
          _endDate = endDate;
          _entries.clear();
          _entries.addAll(loadedEntries);
          _editingScheduleId = scheduleId;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSuccess(
          'Palinsesto caricato. Modifica la griglia e premi "Genera".',
        );
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showError('Errore nel caricamento');
      }
    }
  }

  Future<void> _pauseSchedule(String id, String currentStatus) async {
    final newStatus = currentStatus == 'suspended' ? 'active' : 'suspended';
    try {
      await _supabase
          .from('seasonal_schedules')
          .update({'status': newStatus})
          .eq('id', id);
      _showSuccess(
        newStatus == 'suspended'
            ? 'Palinsesto sospeso'
            : 'Palinsesto riattivato',
      );
      _loadExistingSchedules();
    } catch (e) {
      _showError('Errore: $e');
    }
  }

  Future<void> _activateSchedule(String id) async {
    try {
      await _supabase
          .from('seasonal_schedules')
          .update({'status': 'active'})
          .eq('id', id);
      _showSuccess('Palinsesto attivato per tutti gli utenti');
      _loadExistingSchedules();
    } catch (e) {
      _showError('Errore: $e');
    }
  }

  // ── Generate ──────────────────────────────────────────────────────────────
  Future<void> _generateSchedule() async {
    if (_entries.isEmpty) {
      _showError('Aggiungi almeno una lezione nella griglia');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showError('La data fine deve essere successiva alla data inizio');
      return;
    }
    setState(() => _isGenerating = true);
    try {
      String seasonId;
      if (_editingScheduleId != null) {
        seasonId = _editingScheduleId!;
        await _supabase
            .from('schedule_instances')
            .delete()
            .eq('seasonal_schedule_id', seasonId);
        await _supabase
            .from('weekly_schedule_templates')
            .delete()
            .eq('seasonal_schedule_id', seasonId);
        await _supabase
            .from('seasonal_schedules')
            .update({
              'title': _buildTitle(),
              'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
              'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
            })
            .eq('id', seasonId);
      } else {
        final seasonResponse = await _supabase
            .from('seasonal_schedules')
            .insert({
              'title': _buildTitle(),
              'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
              'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
              'status': 'draft',
              'created_by': AuthService.instance.currentUser!.id,
            })
            .select()
            .single();
        seasonId = seasonResponse['id'] as String;
      }

      // Save weekly templates
      final templates = _entries
          .map(
            (e) => {
              'seasonal_schedule_id': seasonId,
              'day_of_week': e.dayOfWeek,
              'start_time': '${e.startTime}:00',
              'end_time': '${e.endTime}:00',
              'discipline': e.disciplineId,
              'instructor_id': e.instructorId,
              'location': e.location,
              'max_capacity': 20,
            },
          )
          .toList();
      if (templates.isNotEmpty) {
        await _supabase.from('weekly_schedule_templates').insert(templates);
      }

      // Build holiday set
      final holidays = _buildHolidaySet(_startDate, _endDate);

      // Generate instances
      final List<Map<String, dynamic>> instances = [];
      DateTime current = _startDate;
      while (!current.isAfter(_endDate)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(current);
        if (!holidays.contains(dateStr)) {
          for (final entry in _entries) {
            final targetDay = _dayOfWeekIndex(entry.dayOfWeek);
            if (current.weekday == targetDay) {
              instances.add({
                'seasonal_schedule_id': seasonId,
                'class_date': dateStr,
                'start_time': '${entry.startTime}:00',
                'end_time': '${entry.endTime}:00',
                'discipline': entry.disciplineId,
                'instructor_id': entry.instructorId,
                'location': entry.location,
                'max_capacity': 20,
                'is_cancelled': false,
              });
            }
          }
        }
        current = current.add(const Duration(days: 1));
      }

      for (int i = 0; i < instances.length; i += 100) {
        final batch = instances.sublist(
          i,
          i + 100 > instances.length ? instances.length : i + 100,
        );
        await _supabase.from('schedule_instances').insert(batch);
      }

      if (mounted) {
        setState(() {
          _isGenerating = false;
          _editingScheduleId = null;
        });
        _showSuccess(
          '✅ ${instances.length} lezioni generate (${holidays.length} festivi esclusi)',
        );
        _loadExistingSchedules();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _showError('Errore: $error');
      }
    }
  }

  String _buildTitle() {
    final s = _startDate.year;
    final e = _endDate.year;
    return e != s ? 'Palinsesto $s/$e' : 'Palinsesto $s';
  }

  // ── Date helpers ──────────────────────────────────────────────────────────
  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final first = isStart ? DateTime(2020) : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2030),
      locale: const Locale('it', 'IT'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.secondary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate))
            _endDate = _startDate.add(const Duration(days: 90));
        } else {
          _endDate = picked;
        }
      });
    }
  }

  DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  Set<String> _buildHolidaySet(DateTime start, DateTime end) {
    final holidays = <String>{};
    for (int year = start.year; year <= end.year; year++) {
      for (final h in _fixedHolidays) {
        final d = DateTime(year, h['month']!, h['day']!);
        if (!d.isBefore(start) && !d.isAfter(end))
          holidays.add(DateFormat('yyyy-MM-dd').format(d));
      }
      final easter = _easterSunday(year);
      final easterMonday = easter.add(const Duration(days: 1));
      for (final d in [easter, easterMonday]) {
        if (!d.isBefore(start) && !d.isAfter(end))
          holidays.add(DateFormat('yyyy-MM-dd').format(d));
      }
    }
    return holidays;
  }

  int _dayOfWeekIndex(String day) {
    switch (day) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  int get _durationDays => _endDate.difference(_startDate).inDays + 1;
  int get _durationWeeks => (_durationDays / 7).ceil();

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _editingScheduleId != null
              ? 'Modifica Palinsesto'
              : 'Crea Palinsesto Stagionale',
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_editingScheduleId != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _editingScheduleId = null;
                _entries.clear();
                _startDate = DateTime.now();
                _endDate = DateTime.now().add(const Duration(days: 90));
              }),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text(
                'Nuovo',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.secondary,
          labelColor: theme.colorScheme.secondary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(icon: Icon(Icons.grid_on, size: 18), text: 'Griglia'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Palinsesti'),
          ],
        ),
      ),
      body: _isLoadingDisciplines
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.secondary,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildGridTab(theme), _buildSchedulesTab(theme)],
            ),
    );
  }

  // ── TAB 1: Grid ───────────────────────────────────────────────────────────
  Widget _buildGridTab(ThemeData theme) {
    return Column(
      children: [
        // Period + generate bar
        _buildTopBar(theme),
        // Grid
        Expanded(child: _buildWeeklyGrid(theme)),
      ],
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
      child: Column(
        children: [
          // Edit mode banner
          if (_editingScheduleId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 14,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Modalità modifica — modifica la griglia e premi "Genera"',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Start date
              Expanded(child: _buildDateTile(theme, true)),
              const SizedBox(width: 8),
              // End date
              Expanded(child: _buildDateTile(theme, false)),
              const SizedBox(width: 8),
              // Duration info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_durationWeeks sett.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$_durationDays giorni',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateSchedule,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt, size: 18),
              label: Text(
                _isGenerating
                    ? 'Generazione in corso...'
                    : _editingScheduleId != null
                    ? 'Rigenera Palinsesto'
                    : 'Genera Palinsesto',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile(ThemeData theme, bool isStart) {
    final date = isStart ? _startDate : _endDate;
    final label = isStart ? 'Inizio' : 'Fine';
    final icon = isStart ? Icons.event_available : Icons.event_busy;
    return InkWell(
      onTap: () => _pickDate(isStart),
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.secondary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yy').format(date),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Weekly Grid ───────────────────────────────────────────────────────────
  Widget _buildWeeklyGrid(ThemeData theme) {
    const double timeColW = 52.0;
    const double dayColW = 110.0;
    const double rowH = 44.0;

    return Scrollbar(
      controller: _vScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vScrollController,
        child: Scrollbar(
          controller: _hScrollController,
          thumbVisibility: true,
          notificationPredicate: (n) => n.depth == 1,
          child: SingleChildScrollView(
            controller: _hScrollController,
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                // Header row: days
                Row(
                  children: [
                    // Corner cell
                    Container(
                      width: timeColW,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        border: Border(
                          right: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          bottom: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ),
                      child: GestureDetector(
                        onTap: _showTimeRangeDialog,
                        child: Center(
                          child: Tooltip(
                            message: 'Imposta orario colonna',
                            child: Icon(
                              Icons.access_time,
                              size: 16,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Day headers
                    ..._orderedDays.map((day) {
                      final hasEntries = _entries.any(
                        (e) => e.dayOfWeek == day,
                      );
                      return Container(
                        width: dayColW,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasEntries
                              ? theme.colorScheme.secondary.withValues(
                                  alpha: 0.12,
                                )
                              : theme.cardColor,
                          border: Border(
                            left: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _dayLabels[day] ?? day,
                            style: TextStyle(
                              color: hasEntries
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                // Grid body: time rows + spanning entries overlay
                SizedBox(
                  width: timeColW + dayColW * _orderedDays.length,
                  height: rowH * _visibleTimeSlots.length,
                  child: Stack(
                    children: [
                      // Background grid rows
                      Column(
                        children: _visibleTimeSlots.map((time) {
                          return Row(
                            children: [
                              // Time label
                              Container(
                                width: timeColW,
                                height: rowH,
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  border: Border(
                                    right: BorderSide(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.3),
                                    ),
                                    bottom: BorderSide(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.15),
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        time,
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        () {
                                          final idx = _timeSlots.indexOf(time);
                                          if (idx >= 0 &&
                                              idx + 1 < _timeSlots.length) {
                                            return _timeSlots[idx + 1];
                                          }
                                          // If last slot, add 30 min manually
                                          final parts = time.split(':');
                                          final h = int.parse(parts[0]);
                                          final m = int.parse(parts[1]);
                                          final totalMin = h * 60 + m + 30;
                                          return '${(totalMin ~/ 60).toString().padLeft(2, '0')}:${(totalMin % 60).toString().padLeft(2, '0')}';
                                        }(),
                                        style: TextStyle(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Empty day cells (tap to add)
                              ..._orderedDays.map((day) {
                                // Only show tap target if no entry starts here
                                final hasEntryStartingHere = _entries.any(
                                  (e) =>
                                      e.dayOfWeek == day && e.startTime == time,
                                );
                                // Also check if this cell is covered by a spanning entry
                                final isCovered = _isCellCovered(day, time);
                                return GestureDetector(
                                  onTap: (hasEntryStartingHere || isCovered)
                                      ? null
                                      : () => _openCellDialog(day, time),
                                  child: Container(
                                    width: dayColW,
                                    height: rowH,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      border: Border(
                                        left: BorderSide(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.2),
                                        ),
                                        bottom: BorderSide(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.15),
                                        ),
                                      ),
                                    ),
                                    child: (hasEntryStartingHere || isCovered)
                                        ? null
                                        : Center(
                                            child: Icon(
                                              Icons.add,
                                              size: 14,
                                              color: theme.colorScheme.outline
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
                      // Spanning entry overlays
                      ..._buildSpanningEntries(theme, timeColW, dayColW, rowH),
                    ],
                  ),
                ),
                // Bottom padding
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Converts a "HH:mm" string to total minutes since midnight.
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    return int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
  }

  /// Returns true if the given cell is covered by a spanning entry
  /// (i.e. an entry that starts before this time and ends after it)
  bool _isCellCovered(String day, String time) {
    final timeMin = _timeToMinutes(time);
    for (final entry in _entries) {
      if (entry.dayOfWeek != day) continue;
      final startMin = _timeToMinutes(entry.startTime);
      final endMin = _timeToMinutes(entry.endTime);
      // Cell is covered if timeMin is strictly between start and end
      if (timeMin > startMin && timeMin < endMin) return true;
    }
    return false;
  }

  /// Builds positioned overlay widgets for each entry, spanning the correct rows
  List<Widget> _buildSpanningEntries(
    ThemeData theme,
    double timeColW,
    double dayColW,
    double rowH,
  ) {
    final List<Widget> overlays = [];

    for (final entry in _entries) {
      final startIdx = _visibleTimeSlots.indexOf(entry.startTime);
      if (startIdx < 0) continue;

      // Height: calculated purely from minute difference, independent of index.
      // (endMinutes - startMinutes) / 30 gives the number of 30-min slots.
      final int startMin = _timeToMinutes(entry.startTime);
      final int endMin = _timeToMinutes(entry.endTime);
      final int durationMinutes = endMin - startMin;
      final double entryHeight = durationMinutes > 0
          ? (durationMinutes / 30.0) * rowH
          : rowH;

      // spanCount is only used to decide whether to show instructor name
      final int spanCount = durationMinutes > 30 ? 2 : 1;

      final dayIdx = _orderedDays.indexOf(entry.dayOfWeek);
      if (dayIdx < 0) continue;

      final double top = startIdx * rowH;
      final double left = timeColW + dayIdx * dayColW;

      const double handleSize = 12.0;

      // Resolve discipline color from the loaded disciplines list
      Color disciplineColor = theme.colorScheme.secondary;
      if (entry.disciplineId != null) {
        final discMatch = _disciplines.firstWhere(
          (d) => d['id'] == entry.disciplineId,
          orElse: () => <String, dynamic>{},
        );
        if (discMatch.isNotEmpty && discMatch['color'] != null) {
          disciplineColor = discMatch['color'] as Color;
        }
      }

      overlays.add(
        Positioned(
          top: top,
          left: left,
          width: dayColW,
          height: entryHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main lesson block (tap to edit)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _openCellDialog(
                    entry.dayOfWeek,
                    entry.startTime,
                    existing: entry,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: disciplineColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: disciplineColor.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.disciplineName ?? '—',
                          style: TextStyle(
                            color: disciplineColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (entry.instructorName != null && spanCount > 1)
                          Text(
                            entry.instructorName!,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '${entry.startTime}–${entry.endTime}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── TOP drag handle ──────────────────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: handleSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) {
                    _resizeDrag = _ResizeDragState(
                      entryId: entry.id,
                      isBottom: false,
                    );
                  },
                  onVerticalDragUpdate: (details) {
                    if (_resizeDrag == null || _resizeDrag!.entryId != entry.id)
                      return;
                    _resizeDrag!.accumulatedDelta += details.delta.dy;
                    final int slotShift = (_resizeDrag!.accumulatedDelta / rowH)
                        .round();
                    if (slotShift == 0) return;

                    final int currentStartIdx = _timeSlots.indexOf(
                      entry.startTime,
                    );
                    final int currentEndIdx = _timeSlots.indexOf(entry.endTime);
                    final int newStartIdx = (currentStartIdx + slotShift).clamp(
                      0,
                      currentEndIdx - 1,
                    );

                    if (newStartIdx != currentStartIdx) {
                      final newStartTime = _timeSlots[newStartIdx];
                      setState(() {
                        final idx = _entries.indexWhere(
                          (e) => e.id == entry.id,
                        );
                        if (idx >= 0) {
                          _entries[idx] = _entries[idx].copyWith(
                            startTime: newStartTime,
                          );
                        }
                      });
                      _resizeDrag!.accumulatedDelta -= slotShift * rowH;
                    }
                  },
                  onVerticalDragEnd: (_) => _resizeDrag = null,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 4,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                ),
              ),

              // ── BOTTOM drag handle ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: handleSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) {
                    _resizeDrag = _ResizeDragState(
                      entryId: entry.id,
                      isBottom: true,
                    );
                  },
                  onVerticalDragUpdate: (details) {
                    if (_resizeDrag == null || _resizeDrag!.entryId != entry.id)
                      return;
                    _resizeDrag!.accumulatedDelta += details.delta.dy;
                    final int slotShift = (_resizeDrag!.accumulatedDelta / rowH)
                        .round();
                    if (slotShift == 0) return;

                    final int currentStartIdx = _timeSlots.indexOf(
                      entry.startTime,
                    );
                    final int currentEndIdx = _timeSlots.indexOf(entry.endTime);
                    final int newEndIdx = (currentEndIdx + slotShift).clamp(
                      currentStartIdx + 1,
                      _timeSlots.length - 1,
                    );

                    if (newEndIdx != currentEndIdx) {
                      final newEndTime = _timeSlots[newEndIdx];
                      setState(() {
                        final idx = _entries.indexWhere(
                          (e) => e.id == entry.id,
                        );
                        if (idx >= 0) {
                          _entries[idx] = _entries[idx].copyWith(
                            endTime: newEndTime,
                          );
                        }
                      });
                      _resizeDrag!.accumulatedDelta -= slotShift * rowH;
                    }
                  },
                  onVerticalDragEnd: (_) => _resizeDrag = null,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return overlays;
  }

  Widget _buildCell({
    required ThemeData theme,
    required String day,
    required String time,
    required List<_GridEntry> entries,
    required double width,
    required double height,
  }) {
    // This method is kept for compatibility but is no longer used by the grid.
    // The grid now uses _buildSpanningEntries for entry rendering.
    final isEmpty = entries.isEmpty;
    return GestureDetector(
      onTap: () => isEmpty
          ? _openCellDialog(day, time)
          : _openCellDialog(day, time, existing: entries.first),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isEmpty
              ? Colors.transparent
              : theme.colorScheme.secondary.withValues(alpha: 0.18),
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: isEmpty
            ? Center(
                child: Icon(
                  Icons.add,
                  size: 14,
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entries.first.disciplineName ?? '—',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entries.first.instructorName != null)
                      Text(
                        entries.first.instructorName!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${entries.first.startTime}–${() {
                        final eIdx = _timeSlots.indexOf(entries.first.endTime);
                        return eIdx > 0 ? _timeSlots[eIdx - 1] : entries.first.endTime;
                      }()}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── TAB 2: Existing schedules ─────────────────────────────────────────────
  Widget _buildSchedulesTab(ThemeData theme) {
    if (_isLoadingSchedules) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.secondary),
      );
    }
    if (_existingSchedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Nessun palinsesto creato',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vai alla scheda Griglia per crearne uno',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadExistingSchedules,
      color: theme.colorScheme.secondary,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: _existingSchedules.length,
        itemBuilder: (ctx, i) =>
            _buildScheduleCard(theme, _existingSchedules[i]),
      ),
    );
  }

  Widget _buildScheduleCard(ThemeData theme, Map<String, dynamic> schedule) {
    final status = schedule['status'] as String? ?? 'draft';
    final title = schedule['title'] as String? ?? 'Palinsesto';
    final startDate = DateTime.tryParse(
      schedule['start_date'] as String? ?? '',
    );
    final endDate = DateTime.tryParse(schedule['end_date'] as String? ?? '');

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'active':
        statusColor = Colors.green;
        statusIcon = Icons.play_circle_outline;
        break;
      case 'suspended':
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle_outline;
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusIcon = Icons.edit_note;
    }

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status == 'active'
                            ? 'Attivo'
                            : status == 'suspended'
                            ? 'Sospeso'
                            : status == 'completed'
                            ? 'Completato'
                            : 'Bozza',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (startDate != null && endDate != null) ...[
              const SizedBox(height: 6),
              Text(
                '${DateFormat('dd/MM/yyyy').format(startDate)} → ${DateFormat('dd/MM/yyyy').format(endDate)}',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                // Edit
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _editScheduleFull(schedule);
                      _tabController.animateTo(0);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text(
                      'Modifica',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.secondary,
                      side: BorderSide(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Activate button (only for draft/suspended)
                if (status == 'draft' || status == 'suspended') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _activateSchedule(schedule['id'] as String),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text(
                        'Attiva',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(
                          color: Colors.green.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Suspend button (only for active)
                if (status == 'active') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _pauseSchedule(schedule['id'] as String, status),
                      icon: const Icon(Icons.pause_outlined, size: 14),
                      label: const Text(
                        'Sospendi',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Delete
                IconButton(
                  onPressed: () =>
                      _deleteSchedule(schedule['id'] as String, title),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
