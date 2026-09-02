import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_export.dart';
import '../../services/discipline_service.dart';
import '../../services/auth_service.dart';
import '../../services/realtime_notification_service.dart';

import './widgets/bulk_operations_toolbar_widget.dart';
import './widgets/discipline_card_widget.dart';
import './widgets/discipline_editor_widget.dart';
import './widgets/discipline_header_widget.dart';

class AdminDisciplineManagement extends StatefulWidget {
  const AdminDisciplineManagement({super.key});

  @override
  State<AdminDisciplineManagement> createState() =>
      _AdminDisciplineManagementState();
}

class _AdminDisciplineManagementState extends State<AdminDisciplineManagement> {
  final DisciplineService _disciplineService = DisciplineService.instance;
  final AuthService _authService = AuthService.instance;

  // Core discipline data - now fetched from Supabase
  List<Map<String, dynamic>> disciplines = [];
  List<Map<String, dynamic>> instructorProfiles = [];
  bool isLoading = true;
  String? errorMessage;
  bool isPrincipalAdmin = false;

  // Selection and editing state
  Set<String> selectedDisciplines = {};
  bool isEditMode = false;
  String? editingDisciplineId;

  // Search and filter
  String searchQuery = '';
  List<String> activeFilters = [];

  // Realtime subscription for admin data changes
  StreamSubscription<RealtimeDataChangeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _loadDisciplines();
    _checkAdminStatus();
    _subscribeToRealtimeChanges();
  }

  void _subscribeToRealtimeChanges() {
    RealtimeNotificationService.instance.subscribeToAdminDataChanges();

    _realtimeSubscription = RealtimeNotificationService
        .instance.dataChangeStream
        .where((event) => event.type == RealtimeDataChangeType.disciplines)
        .listen((_) {
      if (mounted) {
        _loadDisciplines();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final adminStatus = await _authService.isPrincipalAdmin();
      if (mounted) {
        setState(() {
          isPrincipalAdmin = adminStatus;
        });
      }
    } catch (error) {
      print('Error checking admin status: $error');
    }
  }

  Future<void> _loadDisciplines() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final [disciplinesData, instructorsData] = await Future.wait([
        _disciplineService.getActiveDisciplines(),
        _disciplineService.getInstructorProfiles(),
      ]);

      setState(() {
        disciplines = disciplinesData;
        instructorProfiles = instructorsData;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'admin_discipline.title'.tr(),
          style: theme.appBarTheme.titleTextStyle,
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        actions: [
          if (selectedDisciplines.isNotEmpty)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear),
              tooltip: 'admin_discipline.deselect_all'.tr(),
            ),
          IconButton(
            onPressed: _loadDisciplines,
            icon: const Icon(Icons.refresh),
            tooltip: 'admin_discipline.tooltip_reload'.tr(),
          ),
          IconButton(
            onPressed: _showSettingsMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Header with active disciplines and search
                    DisciplineHeaderWidget(
                      disciplines: disciplines,
                      searchQuery: searchQuery,
                      activeFilters: activeFilters,
                      onSearchChanged: (query) =>
                          setState(() => searchQuery = query),
                      onFilterChanged: (filters) =>
                          setState(() => activeFilters = filters),
                      onDisciplineToggle: _toggleDisciplineActive,
                    ),

                    // Bulk operations toolbar (shown when items selected)
                    if (selectedDisciplines.isNotEmpty)
                      BulkOperationsToolbarWidget(
                        selectedCount: selectedDisciplines.length,
                        onBulkEdit: _showBulkEditDialog,
                        onBulkDelete: _showBulkDeleteDialog,
                        onBulkScheduleUpdate: _showBulkScheduleDialog,
                      ),

                    // Discipline cards list
                    Expanded(child: _buildDisciplineList()),
                  ],
                ),

      // Add new discipline FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDisciplineDialog,
        icon: const Icon(Icons.add),
        label: Text('admin_discipline.new_discipline'.tr()),
        backgroundColor: theme.floatingActionButtonTheme.backgroundColor,
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
            'admin_discipline.load_error'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'admin_discipline.unknown_error'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDisciplines,
            icon: const Icon(Icons.refresh),
            label: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplineList() {
    final filteredDisciplines = _filterDisciplines();

    if (filteredDisciplines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_martial_arts,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(77),
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'user_mgmt.no_discipline_search'
                      .tr(namedArgs: {'query': searchQuery})
                  : 'user_mgmt.no_active_disciplines'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              disciplines.isEmpty
                  ? 'admin_discipline.add_first_discipline_hint'.tr()
                  : 'admin_discipline.modify_search_hint'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDisciplines,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredDisciplines.length,
        itemBuilder: (context, index) {
          final discipline = filteredDisciplines[index];

          return DisciplineCardWidget(
            discipline: discipline,
            isSelected: selectedDisciplines.contains(discipline['id']),
            isEditMode: isEditMode,
            onTap: () => _handleDisciplineSelection(discipline['id']),
            onLongPress: () => _enterEditMode(discipline['id']),
            onEdit: () => _editDiscipline(discipline['id']),
            onEditSchedule: () => _editSchedule(discipline['id']),
            onAddNote: () => _addNote(discipline['id']),
            onToggleActive: () => _toggleDisciplineActive(discipline['id']),
            onDelete: () => _deleteDiscipline(discipline['id']),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filterDisciplines() {
    var filtered = disciplines.where((discipline) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!discipline['name'].toLowerCase().contains(query) &&
            !discipline['instructors'].any(
              (instructor) => instructor.toLowerCase().contains(query),
            ) &&
            !discipline['locations'].any(
              (location) => location.toLowerCase().contains(query),
            )) {
          return false;
        }
      }

      // Active filter
      if (activeFilters.contains('active') && !discipline['isActive']) {
        return false;
      }
      if (activeFilters.contains('inactive') && discipline['isActive']) {
        return false;
      }

      return true;
    }).toList();

    return filtered;
  }

  void _handleDisciplineSelection(String disciplineId) {
    if (isEditMode) {
      setState(() {
        if (selectedDisciplines.contains(disciplineId)) {
          selectedDisciplines.remove(disciplineId);
        } else {
          selectedDisciplines.add(disciplineId);
        }
      });
    } else {
      _viewDisciplineDetails(disciplineId);
    }
  }

  void _enterEditMode(String? disciplineId) {
    setState(() {
      isEditMode = true;
      if (disciplineId != null) {
        selectedDisciplines.add(disciplineId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      selectedDisciplines.clear();
      isEditMode = false;
    });
  }

  void _toggleDisciplineActive(String disciplineId) {
    // For now, just show a message as this would require complex database operations
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('admin_discipline.toggle_development'.tr()),
        action: SnackBarAction(
          label: 'common.ok'.tr(),
          onPressed: () {},
        ),
      ),
    );
  }

  void _viewDisciplineDetails(String disciplineId) {
    final discipline = disciplines.firstWhere((d) => d['id'] == disciplineId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DisciplineEditorWidget(
        discipline: discipline,
        instructorProfiles: instructorProfiles,
        onSave: (updatedDiscipline) {
          Navigator.pop(context);
          _loadDisciplines(); // Reload data from Supabase
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _editDiscipline(String disciplineId) {
    _viewDisciplineDetails(disciplineId);
  }

  void _editSchedule(String disciplineId) {
    // Navigate to seasonal schedule creation with discipline filter
    Navigator.pushNamed(
      context,
      '/seasonal-schedule-creation',
      arguments: {'disciplineFilter': disciplineId},
    );
  }

  void _addNote(String disciplineId) {
    _showQuickNoteDialog(disciplineId);
  }

  void _deleteDiscipline(String disciplineId) async {
    final discipline = disciplines.firstWhere((d) => d['id'] == disciplineId);

    // Check if user is principal admin
    if (isPrincipalAdmin) {
      // Allow principal admin to delete disciplines directly
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('admin_discipline.delete_confirm_title'.tr()),
          content: Text(
            'admin_discipline.delete_confirm_principal'.tr(
              namedArgs: {'name': discipline['name'].toString()},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _performDisciplineDeletion(
                  disciplineId,
                  discipline['name'],
                );
              },
              child: Text('common.delete'.tr()),
            ),
          ],
        ),
      );
    } else {
      // Show restriction dialog for non-principal admins
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('admin_discipline.attention_title'.tr()),
          content: Text(
            'admin_discipline.delete_restriction'.tr(
              namedArgs: {'name': discipline['name'].toString()},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.understood'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/instructor-management');
              },
              child: Text('admin_discipline.manage_instructors'.tr()),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _performDisciplineDeletion(
    String disciplineId,
    String disciplineName,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('admin_discipline.deleting'.tr()),
            ],
          ),
        ),
      );

      // Delete the discipline
      final success = await _disciplineService.deleteDiscipline(disciplineId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'admin_discipline.deleted_success'.tr(
                namedArgs: {'name': disciplineName},
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: 'common.ok'.tr(),
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Reload disciplines
        await _loadDisciplines();
      } else {
        throw Exception('admin_discipline.delete_failed'.tr());
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
            'admin_discipline.delete_error'.tr(
              namedArgs: {'detail': error.toString()},
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'common.ok'.tr(),
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _showAddDisciplineDialog() {
    final TextEditingController newDisciplineController =
        TextEditingController();
    bool isSaving = false;
    String selectedColorHex = '#FF5722'; // Default: vibrant orange-red

    // Available colors for discipline selection
    final List<Map<String, dynamic>> availableColors = [
      {
        'hex': '#FF5722',
        'color': const Color(0xFFFF5722),
        'label': 'Arancione'
      },
      {'hex': '#2196F3', 'color': const Color(0xFF2196F3), 'label': 'Blu'},
      {'hex': '#4CAF50', 'color': const Color(0xFF4CAF50), 'label': 'Verde'},
      {'hex': '#9C27B0', 'color': const Color(0xFF9C27B0), 'label': 'Viola'},
      {'hex': '#F44336', 'color': const Color(0xFFF44336), 'label': 'Rosso'},
      {'hex': '#FFC107', 'color': const Color(0xFFFFC107), 'label': 'Giallo'},
      {'hex': '#00BCD4', 'color': const Color(0xFF00BCD4), 'label': 'Ciano'},
      {'hex': '#FF9800', 'color': const Color(0xFFFF9800), 'label': 'Ambra'},
      {'hex': '#E91E63', 'color': const Color(0xFFE91E63), 'label': 'Rosa'},
      {'hex': '#009688', 'color': const Color(0xFF009688), 'label': 'Teal'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('admin_discipline.manage_disciplines_dialog'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Existing disciplines list with delete options
                if (disciplines.isNotEmpty) ...[
                  Text(
                    'admin_discipline.existing_disciplines'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: disciplines.length,
                      itemBuilder: (context, index) {
                        final discipline = disciplines[index];
                        final disciplineColor = discipline['color'] as Color? ??
                            const Color(0xFF757575);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: disciplineColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            title: Text(discipline['name']),
                            subtitle: Text(
                              'admin_discipline.instructors_lessons_count'.tr(
                                namedArgs: {
                                  'instructors': discipline['instructors']
                                      .length
                                      .toString(),
                                  'classes': (discipline['totalClasses'] ?? 0)
                                      .toString(),
                                },
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _confirmDisciplineDelete(
                                  context,
                                  discipline['id'],
                                  discipline['name'],
                                  () {
                                    Navigator.pop(context);
                                    _loadDisciplines();
                                    _showAddDisciplineDialog();
                                  },
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],

                // Add new discipline section
                const Text(
                  'Aggiungi nuova disciplina:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newDisciplineController,
                  decoration: InputDecoration(
                    hintText: 'admin_discipline.hint_name'.tr(),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sports_martial_arts),
                  ),
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 16),
                // Color selection
                const Text(
                  'Colore identificativo:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableColors.map((colorOption) {
                    final isSelected = selectedColorHex == colorOption['hex'];
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedColorHex = colorOption['hex'] as String;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorOption['color'] as Color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white,
                                  width: 3,
                                )
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: (colorOption['color'] as Color)
                                        .withAlpha(128),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Preview of how the discipline will look
                if (newDisciplineController.text.trim().isNotEmpty) ...[
                  const Text(
                    'Anteprima:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            Theme.of(context).colorScheme.outline.withAlpha(51),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: availableColors.firstWhere(
                              (c) => c['hex'] == selectedColorHex,
                              orElse: () => availableColors.first,
                            )['color'] as Color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                newDisciplineController.text
                                    .trim()
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '0 ore/settimana • 0 studenti',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withAlpha(153),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Attiva',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text('common.close'.tr()),
            ),
            ElevatedButton(
              onPressed: (newDisciplineController.text.trim().isEmpty ||
                      isSaving)
                  ? null
                  : () async {
                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        final disciplineName =
                            newDisciplineController.text.trim();

                        // Create the new discipline with selected color
                        final success = await _disciplineService
                            .createNewDiscipline(disciplineName,
                                colorHex: selectedColorHex);

                        if (success) {
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Disciplina "$disciplineName" creata con successo',
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          );

                          // Reload disciplines
                          await _loadDisciplines();
                        } else {
                          throw Exception(
                              'admin_discipline.delete_failed'.tr());
                        }
                      } catch (error) {
                        setDialogState(() {
                          isSaving = false;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('admin_discipline.delete_error_short'
                                .tr(namedArgs: {'detail': error.toString()})),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDisciplineDelete(
    BuildContext context,
    String disciplineId,
    String disciplineName,
    VoidCallback onDeleted,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('admin_discipline.delete_confirm_title'.tr()),
        content: Text(
          'admin_discipline.delete_confirm_simple'.tr(
            namedArgs: {'name': disciplineName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('admin_discipline.deleting'.tr()),
                    ],
                  ),
                ),
              );

              try {
                final success = await _disciplineService.deleteDiscipline(
                  disciplineId,
                );

                if (context.mounted) Navigator.pop(context); // Close loading

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('admin_discipline.deleted_success_short'
                          .tr(namedArgs: {'name': disciplineName})),
                      backgroundColor: Colors.green,
                    ),
                  );
                  onDeleted();
                } else {
                  throw Exception('admin_discipline.delete_failed'.tr());
                }
              } catch (error) {
                if (context.mounted) Navigator.pop(context); // Close loading

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('admin_discipline.delete_error_short'
                        .tr(namedArgs: {'detail': error.toString()})),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _showQuickNoteDialog(String disciplineId) {
    final discipline = disciplines.firstWhere((d) => d['id'] == disciplineId);
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('user_mgmt.add_note_title'
            .tr(namedArgs: {'name': discipline['name']})),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
                'Nota: Utilizzare la gestione palinsesti per modificare orari e dettagli',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/seasonal-schedule-creation',
                arguments: {'disciplineFilter': disciplineId},
              );
            },
            child: Text('admin_discipline.go_to_schedules'.tr()),
          ),
        ],
      ),
    );
  }

  void _showBulkEditDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Le discipline vengono gestite tramite istruttori e palinsesti',
        ),
        action: SnackBarAction(
            label: 'admin_discipline.manage'.tr(), onPressed: () {}),
      ),
    );
  }

  void _showBulkDeleteDialog() {
    if (isPrincipalAdmin) {
      // Allow bulk deletion for principal admin
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('admin_discipline.bulk_delete_title'.tr()),
          content: Text(
            'Sei sicuro di voler eliminare ${selectedDisciplines.length} discipline?\n\n'
            'ATTENZIONE: Questa operazione non può essere annullata e rimuoverà:\n'
            '• Le discipline da tutti gli istruttori\n'
            '• Tutti i palinsesti associati\n\n'
            'Come amministratore principale, hai i privilegi per questa operazione.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _performBulkDeletion();
              },
              child: Text('admin_discipline.delete_all'.tr()),
            ),
          ],
        ),
      );
    } else {
      // Show restriction dialog for non-principal admins
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('admin_discipline.title'.tr()),
          content: Text('admin_discipline.bulk_delete_restricted'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.understood'.tr()),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _performBulkDeletion() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('admin_discipline.bulk_deleting'
                  .tr(namedArgs: {'count': '${selectedDisciplines.length}'})),
            ],
          ),
        ),
      );

      // Delete selected disciplines
      int successCount = 0;
      int failureCount = 0;

      for (String disciplineId in selectedDisciplines) {
        try {
          final success = await _disciplineService.deleteDiscipline(
            disciplineId,
          );
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
        } catch (error) {
          failureCount++;
          print('Error deleting discipline $disciplineId: $error');
        }
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show results
      String message;
      Color backgroundColor;

      if (failureCount == 0) {
        message = 'admin_discipline.bulk_success'
            .tr(namedArgs: {'count': '$successCount'});
        backgroundColor = Theme.of(context).colorScheme.primary;
      } else if (successCount == 0) {
        message = 'admin_discipline.bulk_none_deleted'.tr();
        backgroundColor = Theme.of(context).colorScheme.error;
      } else {
        message = 'admin_discipline.bulk_partial'.tr(namedArgs: {
          'success': '$successCount',
          'failure': '$failureCount'
        });
        backgroundColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          action: SnackBarAction(
            label: 'common.ok'.tr(),
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );

      // Clear selection and reload
      setState(() {
        selectedDisciplines.clear();
        isEditMode = false;
      });

      await _loadDisciplines();
    } catch (error) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'admin_discipline.delete_error'.tr(
              namedArgs: {'detail': error.toString()},
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showBulkScheduleDialog() {
    Navigator.pushNamed(context, '/seasonal-schedule-creation');
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: Text('admin_discipline.manage_instructors'.tr()),
            subtitle: Text('admin_discipline.menu_manage_instructors_sub'.tr()),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/instructor-management');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text('admin_discipline.menu_seasonal'.tr()),
            subtitle: Text('admin_discipline.menu_seasonal_sub'.tr()),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/seasonal-schedule-creation');
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text('admin_discipline.menu_reload'.tr()),
            onTap: () {
              Navigator.pop(context);
              _loadDisciplines();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('admin_discipline.settings'.tr()),
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings
            },
          ),
        ],
      ),
    );
  }
}
