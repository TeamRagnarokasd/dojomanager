import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
// Add this import for DateFormat

class BulkOperationsWidget extends StatefulWidget {
  final Map<String, dynamic>? currentSeason;
  final List<Map<String, dynamic>> weeklyTemplates;
  final List<Map<String, dynamic>> instructors;
  final VoidCallback onOperationCompleted;

  const BulkOperationsWidget({
    Key? key,
    this.currentSeason,
    required this.weeklyTemplates,
    required this.instructors,
    required this.onOperationCompleted,
  }) : super(key: key);

  @override
  State<BulkOperationsWidget> createState() => _BulkOperationsWidgetState();
}

class _BulkOperationsWidgetState extends State<BulkOperationsWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isProcessing = false;

  Future<void> _duplicateTemplate(Map<String, dynamic> sourceTemplate) async {
    setState(() => _isProcessing = true);

    try {
      HapticFeedback.mediumImpact();

      // Show duplication dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _TemplateDuplicationDialog(
          sourceTemplate: sourceTemplate,
          availableDays: _getAvailableDays(),
        ),
      );

      if (result != null) {
        await _supabase.from('weekly_schedule_templates').insert({
          ...sourceTemplate,
          'id': null, // Let database generate new ID
          'day_of_week': result['day_of_week'],
          'start_time': result['start_time'],
          'end_time': result['end_time'],
        });

        widget.onOperationCompleted();
        _showSuccessSnackBar('Template duplicato con successo');
      }
    } catch (error) {
      _showErrorSnackBar('Errore nella duplicazione template');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _massInstructorReassignment() async {
    if (widget.instructors.isEmpty) {
      _showErrorSnackBar('Nessun istruttore disponibile');
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _InstructorReassignmentDialog(
        instructors: widget.instructors,
        weeklyTemplates: widget.weeklyTemplates,
      ),
    );

    if (result != null) {
      setState(() => _isProcessing = true);

      try {
        HapticFeedback.mediumImpact();

        final fromInstructorId = result['from_instructor_id'];
        final toInstructorId = result['to_instructor_id'];
        final selectedTemplateIds = result['template_ids'] as List<String>;

        // Update weekly templates
        if (selectedTemplateIds.isNotEmpty) {
          for (final templateId in selectedTemplateIds) {
            await _supabase
                .from('weekly_schedule_templates')
                .update({'instructor_id': toInstructorId}).eq('id', templateId);
          }
        } else {
          // Update all templates for the instructor
          await _supabase
              .from('weekly_schedule_templates')
              .update({'instructor_id': toInstructorId})
              .eq('instructor_id', fromInstructorId)
              .eq('seasonal_schedule_id', widget.currentSeason!['id']);
        }

        // Update existing schedule instances
        await _supabase
            .from('schedule_instances')
            .update({'instructor_id': toInstructorId})
            .eq('instructor_id', fromInstructorId)
            .eq('seasonal_schedule_id', widget.currentSeason!['id']);

        widget.onOperationCompleted();
        _showSuccessSnackBar('Riassegnazione istruttore completata');
      } catch (error) {
        _showErrorSnackBar('Errore nella riassegnazione istruttore');
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _bulkTimeAdjustment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _TimeAdjustmentDialog(
        weeklyTemplates: widget.weeklyTemplates,
      ),
    );

    if (result != null) {
      setState(() => _isProcessing = true);

      try {
        HapticFeedback.mediumImpact();

        final adjustment = result['adjustment'] as int; // minutes
        final selectedTemplateIds = result['template_ids'] as List<String>;

        for (final templateId in selectedTemplateIds) {
          final template =
              widget.weeklyTemplates.firstWhere((t) => t['id'] == templateId);

          // Parse current times
          final currentStartParts = template['start_time'].split(':');
          final currentEndParts = template['end_time'].split(':');

          var startMinutes = int.parse(currentStartParts[0]) * 60 +
              int.parse(currentStartParts[1]);
          var endMinutes = int.parse(currentEndParts[0]) * 60 +
              int.parse(currentEndParts[1]);

          // Apply adjustment
          startMinutes += adjustment;
          endMinutes += adjustment;

          // Validate time bounds
          if (startMinutes < 0 ||
              endMinutes >= 24 * 60 ||
              startMinutes >= endMinutes) {
            continue; // Skip invalid adjustments
          }

          // Format new times
          final newStartTime =
              '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).toString().padLeft(2, '0')}:00';
          final newEndTime =
              '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:${(endMinutes % 60).toString().padLeft(2, '0')}:00';

          await _supabase.from('weekly_schedule_templates').update({
            'start_time': newStartTime,
            'end_time': newEndTime,
          }).eq('id', templateId);
        }

        widget.onOperationCompleted();
        _showSuccessSnackBar('Orari aggiornati con successo');
      } catch (error) {
        _showErrorSnackBar('Errore nell\'aggiornamento orari');
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _clearAllScheduleInstances() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conferma Cancellazione'),
        content: Text(
            'Attenzione! Questa operazione cancellerà tutte le istanze di palinsesto generate. '
            'Dovrai rigenerare tutto il calendario. Continuare?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('Cancella Tutto'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);

      try {
        HapticFeedback.heavyImpact();

        await _supabase
            .from('schedule_instances')
            .delete()
            .eq('seasonal_schedule_id', widget.currentSeason!['id']);

        widget.onOperationCompleted();
        _showSuccessSnackBar(
            'Tutte le istanze di palinsesto sono state cancellate');
      } catch (error) {
        _showErrorSnackBar('Errore nella cancellazione delle istanze');
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  List<String> _getAvailableDays() {
    final allDays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final usedDays =
        widget.weeklyTemplates.map((t) => t['day_of_week']).toSet();
    return allDays.where((day) => !usedDays.contains(day)).toList();
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
          _buildOperationsGrid(),
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
            Icons.settings,
            size: 64,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          SizedBox(height: 2.h),
          Text(
            'Nessuna Stagione Configurata',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Configura prima una stagione per accedere alle operazioni bulk',
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
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings,
                color: Colors.purple,
                size: 28,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operazioni Bulk',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Esegui operazioni di massa sui template e sul palinsesto',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_isProcessing)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOperationCard(
                'Duplica Template',
                'Copia un template esistente su altri giorni',
                Icons.content_copy,
                Colors.blue,
                widget.weeklyTemplates.isNotEmpty && !_isProcessing,
                () => _showTemplateDuplicationOptions(),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildOperationCard(
                'Riassegna Istruttore',
                'Cambia istruttore su più template',
                Icons.person_search,
                Colors.green,
                widget.weeklyTemplates.isNotEmpty &&
                    widget.instructors.length > 1 &&
                    !_isProcessing,
                _massInstructorReassignment,
              ),
            ),
          ],
        ),
        SizedBox(height: 3.w),
        Row(
          children: [
            Expanded(
              child: _buildOperationCard(
                'Aggiusta Orari',
                'Sposta tutti gli orari di X minuti',
                Icons.schedule,
                Colors.orange,
                widget.weeklyTemplates.isNotEmpty && !_isProcessing,
                _bulkTimeAdjustment,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: _buildOperationCard(
                'Cancella Tutto',
                'Rimuovi tutte le istanze generate',
                Icons.delete_sweep,
                Colors.red,
                !_isProcessing,
                _clearAllScheduleInstances,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOperationCard(
    String title,
    String description,
    IconData icon,
    Color color,
    bool enabled,
    VoidCallback? onTap,
  ) {
    return Card(
      color: enabled
          ? Theme.of(context).cardColor
          : Theme.of(context).cardColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: enabled
              ? color.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: enabled
                      ? color.withValues(alpha: 0.1)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? color
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                  size: 32,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: enabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 1.h),
              Text(
                description,
                style: TextStyle(
                  color: enabled
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTemplateDuplicationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Seleziona Template da Duplicare',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 3.h),
            ...widget.weeklyTemplates.map((template) {
              return ListTile(
                leading: Icon(Icons.content_copy, color: Colors.blue),
                title: Text(
                    '${template['discipline']} - ${template['day_of_week']}'),
                subtitle:
                    Text('${template['start_time']} - ${template['end_time']}'),
                onTap: () {
                  Navigator.pop(context);
                  _duplicateTemplate(template);
                },
              );
            }).toList(),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}

// Template Duplication Dialog
class _TemplateDuplicationDialog extends StatefulWidget {
  final Map<String, dynamic> sourceTemplate;
  final List<String> availableDays;

  const _TemplateDuplicationDialog({
    Key? key,
    required this.sourceTemplate,
    required this.availableDays,
  }) : super(key: key);

  @override
  State<_TemplateDuplicationDialog> createState() =>
      _TemplateDuplicationDialogState();
}

class _TemplateDuplicationDialogState
    extends State<_TemplateDuplicationDialog> {
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final Map<String, String> _dayLabels = {
    'monday': 'Lunedì',
    'tuesday': 'Martedì',
    'wednesday': 'Mercoledì',
    'thursday': 'Giovedì',
    'friday': 'Venerdì',
    'saturday': 'Sabato',
    'sunday': 'Domenica',
  };

  @override
  void initState() {
    super.initState();
    // Initialize with source template times - parse time string directly
    final startTimeParts = widget.sourceTemplate['start_time'].split(':');
    final endTimeParts = widget.sourceTemplate['end_time'].split(':');
    
    _startTime = TimeOfDay(
      hour: int.parse(startTimeParts[0]),
      minute: int.parse(startTimeParts[1]),
    );
    _endTime = TimeOfDay(
      hour: int.parse(endTimeParts[0]),
      minute: int.parse(endTimeParts[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Duplica Template'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedDay,
            decoration: InputDecoration(
              labelText: 'Nuovo Giorno *',
              border: OutlineInputBorder(),
            ),
            items: widget.availableDays.map<DropdownMenuItem<String>>((day) {
              return DropdownMenuItem<String>(
                value: day,
                child: Text(_dayLabels[day] ?? day),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedDay = value),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _startTime!,
                    );
                    if (time != null) {
                      setState(() => _startTime = time);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ora Inizio'),
                        Text(_startTime?.format(context) ?? ''),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _endTime!,
                    );
                    if (time != null) {
                      setState(() => _endTime = time);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ora Fine'),
                        Text(_endTime?.format(context) ?? ''),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed:
              _selectedDay != null && _startTime != null && _endTime != null
                  ? () {
                      Navigator.pop(context, {
                        'day_of_week': _selectedDay,
                        'start_time':
                            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00',
                        'end_time':
                            '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00',
                      });
                    }
                  : null,
          child: Text('Duplica'),
        ),
      ],
    );
  }
}

// Instructor Reassignment Dialog
class _InstructorReassignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> instructors;
  final List<Map<String, dynamic>> weeklyTemplates;

  const _InstructorReassignmentDialog({
    Key? key,
    required this.instructors,
    required this.weeklyTemplates,
  }) : super(key: key);

  @override
  State<_InstructorReassignmentDialog> createState() =>
      _InstructorReassignmentDialogState();
}

class _InstructorReassignmentDialogState
    extends State<_InstructorReassignmentDialog> {
  String? _fromInstructorId;
  String? _toInstructorId;
  List<String> _selectedTemplateIds = [];

  @override
  Widget build(BuildContext context) {
    final fromInstructorTemplates = widget.weeklyTemplates
        .where((t) => t['instructor_id'] == _fromInstructorId)
        .toList();

    return AlertDialog(
      title: Text('Riassegna Istruttore'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _fromInstructorId,
              decoration: InputDecoration(
                labelText: 'Da Istruttore',
                border: OutlineInputBorder(),
              ),
              items: widget.instructors.map<DropdownMenuItem<String>>((instructor) {
                return DropdownMenuItem<String>(
                  value: instructor['id'],
                  child: Text(instructor['full_name']),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _fromInstructorId = value;
                _selectedTemplateIds.clear();
              }),
            ),
            SizedBox(height: 2.h),
            DropdownButtonFormField<String>(
              value: _toInstructorId,
              decoration: InputDecoration(
                labelText: 'A Istruttore',
                border: OutlineInputBorder(),
              ),
              items: widget.instructors
                  .where((i) => i['id'] != _fromInstructorId)
                  .map<DropdownMenuItem<String>>((instructor) {
                return DropdownMenuItem<String>(
                  value: instructor['id'],
                  child: Text(instructor['full_name']),
                );
              }).toList(),
              onChanged: (value) => setState(() => _toInstructorId = value),
            ),
            if (fromInstructorTemplates.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text('Seleziona Template (vuoto = tutti)'),
              ...fromInstructorTemplates.map((template) {
                return CheckboxListTile(
                  value: _selectedTemplateIds.contains(template['id']),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedTemplateIds.add(template['id']);
                      } else {
                        _selectedTemplateIds.remove(template['id']);
                      }
                    });
                  },
                  title: Text(
                      '${template['discipline']} - ${template['day_of_week']}'),
                  subtitle: Text(
                      '${template['start_time']} - ${template['end_time']}'),
                );
              }).toList(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _fromInstructorId != null && _toInstructorId != null
              ? () {
                  Navigator.pop(context, {
                    'from_instructor_id': _fromInstructorId,
                    'to_instructor_id': _toInstructorId,
                    'template_ids': _selectedTemplateIds,
                  });
                }
              : null,
          child: Text('Riassegna'),
        ),
      ],
    );
  }
}

// Time Adjustment Dialog
class _TimeAdjustmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> weeklyTemplates;

  const _TimeAdjustmentDialog({
    Key? key,
    required this.weeklyTemplates,
  }) : super(key: key);

  @override
  State<_TimeAdjustmentDialog> createState() => _TimeAdjustmentDialogState();
}

class _TimeAdjustmentDialogState extends State<_TimeAdjustmentDialog> {
  int _adjustment = 0; // in minutes
  List<String> _selectedTemplateIds = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Aggiusta Orari'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sposta orari di:'),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _adjustment = -30),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _adjustment == -30
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                    child: Text('-30 min'),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _adjustment = -15),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _adjustment == -15
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                    child: Text('-15 min'),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _adjustment = 15),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _adjustment == 15
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                    child: Text('+15 min'),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _adjustment = 30),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _adjustment == 30
                          ? Theme.of(context).colorScheme.secondary
                          : null,
                    ),
                    child: Text('+30 min'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text('Seleziona Template:'),
            ...widget.weeklyTemplates.map((template) {
              return CheckboxListTile(
                value: _selectedTemplateIds.contains(template['id']),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedTemplateIds.add(template['id']);
                    } else {
                      _selectedTemplateIds.remove(template['id']);
                    }
                  });
                },
                title: Text(
                    '${template['discipline']} - ${template['day_of_week']}'),
                subtitle:
                    Text('${template['start_time']} - ${template['end_time']}'),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Annulla'),
        ),
        ElevatedButton(
          onPressed: _adjustment != 0 && _selectedTemplateIds.isNotEmpty
              ? () {
                  Navigator.pop(context, {
                    'adjustment': _adjustment,
                    'template_ids': _selectedTemplateIds,
                  });
                }
              : null,
          child: Text('Applica'),
        ),
      ],
    );
  }
}