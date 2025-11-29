import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeasonConfigurationWidget extends StatefulWidget {
  final Map<String, dynamic>? currentSeason;
  final Function(Map<String, dynamic>) onSeasonCreated;
  final VoidCallback onSeasonUpdated;

  const SeasonConfigurationWidget({
    Key? key,
    this.currentSeason,
    required this.onSeasonCreated,
    required this.onSeasonUpdated,
  }) : super(key: key);

  @override
  State<SeasonConfigurationWidget> createState() =>
      _SeasonConfigurationWidgetState();
}

class _SeasonConfigurationWidgetState extends State<SeasonConfigurationWidget> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 90));
  bool _showStartCalendar = false;
  bool _showEndCalendar = false;

  // Schedule Templates Management
  List<Map<String, dynamic>> _scheduleTemplates = [];
  List<Map<String, dynamic>> _availableInstructors = [];
  bool _isLoadingInstructors = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _loadAvailableInstructors();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    if (widget.currentSeason != null) {
      _titleController.text = widget.currentSeason!['title'] ?? '';
      _descriptionController.text = widget.currentSeason!['description'] ?? '';
      _startDate = DateTime.parse(widget.currentSeason!['start_date']);
      _endDate = DateTime.parse(widget.currentSeason!['end_date']);
      _loadExistingTemplates();
    }
  }

  Future<void> _loadAvailableInstructors() async {
    setState(() => _isLoadingInstructors = true);
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('id, full_name')
          .inFilter('role', [
            'instructor',
            'instructor_admin',
            'admin',
            'principal_admin',
          ])
          .eq('status', 'approved')
          .order('full_name');

      setState(() {
        _availableInstructors = List<Map<String, dynamic>>.from(response);
        _isLoadingInstructors = false;
      });
    } catch (error) {
      setState(() => _isLoadingInstructors = false);
      print('Error loading instructors: $error');
    }
  }

  Future<void> _loadExistingTemplates() async {
    if (widget.currentSeason == null) return;

    try {
      final response = await _supabase
          .from('weekly_schedule_templates')
          .select('*')
          .eq('seasonal_schedule_id', widget.currentSeason!['id'])
          .order('day_of_week, start_time');

      if (mounted) {
        setState(() {
          _scheduleTemplates = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (error) {
      print('Error loading existing templates: $error');
    }
  }

  void _createOrUpdateSeason() async {
    if (_titleController.text.isEmpty) {
      _showErrorMessage('Inserisci il titolo della stagione');
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      _showErrorMessage('La data fine deve essere successiva alla data inizio');
      return;
    }

    final seasonData = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
      'status': 'draft',
    };

    // If it's an existing season with templates, save templates after season update
    if (widget.currentSeason != null && _scheduleTemplates.isNotEmpty) {
      await _saveScheduleTemplates();
    }

    widget.onSeasonCreated(seasonData);
  }

  Future<void> _saveScheduleTemplates() async {
    if (widget.currentSeason == null) return;

    try {
      // Delete existing templates first
      await _supabase
          .from('weekly_schedule_templates')
          .delete()
          .eq('seasonal_schedule_id', widget.currentSeason!['id']);

      // Insert new templates
      if (_scheduleTemplates.isNotEmpty) {
        final templatesToInsert =
            _scheduleTemplates
                .map(
                  (template) => {
                    'seasonal_schedule_id': widget.currentSeason!['id'],
                    'day_of_week': template['day_of_week'],
                    'start_time': template['start_time'],
                    'end_time': template['end_time'],
                    'discipline': template['discipline'],
                    'instructor_id': template['instructor_id'],
                    'location': template['location'] ?? 'Sala 1° piano',
                    'max_capacity': template['max_capacity'] ?? 20,
                    'notes': template['notes'] ?? '',
                  },
                )
                .toList();

        await _supabase
            .from('weekly_schedule_templates')
            .insert(templatesToInsert);
      }

      // Touch the parent season to refresh its updated_at timestamp so other
      // sections (e.g., discipline list) immediately reference this latest
      // season even while it's still in draft
      try {
        await _supabase
            .from('seasonal_schedules')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', widget.currentSeason!['id']);
      } catch (_) {}

      // Reload templates to get the saved data with proper IDs
      await _loadExistingTemplates();

      // Notify parent to refresh its data
      widget.onSeasonUpdated();

      _showSuccessMessage('Schema orari salvato con successo!');
    } catch (error) {
      _showErrorMessage('Errore nel salvataggio schema orari: $error');
    }
  }

  void _addScheduleTemplate() {
    setState(() {
      _scheduleTemplates.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'day_of_week': 'monday',
        'start_time': '19:00:00',
        'end_time': '20:30:00',
        'discipline': 'bjj',
        'instructor_id':
            _availableInstructors.isNotEmpty
                ? _availableInstructors.first['id']
                : null,
        'location': 'Sala 1° piano',
        'max_capacity': 20,
        'notes': '',
      });
    });
  }

  void _removeScheduleTemplate(int index) {
    setState(() {
      _scheduleTemplates.removeAt(index);
    });
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  @override
  void didUpdateWidget(SeasonConfigurationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload data when the current season changes
    if (oldWidget.currentSeason != widget.currentSeason) {
      _loadExistingData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.currentSeason == null) ...[
            _buildCreateSeasonCard(),
            SizedBox(height: 3.h),
          ] else ...[
            _buildExistingSeasonCard(),
            SizedBox(height: 3.h),
          ],
          _buildSeasonDetailsForm(),
          if (widget.currentSeason != null) ...[
            SizedBox(height: 3.h),
            _buildScheduleTemplatesSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateSeasonCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: Theme.of(context).colorScheme.secondary,
            ),
            SizedBox(height: 2.h),
            Text(
              'Crea Nuovo Palinsesto Stagionale',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Configura un nuovo periodo stagionale con date di inizio e fine, gestione festività e schema orari automatico',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingSeasonCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_view_month,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 24,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stagione Attuale',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.currentSeason!['title'] ?? 'Senza titolo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 2.w),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.currentSeason!['start_date']))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.currentSeason!['end_date']))}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonDetailsForm() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurazione Stagione',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),

            // Season Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Titolo Stagione *',
                hintText: 'es. Palinsesto 2025/2026',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            SizedBox(height: 2.h),

            // Season Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descrizione (opzionale)',
                hintText: 'es. Orari stagione 2025/2026',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            SizedBox(height: 3.h),

            // Date Selection Section
            Text(
              'Periodo Stagionale',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),

            Row(
              children: [
                Expanded(
                  child: _buildDateSelector(
                    'Data Inizio',
                    _startDate,
                    Icons.event_available,
                    () => setState(
                      () => _showStartCalendar = !_showStartCalendar,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: _buildDateSelector(
                    'Data Fine',
                    _endDate,
                    Icons.event_busy,
                    () => setState(() => _showEndCalendar = !_showEndCalendar),
                  ),
                ),
              ],
            ),

            if (_showStartCalendar) ...[
              SizedBox(height: 2.h),
              _buildCalendarWidget(true),
            ],

            if (_showEndCalendar) ...[
              SizedBox(height: 2.h),
              _buildCalendarWidget(false),
            ],

            SizedBox(height: 4.h),

            // Duration Info
            _buildDurationInfo(),

            SizedBox(height: 4.h),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: _createOrUpdateSeason,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.currentSeason == null
                      ? 'Crea Stagione'
                      : 'Aggiorna Stagione',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTemplatesSection() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schema Orari Settimanale',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Configura gli orari per tutti i giorni della settimana. Vedrai gli orari aggiunti per ciascun giorno.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addScheduleTemplate,
                  icon: Icon(Icons.add, size: 18),
                  label: Text('Aggiungi Orario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),

            // Weekly Overview Section
            if (_scheduleTemplates.isNotEmpty) _buildWeeklyOverview(),

            if (_scheduleTemplates.isEmpty)
              _buildEmptyScheduleState()
            else
              ..._scheduleTemplates.asMap().entries.map((entry) {
                return _buildScheduleTemplateCard(entry.key, entry.value);
              }).toList(),
            if (_scheduleTemplates.isNotEmpty) ...[
              SizedBox(height: 3.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'Una volta completata la configurazione, vai alla sezione "Operazioni" per generare automaticamente tutte le lezioni dell\'anno considerando le festività.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              SizedBox(
                width: double.infinity,
                height: 6.h,
                child: ElevatedButton.icon(
                  onPressed: _saveScheduleTemplates,
                  icon: Icon(Icons.save, size: 18),
                  label: Text('Salva Schema Orari'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    final daysOfWeek = {
      'monday': 'Lunedì',
      'tuesday': 'Martedì',
      'wednesday': 'Mercoledì',
      'thursday': 'Giovedì',
      'friday': 'Venerdì',
      'saturday': 'Sabato',
      'sunday': 'Domenica',
    };

    // Group schedules by day
    Map<String, List<Map<String, dynamic>>> schedulesByDay = {};
    for (String day in daysOfWeek.keys) {
      schedulesByDay[day] =
          _scheduleTemplates
              .where((template) => template['day_of_week'] == day)
              .toList()
            ..sort(
              (a, b) =>
                  (a['start_time'] ?? '').compareTo(b['start_time'] ?? ''),
            );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_view_week,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'Panoramica Settimanale',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ...daysOfWeek.entries.map((dayEntry) {
            final dayKey = dayEntry.key;
            final dayName = dayEntry.value;
            final daySchedules = schedulesByDay[dayKey] ?? [];

            return Container(
              margin: EdgeInsets.only(bottom: 2.h),
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color:
                              daySchedules.isEmpty
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.3)
                                  : Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        dayName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.w,
                          vertical: 0.5.h,
                        ),
                        decoration: BoxDecoration(
                          color:
                              daySchedules.isEmpty
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.1)
                                  : Theme.of(context).colorScheme.secondary
                                      .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${daySchedules.length} orari',
                          style: TextStyle(
                            color:
                                daySchedules.isEmpty
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (daySchedules.isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    ...daySchedules.map((schedule) {
                      final startTime =
                          schedule['start_time']?.substring(0, 5) ?? '';
                      final endTime =
                          schedule['end_time']?.substring(0, 5) ?? '';
                      final discipline = _getDisciplineName(
                        schedule['discipline'],
                      );
                      final location = schedule['location'] ?? '';

                      return Container(
                        margin: EdgeInsets.only(bottom: 0.5.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$startTime-$endTime',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    discipline,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (location.isNotEmpty)
                                    Text(
                                      location,
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ] else
                    Padding(
                      padding: EdgeInsets.only(top: 1.h),
                      child: Text(
                        'Nessun orario configurato',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getDisciplineName(String? discipline) {
    switch (discipline) {
      case 'bjj':
        return 'Brazilian Jiu-Jitsu (BJJ)';
      case 'mma':
        return 'Mixed Martial Arts (MMA)';
      case 'sambo':
        return 'Sambo';
      case 'grappling':
        return 'Grappling';
      case 'fitness':
        return 'Prep. Atletica';
      default:
        return 'Disciplina sconosciuta';
    }
  }

  Widget _buildEmptyScheduleState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 48,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: 2.h),
          Text(
            'Nessun Orario Configurato',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Aggiungi il primo orario settimanale per iniziare la configurazione del palinsesto',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTemplateCard(int index, Map<String, dynamic> template) {
    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Orario ${index + 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () => _removeScheduleTemplate(index),
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                tooltip: 'Rimuovi orario',
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Day of Week Selection
          Text(
            'Giorno della Settimana',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 1.h),
          DropdownButtonFormField<String>(
            value: template['day_of_week'],
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 3.w,
                vertical: 1.h,
              ),
            ),
            items: [
              DropdownMenuItem(value: 'monday', child: Text('Lunedì')),
              DropdownMenuItem(value: 'tuesday', child: Text('Martedì')),
              DropdownMenuItem(value: 'wednesday', child: Text('Mercoledì')),
              DropdownMenuItem(value: 'thursday', child: Text('Giovedì')),
              DropdownMenuItem(value: 'friday', child: Text('Venerdì')),
              DropdownMenuItem(value: 'saturday', child: Text('Sabato')),
              DropdownMenuItem(value: 'sunday', child: Text('Domenica')),
            ],
            onChanged: (value) {
              setState(() {
                _scheduleTemplates[index]['day_of_week'] = value!;
              });
            },
          ),
          SizedBox(height: 2.h),

          // Time Selection
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orario Inizio',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextFormField(
                      initialValue:
                          template['start_time']?.substring(0, 5) ?? '19:00',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'HH:MM',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.h,
                        ),
                      ),
                      onChanged: (value) {
                        _scheduleTemplates[index]['start_time'] = '$value:00';
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orario Fine',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextFormField(
                      initialValue:
                          template['end_time']?.substring(0, 5) ?? '20:30',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'HH:MM',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.h,
                        ),
                      ),
                      onChanged: (value) {
                        _scheduleTemplates[index]['end_time'] = '$value:00';
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Discipline Selection
          Text(
            'Disciplina',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 1.h),
          DropdownButtonFormField<String>(
            value: template['discipline'],
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 3.w,
                vertical: 1.h,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'bjj',
                child: Text('Brazilian Jiu-Jitsu (BJJ)'),
              ),
              DropdownMenuItem(
                value: 'mma',
                child: Text('Mixed Martial Arts (MMA)'),
              ),
              DropdownMenuItem(value: 'sambo', child: Text('Sambo')),
              DropdownMenuItem(value: 'grappling', child: Text('Grappling')),
              DropdownMenuItem(value: 'fitness', child: Text('Prep. Atletica')),
            ],
            onChanged: (value) {
              setState(() {
                _scheduleTemplates[index]['discipline'] = value!;
              });
            },
          ),
          SizedBox(height: 2.h),

          // Instructor Selection
          Text(
            'Istruttore Responsabile',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 1.h),
          if (_isLoadingInstructors)
            Container(
              height: 6.h,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            DropdownButtonFormField<String>(
              value: template['instructor_id'],
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 3.w,
                  vertical: 1.h,
                ),
              ),
              items:
                  _availableInstructors.map((instructor) {
                    return DropdownMenuItem<String>(
                      value: instructor['id'],
                      child: Text(instructor['full_name'] ?? 'Senza nome'),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  _scheduleTemplates[index]['instructor_id'] = value!;
                });
              },
            ),
          SizedBox(height: 2.h),

          // Location and Capacity
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Luogo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    DropdownButtonFormField<String>(
                      value:
                          // Normalize the stored human-readable label to the dropdown key
                          (template['location'] == null ||
                                  template['location'] == 'Sala Principale' ||
                                  template['location'] == 'Sala 1° piano')
                              ? 'sala_1_piano'
                              : template['location'] == 'Sala 2° piano'
                              ? 'sala_2_piano'
                              : 'sala_1_piano',
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.h,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'sala_1_piano',
                          child: Text('Sala 1° piano'),
                        ),
                        DropdownMenuItem(
                          value: 'sala_2_piano',
                          child: Text('Sala 2° piano'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _scheduleTemplates[index]['location'] =
                              value == 'sala_1_piano'
                                  ? 'Sala 1° piano'
                                  : 'Sala 2° piano';
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capienza Max',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    TextFormField(
                      initialValue: (template['max_capacity'] ?? 20).toString(),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: '20',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 1.h,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        _scheduleTemplates[index]['max_capacity'] =
                            int.tryParse(value) ?? 20;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(
    String label,
    DateTime date,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 2.w),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarWidget(bool isStartDate) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TableCalendar<String>(
        firstDay: DateTime.now().subtract(Duration(days: 30)),
        lastDay: DateTime.now().add(Duration(days: 365)),
        focusedDay: isStartDate ? _startDate : _endDate,
        selectedDayPredicate: (day) {
          return isSameDay(isStartDate ? _startDate : _endDate, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            if (isStartDate) {
              _startDate = selectedDay;
              _showStartCalendar = false;
              if (_endDate.isBefore(_startDate)) {
                _endDate = _startDate.add(Duration(days: 90));
              }
            } else {
              _endDate = selectedDay;
              _showEndCalendar = false;
              if (_endDate.isBefore(_startDate)) {
                _startDate = _endDate.subtract(Duration(days: 90));
              }
            }
          });
        },
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationInfo() {
    final duration = _endDate.difference(_startDate);
    final weeks = (duration.inDays / 7).ceil();

    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durata Stagione',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${duration.inDays} giorni • $weeks settimane',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
