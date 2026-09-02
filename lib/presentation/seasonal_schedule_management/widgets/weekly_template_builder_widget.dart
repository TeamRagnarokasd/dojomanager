import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklyTemplateBuilderWidget extends StatefulWidget {
  final Map<String, dynamic>? currentSeason;
  final List<Map<String, dynamic>> weeklyTemplates;
  final List<Map<String, dynamic>> instructors;
  final VoidCallback onTemplatesUpdated;

  const WeeklyTemplateBuilderWidget({
    Key? key,
    this.currentSeason,
    required this.weeklyTemplates,
    required this.instructors,
    required this.onTemplatesUpdated,
  }) : super(key: key);

  @override
  State<WeeklyTemplateBuilderWidget> createState() =>
      _WeeklyTemplateBuilderWidgetState();
}

class _WeeklyTemplateBuilderWidgetState
    extends State<WeeklyTemplateBuilderWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Disciplines loaded dynamically from Supabase
  List<Map<String, dynamic>> _availableDisciplines = [];
  bool _loadingDisciplines = true;

  final List<String> _daysOfWeek = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  Map<String, String> get _dayLabels => {
    'monday': 'seasonal_schedule.monday'.tr(),
    'tuesday': 'seasonal_schedule.tuesday'.tr(),
    'wednesday': 'seasonal_schedule.wednesday'.tr(),
    'thursday': 'seasonal_schedule.thursday'.tr(),
    'friday': 'seasonal_schedule.friday'.tr(),
    'saturday': 'seasonal_schedule.saturday'.tr(),
    'sunday': 'seasonal_schedule.sunday'.tr(),
  };

  @override
  void initState() {
    super.initState();
    _loadDisciplinesFromSupabase();
  }

  Future<void> _loadDisciplinesFromSupabase() async {
    try {
      final response = await _supabase
          .from('custom_disciplines')
          .select('name, display_name, color_hex')
          .eq('is_active', true)
          .order('display_name');

      final List<Map<String, dynamic>> disciplines = (response as List)
          .map(
            (d) => {
              'id': d['name'] as String,
              'label': (d['display_name'] ?? d['name']) as String,
              'color_hex': d['color_hex'] as String? ?? '#9E9E9E',
            },
          )
          .toList();

      if (mounted) {
        setState(() {
          _availableDisciplines = disciplines;
          _loadingDisciplines = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableDisciplines = [];
          _loadingDisciplines = false;
        });
      }
    }
  }

  /// Returns the display label for a discipline id, falling back to the raw id
  String _getDisciplineLabel(String? disciplineId) {
    if (disciplineId == null) return '';
    final match = _availableDisciplines.firstWhere(
      (d) => d['id'] == disciplineId,
      orElse: () => <String, dynamic>{},
    );
    return (match['label'] as String?) ?? disciplineId;
  }

  /// Returns the color for a discipline id
  Color _getDisciplineColor(String? disciplineId) {
    if (disciplineId == null) return Colors.grey;
    final match = _availableDisciplines.firstWhere(
      (d) => d['id'] == disciplineId,
      orElse: () => <String, dynamic>{},
    );
    final hex = match['color_hex'] as String?;
    if (hex == null) return Colors.grey;
    return _parseColor(hex);
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  void _showAddTemplateDialog([String? dayOfWeek]) {
    showDialog(
      context: context,
      builder: (context) => _TemplateEditorDialog(
        currentSeason: widget.currentSeason,
        instructors: widget.instructors,
        dayLabels: _dayLabels,
        availableDisciplines: _availableDisciplines,
        preselectedDay: dayOfWeek,
        onSave: (templateData) async {
          await _saveTemplate(templateData);
        },
      ),
    );
  }

  void _showEditTemplateDialog(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (context) => _TemplateEditorDialog(
        currentSeason: widget.currentSeason,
        instructors: widget.instructors,
        dayLabels: _dayLabels,
        availableDisciplines: _availableDisciplines,
        existingTemplate: template,
        onSave: (templateData) async {
          await _updateTemplate(template['id'], templateData);
        },
      ),
    );
  }

  Future<void> _saveTemplate(Map<String, dynamic> templateData) async {
    try {
      await _supabase.from('weekly_schedule_templates').insert({
        ...templateData,
        'seasonal_schedule_id': widget.currentSeason!['id'],
      });

      widget.onTemplatesUpdated();
      _showSuccessSnackBar('Template orario aggiunto con successo');
    } catch (error) {
      _showErrorSnackBar('seasonal_schedule.template_add_error'.tr());
    }
  }

  Future<void> _updateTemplate(
    String templateId,
    Map<String, dynamic> templateData,
  ) async {
    try {
      await _supabase
          .from('weekly_schedule_templates')
          .update(templateData)
          .eq('id', templateId);

      widget.onTemplatesUpdated();
      _showSuccessSnackBar('Template orario aggiornato');
    } catch (error) {
      _showErrorSnackBar('seasonal_schedule.template_update_error'.tr());
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('admin_discipline.delete_confirm_title'.tr()),
        content: Text('seasonal_schedule.delete_template_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase
            .from('weekly_schedule_templates')
            .delete()
            .eq('id', templateId);

        widget.onTemplatesUpdated();
        _showSuccessSnackBar('Template eliminato');
      } catch (error) {
        _showErrorSnackBar('seasonal_schedule.template_delete_error'.tr());
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentSeason == null) {
      return _buildNoSeasonWidget();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          SizedBox(height: 3.h),
          _buildWeeklyOverview(),
          SizedBox(height: 3.h),
          _buildTemplatesList(),
        ],
      ),
    );
  }

  Widget _buildNoSeasonWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          SizedBox(height: 2.h),
          Text(
            'seasonal_schedule.no_season_title'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'seasonal_schedule.configure_season_first'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.view_week,
                color: Theme.of(context).colorScheme.secondary,
                size: 28,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'seasonal_schedule.weekly_schema_title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'seasonal_schedule.weekly_schema_subtitle'.tr(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _loadingDisciplines
                  ? null
                  : () => _showAddTemplateDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16),
                  SizedBox(width: 1.w),
                  Text('seasonal_schedule.add'.tr()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'seasonal_schedule.weekly_overview'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        SizedBox(
          height: 20.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _daysOfWeek.length,
            itemBuilder: (context, index) {
              final day = _daysOfWeek[index];
              final dayTemplates = widget.weeklyTemplates
                  .where((t) => t['day_of_week'] == day)
                  .toList();

              return _buildDayColumn(day, dayTemplates);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayColumn(String day, List<Map<String, dynamic>> templates) {
    return Container(
      width: 30.w,
      margin: EdgeInsets.only(right: 3.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: templates.isNotEmpty
                  ? Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: templates.isNotEmpty
                    ? Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.3)
                    : Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dayLabels[day]!.substring(0, 3),
                  style: TextStyle(
                    color: templates.isNotEmpty
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${templates.length}',
                  style: TextStyle(
                    color: templates.isNotEmpty
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 1.h),

          // Templates for this day
          Expanded(
            child: templates.isEmpty
                ? InkWell(
                    onTap: () => _showAddTemplateDialog(day),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            'seasonal_schedule.add_time_slot'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return _buildMiniTemplateCard(template);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTemplateCard(Map<String, dynamic> template) {
    final discipline = template['discipline'] as String?;
    final disciplineColor = _getDisciplineColor(discipline);
    final disciplineLabel = _getDisciplineLabel(discipline);
    final startTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(template['start_time']),
    );
    final endTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(template['end_time']),
    );

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      child: InkWell(
        onTap: () => _showEditTemplateDialog(template),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: disciplineColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: disciplineColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                disciplineLabel,
                style: TextStyle(
                  color: disciplineColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                '${startTime.format(context)}-${endTime.format(context)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesList() {
    if (widget.weeklyTemplates.isEmpty) {
      return _buildEmptyTemplatesWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tutti i Template (${widget.weeklyTemplates.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.weeklyTemplates.length,
          itemBuilder: (context, index) {
            final template = widget.weeklyTemplates[index];
            return _buildTemplateCard(template);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyTemplatesWidget() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          children: [
            Icon(
              Icons.schedule,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 2.h),
            Text(
              'seasonal_schedule.no_templates_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'seasonal_schedule.no_templates_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: () => _showAddTemplateDialog(),
              icon: const Icon(Icons.add),
              label: Text('seasonal_schedule.add_first_template'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final discipline = template['discipline'] as String?;
    final disciplineColor = _getDisciplineColor(discipline);
    final disciplineLabel = _getDisciplineLabel(discipline);
    final dayOfWeek = template['day_of_week'];
    final startTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(template['start_time']),
    );
    final endTime = TimeOfDay.fromDateTime(
      DateFormat('HH:mm:ss').parse(template['end_time']),
    );
    final instructor = template['instructor'];

    return Card(
      margin: EdgeInsets.only(bottom: 2.h),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Row(
          children: [
            // Discipline indicator
            Container(
              width: 4,
              height: 8.h,
              decoration: BoxDecoration(
                color: disciplineColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 4.w),

            // Template info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.w,
                          vertical: 0.5.h,
                        ),
                        decoration: BoxDecoration(
                          color: disciplineColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          disciplineLabel,
                          style: TextStyle(
                            color: disciplineColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        _dayLabels[dayOfWeek] ?? dayOfWeek,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        '${startTime.format(context)} - ${endTime.format(context)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        instructor?['full_name'] ??
                            'seasonal_schedule.no_instructor_assigned'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        template['location'] ??
                            'seasonal_schedule.no_location'.tr(),
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

            // Actions
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _showEditTemplateDialog(template);
                    break;
                  case 'delete':
                    _deleteTemplate(template['id']);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 16),
                      SizedBox(width: 2.w),
                      Text('profile.modify'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'common.delete'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
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

// Template Editor Dialog
class _TemplateEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? currentSeason;
  final List<Map<String, dynamic>> instructors;
  final Map<String, String> dayLabels;
  final List<Map<String, dynamic>> availableDisciplines;
  final String? preselectedDay;
  final Map<String, dynamic>? existingTemplate;
  final Function(Map<String, dynamic>) onSave;

  const _TemplateEditorDialog({
    Key? key,
    this.currentSeason,
    required this.instructors,
    required this.dayLabels,
    required this.availableDisciplines,
    this.preselectedDay,
    this.existingTemplate,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _capacityController = TextEditingController(text: '20');

  String? _selectedDay;
  String? _selectedDiscipline;
  String? _selectedInstructorId;
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _notesController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    if (widget.preselectedDay != null) {
      _selectedDay = widget.preselectedDay;
    }

    if (widget.existingTemplate != null) {
      final template = widget.existingTemplate!;
      _selectedDay = template['day_of_week'];
      _selectedDiscipline = template['discipline'];
      _selectedInstructorId = template['instructor_id'];
      _locationController.text = template['location'] ?? '';
      _notesController.text = template['notes'] ?? '';
      _capacityController.text = (template['max_capacity'] ?? 20).toString();

      _startTime = TimeOfDay.fromDateTime(
        DateFormat('HH:mm:ss').parse(template['start_time']),
      );
      _endTime = TimeOfDay.fromDateTime(
        DateFormat('HH:mm:ss').parse(template['end_time']),
      );
    }
  }

  void _saveTemplate() {
    if (_selectedDay == null ||
        _selectedDiscipline == null ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('seasonal_schedule.required_fields'.tr()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final templateData = {
      'day_of_week': _selectedDay,
      'discipline': _selectedDiscipline,
      'start_time':
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
      'end_time':
          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00',
      'instructor_id': _selectedInstructorId,
      'location': _locationController.text,
      'max_capacity': int.tryParse(_capacityController.text) ?? 20,
      'notes': _notesController.text,
    };

    Navigator.pop(context);
    widget.onSave(templateData);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        widget.existingTemplate != null
            ? 'seasonal_schedule.edit_template'.tr()
            : 'seasonal_schedule.new_time_template'.tr(),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 80.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day selection
              DropdownButtonFormField<String>(
                initialValue: _selectedDay,
                decoration: InputDecoration(
                  labelText: 'Giorno della Settimana *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: widget.dayLabels.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedDay = value),
              ),
              SizedBox(height: 2.h),

              // Discipline selection — fully dynamic from Supabase
              widget.availableDisciplines.isEmpty
                  ? InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Disciplina *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Caricamento discipline...',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue:
                          _selectedDiscipline != null &&
                              widget.availableDisciplines.any(
                                (d) => d['id'] == _selectedDiscipline,
                              )
                          ? _selectedDiscipline
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Disciplina *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      hint: const Text('Seleziona disciplina'),
                      items: widget.availableDisciplines.map((discipline) {
                        return DropdownMenuItem<String>(
                          value: discipline['id'] as String,
                          child: Text(discipline['label'] as String),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedDiscipline = value),
                    ),
              SizedBox(height: 2.h),

              // Instructor selection
              DropdownButtonFormField<String>(
                initialValue: _selectedInstructorId,
                decoration: InputDecoration(
                  labelText: 'seasonal_schedule.instructor'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                hint: Text('seasonal_schedule.select_instructor'.tr()),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'seasonal_schedule.no_instructor_assigned'.tr(),
                    ),
                  ),
                  ...widget.instructors.map((instructor) {
                    return DropdownMenuItem<String>(
                      value: instructor['user_id'] as String?,
                      child: Text(
                        instructor['user_profiles']?['full_name'] ??
                            instructor['full_name'] ??
                            'Istruttore',
                      ),
                    );
                  }),
                ],
                onChanged: (value) =>
                    setState(() => _selectedInstructorId = value),
              ),
              SizedBox(height: 2.h),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'seasonal_schedule.location'.tr() + ' *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 2.h),

              // Time selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (time != null) setState(() => _startTime = time);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'seasonal_schedule.start_time'.tr(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (time != null) setState(() => _endTime = time);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'seasonal_schedule.end_time'.tr(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),

              // Capacity
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'seasonal_schedule.max_capacity'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 2.h),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'seasonal_schedule.notes'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _saveTemplate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
          ),
          child: Text('common.save'.tr()),
        ),
      ],
    );
  }
}
