import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import './instructor_selection_dialog_widget.dart';
import './discipline_subscription_plans_widget.dart';
import '../../../services/discipline_service.dart';

class DisciplineEditorWidget extends StatefulWidget {
  final Map<String, dynamic>? discipline;
  final List<Map<String, dynamic>> instructorProfiles;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const DisciplineEditorWidget({
    super.key,
    this.discipline,
    required this.instructorProfiles,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<DisciplineEditorWidget> createState() => _DisciplineEditorWidgetState();
}

class _DisciplineEditorWidgetState extends State<DisciplineEditorWidget> {
  late Map<String, dynamic> _disciplineData;
  bool _isLoading = false;
  final DisciplineService _disciplineService = DisciplineService.instance;

  @override
  void initState() {
    super.initState();
    _disciplineData = widget.discipline != null
        ? Map<String, dynamic>.from(widget.discipline!)
        : {
            'id': '',
            'name': '',
            'isActive': true,
            'color': const Color(0xFF2196F3),
            'instructors': <String>[],
            'locations': <String>[],
            'schedule': <String, dynamic>{},
          };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.discipline != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.sports_martial_arts,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 12),
              Text(
                isEditing
                    ? 'admin_discipline.discipline_details'
                        .tr(namedArgs: {'name': '${_disciplineData['name']}'})
                    : 'admin_discipline.new_discipline'.tr(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEditing) ...[
                    _buildInfoSection(),
                    const SizedBox(height: 24),
                    _buildSubscriptionPlansSection(),
                    const SizedBox(height: 24),
                    _buildInstructorsSection(),
                    const SizedBox(height: 24),
                    _buildScheduleSection(),
                    const SizedBox(height: 24),
                    _buildLocationsSection(),
                  ] else
                    _buildNewDisciplineInfo(),
                ],
              ),
            ),
          ),

          // Actions
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: Text('common.cancel'.tr()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      isEditing ? _navigateToManagement : _navigateToCreate,
                  child: Text(isEditing
                      ? 'admin_discipline.manage'.tr()
                      : 'common.create'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'admin_discipline.discipline_info'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _disciplineData['color'],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _disciplineData['name'],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'Disciplina ${_disciplineData['isActive'] ? 'attiva' : 'inattiva'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _disciplineData['isActive']
                                ? Colors.green
                                : Colors.orange,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorsSection() {
    final instructors = List<String>.from(_disciplineData['instructors']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'admin_management.instructors_filter'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showInstructorSelectionDialog,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('admin_discipline.manage'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (instructors.isEmpty)
              Text(
                'admin_discipline.no_instructor'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                    ),
              )
            else
              ...instructors.map((instructor) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 8),
                        Text(instructor),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    final schedule = Map<String, dynamic>.from(_disciplineData['schedule']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Orari',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/seasonal-schedule-creation',
                    arguments: {'disciplineFilter': _disciplineData['id']},
                  ),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('profile.modify'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (schedule.isEmpty)
              Text(
                'seasonal_schedule.no_schedule_in_card'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                    ),
              )
            else
              ...schedule.entries.map((dayEntry) {
                final dayName = dayEntry.key;
                final sessions =
                    List<Map<String, dynamic>>.from(dayEntry.value);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      ...sessions.map((session) => Padding(
                            padding: const EdgeInsets.only(left: 16, top: 2),
                            child: Text(
                              '${session['time']} - ${session['location']} (${session['instructor']})',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlansSection() {
    return DisciplineSubscriptionPlansWidget(
      disciplineId: _disciplineData['id'] ?? '',
      disciplineName: _disciplineData['name'] ?? '',
    );
  }

  Widget _buildLocationsSection() {
    final locations = List<String>.from(_disciplineData['locations']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Locations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: locations
                  .map((location) => Chip(
                        label: Text(location),
                        avatar: const Icon(Icons.place, size: 16),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewDisciplineInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Le discipline vengono create automaticamente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Per aggiungere una nuova disciplina:\n\n'
              '• Crea un profilo istruttore con quella disciplina\n'
              '• Aggiungi la disciplina a un palinsesto stagionale\n'
              '• La disciplina apparirà automaticamente nella lista',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showInstructorSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => InstructorSelectionDialogWidget(
        discipline: _disciplineData['id'],
        disciplineName: _disciplineData['name'],
        currentInstructors: List<String>.from(
          _disciplineData['instructors'],
        ),
        onInstructorSelected: _handleInstructorSelected,
      ),
    );
  }

  Future<void> _handleInstructorSelected(
    String instructorUserId,
    String instructorName,
  ) async {
    try {
      // Show loading indicator
      setState(() => _isLoading = true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('admin_discipline.assigning_instructor'.tr()),
            ],
          ),
        ),
      );

      // Get current season ID for context
      final seasonId =
          await _disciplineService.getCurrentSeasonIdForInstructorAssignment();

      // Update instructor assignment for this discipline
      final success = await _disciplineService.updateDisciplineInstructor(
        discipline: _disciplineData['id'],
        newInstructorUserId: instructorUserId,
        seasonId: seasonId,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Istruttore $instructorName assegnato a ${_disciplineData['name']} con successo',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: 'common.ok'.tr(),
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Trigger refresh by calling onSave callback
        widget.onSave(_disciplineData);
      } else {
        throw Exception('Operazione fallita');
      }
    } catch (error) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin_discipline.assign_error'
                .tr(namedArgs: {'error': error.toString()}),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'common.ok'.tr(),
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToManagement() {
    widget.onCancel();
    Navigator.pushNamed(context, AppRoutes.instructorManagementSystem);
  }

  void _navigateToCreate() {
    widget.onCancel();
    Navigator.pushNamed(context, '/seasonal-schedule-creation');
  }
}
