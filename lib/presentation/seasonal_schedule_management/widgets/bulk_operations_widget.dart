import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
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
  int _generatedInstancesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadScheduleInstancesCount();
  }

  @override
  void didUpdateWidget(BulkOperationsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSeason != widget.currentSeason) {
      _loadScheduleInstancesCount();
    }
  }

  Future<void> _loadScheduleInstancesCount() async {
    if (widget.currentSeason == null) return;

    try {
      final response = await _supabase
          .from('schedule_instances')
          .select('id')
          .eq('seasonal_schedule_id', widget.currentSeason!['id']);

      setState(() {
        _generatedInstancesCount = response.length;
      });
    } catch (error) {
      // Silent fail for count
    }
  }

  Future<void> _generateScheduleInstances() async {
    if (widget.currentSeason == null) return;

    setState(() => _isProcessing = true);

    try {
      HapticFeedback.mediumImpact();

      final response = await _supabase.rpc(
        'generate_seasonal_schedule_instances',
        params: {'schedule_id': widget.currentSeason!['id']},
      );

      await _loadScheduleInstancesCount();
      widget.onOperationCompleted();
      _showSuccessSnackBar('bulk_schedule.lessons_generated'
          .tr(namedArgs: {'count': '$response'}));
    } catch (error) {
      _showErrorSnackBar('bulk_schedule.generate_error'.tr());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _activateSchedule() async {
    if (widget.currentSeason == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('bulk_schedule.activate_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sei sicuro di voler attivare questo palinsesto?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2.h),
            Text('bulk_schedule.once_activated'.tr()),
            SizedBox(height: 1.h),
            Text('bulk_schedule.visible_to_all'.tr()),
            Text('bulk_schedule.becomes_official'.tr()),
            Text('bulk_schedule.users_can_book'.tr()),
            SizedBox(height: 2.h),
            if (_generatedInstancesCount > 0)
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        '$_generatedInstancesCount lezioni pronte per l\'attivazione',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'bulk_schedule.no_lessons_generate_first'.tr(),
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('bulk_schedule.activate_button'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      HapticFeedback.heavyImpact();

      // First deactivate any existing active schedules
      await _supabase
          .from('seasonal_schedules')
          .update({'status': 'completed'}).eq('status', 'active');

      // Then activate the current schedule
      await _supabase
          .from('seasonal_schedules')
          .update({'status': 'active'}).eq('id', widget.currentSeason!['id']);

      widget.onOperationCompleted();

      // Show success dialog
      _showActivationSuccessDialog();
    } catch (error) {
      _showErrorSnackBar('bulk_schedule.activate_error'.tr());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showActivationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 2.w),
            Text('bulk_schedule.activated_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'bulk_schedule.activated_message'.tr(),
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 2.h),
            Text('bulk_schedule.visible_now'.tr()),
            Text('bulk_schedule.students_can_book_lessons'.tr()),
            Text('bulk_schedule.available_in_class_schedule'.tr()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('bulk_schedule.continue_here'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/dashboard-home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: Text('bulk_schedule.go_home'.tr()),
          ),
        ],
      ),
    );
  }

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
      _showErrorSnackBar('bulk_schedule.duplicate_error'.tr());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _massInstructorReassignment() async {
    if (widget.instructors.isEmpty) {
      _showErrorSnackBar('bulk_schedule.no_instructors'.tr());
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
        _showErrorSnackBar('bulk_schedule.reassign_error'.tr());
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _bulkTimeAdjustment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _TimeAdjustmentDialog(weeklyTemplates: widget.weeklyTemplates),
    );

    if (result != null) {
      setState(() => _isProcessing = true);

      try {
        HapticFeedback.mediumImpact();

        final adjustment = result['adjustment'] as int; // minutes
        final selectedTemplateIds = result['template_ids'] as List<String>;

        for (final templateId in selectedTemplateIds) {
          final template = widget.weeklyTemplates.firstWhere(
            (t) => t['id'] == templateId,
          );

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

          await _supabase
              .from('weekly_schedule_templates')
              .update({'start_time': newStartTime, 'end_time': newEndTime}).eq(
                  'id', templateId);
        }

        widget.onOperationCompleted();
        _showSuccessSnackBar('Orari aggiornati con successo');
      } catch (error) {
        _showErrorSnackBar('bulk_schedule.times_update_error'.tr());
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _clearAllScheduleInstances() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('bulk_schedule.cancel_all_title'.tr()),
        content: Text(
          'Attenzione! Questa operazione cancellerà tutte le istanze di palinsesto generate. '
          'Dovrai rigenerare tutto il calendario. Continuare?',
        ),
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
            child: Text('bulk_schedule.cancel_all_button'.tr()),
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
          'Tutte le istanze di palinsesto sono state cancellate',
        );
      } catch (error) {
        _showErrorSnackBar('bulk_schedule.cancel_instances_error'.tr());
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
      'sunday',
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

    final isDraft = widget.currentSeason!['status'] == 'draft';
    final isActive = widget.currentSeason!['status'] == 'active';

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Schedule Activation Section at the top
          _buildScheduleActivationCard(isDraft, isActive),
          SizedBox(height: 3.h),

          _buildHeaderCard(),
          SizedBox(height: 3.h),
          _buildOperationsGrid(),
        ],
      ),
    );
  }

  Widget _buildScheduleActivationCard(bool isDraft, bool isActive) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDraft
              ? Colors.green.withValues(alpha: 0.3)
              : isActive
                  ? Colors.blue.withValues(alpha: 0.3)
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(5.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: isDraft
                        ? Colors.green.withValues(alpha: 0.1)
                        : isActive
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDraft
                        ? Icons.publish
                        : isActive
                            ? Icons.check_circle
                            : Icons.schedule,
                    color: isDraft
                        ? Colors.green
                        : isActive
                            ? Colors.blue
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDraft
                            ? 'bulk_schedule.activation_in_progress'.tr()
                            : isActive
                                ? 'Palinsesto Attivo'
                                : 'Stato Palinsesto',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        isDraft
                            ? 'Rendi il palinsesto visibile agli utenti'
                            : isActive
                                ? 'Visibile a tutti gli utenti'
                                : 'Gestisci lo stato del palinsesto',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 3.h),

            // Schedule Status Info
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Configurazione Schema:',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${widget.weeklyTemplates.length} template',
                        style: TextStyle(
                          color: widget.weeklyTemplates.isEmpty
                              ? Colors.orange
                              : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      Icon(
                        Icons.class_,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'Lezioni Generate:',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '$_generatedInstancesCount lezioni',
                        style: TextStyle(
                          color: _generatedInstancesCount == 0
                              ? Colors.orange
                              : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (isDraft) ...[
              SizedBox(height: 3.h),

              // Action Buttons for Draft Status
              if (widget.weeklyTemplates.isEmpty)
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          'Configura prima gli orari settimanali nella sezione "Schema Orari"',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            widget.weeklyTemplates.isNotEmpty && !_isProcessing
                                ? _generateScheduleInstances
                                : null,
                        icon: _isProcessing
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.auto_awesome),
                        label: Text('bulk_schedule.generate_instances'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _generatedInstancesCount > 0 && !_isProcessing
                                ? _activateSchedule
                                : null,
                        icon: Icon(Icons.publish, size: 20),
                        label: Text('bulk_schedule.activate_button'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 2.h),

                // Info message
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Processo di Attivazione',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              '1. Clicca "Genera Lezioni" per creare tutte le istanze di lezione per l\'anno\n'
                              '2. Verifica le lezioni generate\n'
                              '3. Clicca "Attiva Palinsesto" per rendere visibile il calendario agli utenti',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (isActive) ...[
              SizedBox(height: 3.h),

              // Active Status Info
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Palinsesto Attivo',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Il palinsesto è visibile a tutti gli utenti nella sezione "Orario Classi". Gli studenti possono prenotare le lezioni.',
                            style: TextStyle(color: Colors.green, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
              child: Icon(Icons.settings, color: Colors.purple, size: 28),
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
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? color
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 32,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: enabled
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
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
                      : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              'bulk_schedule.select_template_duplicate'.tr(),
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
                  '${template['discipline']} - ${template['day_of_week']}',
                ),
                subtitle: Text(
                  '${template['start_time']} - ${template['end_time']}',
                ),
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
      title: Text('bulk_schedule.duplicate_template'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedDay,
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
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('seasonal_schedule.start_time'.tr()),
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
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('seasonal_schedule.end_time'.tr()),
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
          child: Text('common.cancel'.tr()),
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
          child: Text('bulk_schedule.duplicate_template'.tr()),
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
      title: Text('bulk_schedule.reassign_instructor'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _fromInstructorId,
              decoration: InputDecoration(
                labelText: 'Da Istruttore',
                border: OutlineInputBorder(),
              ),
              items: widget.instructors.map<DropdownMenuItem<String>>((
                instructor,
              ) {
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
              initialValue: _toInstructorId,
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
              Text('bulk_schedule.select_templates'.tr()),
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
                    '${template['discipline']} - ${template['day_of_week']}',
                  ),
                  subtitle: Text(
                    '${template['start_time']} - ${template['end_time']}',
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
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
          child: Text('bulk_schedule.reassign_instructor'.tr()),
        ),
      ],
    );
  }
}

// Time Adjustment Dialog
class _TimeAdjustmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> weeklyTemplates;

  const _TimeAdjustmentDialog({Key? key, required this.weeklyTemplates})
      : super(key: key);

  @override
  State<_TimeAdjustmentDialog> createState() => _TimeAdjustmentDialogState();
}

class _TimeAdjustmentDialogState extends State<_TimeAdjustmentDialog> {
  int _adjustment = 0; // in minutes
  List<String> _selectedTemplateIds = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('bulk_schedule.adjust_times'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('bulk_schedule.shift_times_by'.tr()),
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
                    child: Text('bulk_schedule.shift_minus_30'.tr()),
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
                    child: Text('bulk_schedule.shift_minus_15'.tr()),
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
                    child: Text('bulk_schedule.shift_plus_15'.tr()),
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
                    child: Text('bulk_schedule.shift_plus_30'.tr()),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text('bulk_schedule.select_template'.tr()),
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
                  '${template['discipline']} - ${template['day_of_week']}',
                ),
                subtitle: Text(
                  '${template['start_time']} - ${template['end_time']}',
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common.cancel'.tr()),
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
          child: Text('common.confirm'.tr()),
        ),
      ],
    );
  }
}
