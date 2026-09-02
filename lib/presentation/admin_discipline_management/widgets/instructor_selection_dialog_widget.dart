import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import '../../../services/discipline_service.dart';

class InstructorSelectionDialogWidget extends StatefulWidget {
  final String discipline;
  final String disciplineName;
  final List<String> currentInstructors;
  final Function(String instructorUserId, String instructorName)
      onInstructorSelected;

  const InstructorSelectionDialogWidget({
    super.key,
    required this.discipline,
    required this.disciplineName,
    required this.currentInstructors,
    required this.onInstructorSelected,
  });

  @override
  State<InstructorSelectionDialogWidget> createState() =>
      _InstructorSelectionDialogWidgetState();
}

class _InstructorSelectionDialogWidgetState
    extends State<InstructorSelectionDialogWidget> {
  final DisciplineService _disciplineService = DisciplineService.instance;
  List<Map<String, dynamic>> _qualifiedInstructors = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedInstructorUserId;
  String? _selectedInstructorName;

  @override
  void initState() {
    super.initState();
    _loadQualifiedInstructors();
  }

  Future<void> _loadQualifiedInstructors() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final instructors = await _disciplineService.getInstructorsForDiscipline(
        widget.discipline,
      );

      setState(() {
        _qualifiedInstructors = instructors;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: theme.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'admin_discipline.select_instructor_title'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'admin_discipline.for_discipline'
                            .tr(namedArgs: {'name': widget.disciplineName}),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Current instructors info
            if (widget.currentInstructors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(77),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'admin_discipline.current_instructors'.tr(namedArgs: {
                          'list': widget.currentInstructors.join(', '),
                        }),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _qualifiedInstructors.isEmpty
                          ? _buildEmptyState()
                          : _buildInstructorList(),
            ),

            // Actions
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('common.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedInstructorUserId != null
                        ? _handleConfirm
                        : null,
                    child: Text('common.confirm'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'admin_discipline.load_instructors_error'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'admin_discipline.unknown_error'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadQualifiedInstructors,
            icon: const Icon(Icons.refresh),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(77),
          ),
          const SizedBox(height: 16),
          Text(
            'admin_discipline.no_qualified_instructors'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'admin_discipline.no_qualified_hint'
                .tr(namedArgs: {'name': widget.disciplineName}),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/instructor-management');
            },
            icon: const Icon(Icons.person_add),
            label: Text('admin_discipline.add_instructor'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorList() {
    return ListView.builder(
      itemCount: _qualifiedInstructors.length,
      itemBuilder: (context, index) {
        final instructor = _qualifiedInstructors[index];
        final isSelected = _selectedInstructorUserId == instructor['user_id'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedInstructorUserId = instructor['user_id'];
                _selectedInstructorName = instructor['name'];
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Profile image
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: instructor['profile_image_url'] != null
                        ? NetworkImage(instructor['profile_image_url'])
                        : null,
                    child: instructor['profile_image_url'] == null
                        ? const Icon(Icons.person, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Instructor details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instructor['name'],
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${instructor['years_experience'] ?? 0} anni di esperienza',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (instructor['primary_discipline'] != null) ...[
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(
                              instructor['primary_discipline'],
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Selection indicator
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(128),
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleConfirm() {
    if (_selectedInstructorUserId != null && _selectedInstructorName != null) {
      widget.onInstructorSelected(
        _selectedInstructorUserId!,
        _selectedInstructorName!,
      );
      Navigator.pop(context);
    }
  }
}
