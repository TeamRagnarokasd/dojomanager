import 'package:flutter/material.dart';
import '../../services/discipline_service.dart';
import '../../services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDisciplines();
    _checkAdminStatus();
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
          'Gestione Discipline',
          style: theme.appBarTheme.titleTextStyle,
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation,
        actions: [
          if (selectedDisciplines.isNotEmpty)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear),
              tooltip: 'Deseleziona tutto',
            ),
          IconButton(
            onPressed: _loadDisciplines,
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica',
          ),
          IconButton(
            onPressed: _showSettingsMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body:
          isLoading
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
                    onSearchChanged:
                        (query) => setState(() => searchQuery = query),
                    onFilterChanged:
                        (filters) => setState(() => activeFilters = filters),
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
        label: const Text('Nuova Disciplina'),
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
            'Errore nel caricamento delle discipline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Errore sconosciuto',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDisciplines,
            icon: const Icon(Icons.refresh),
            label: const Text('Riprova'),
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
                  ? 'Nessuna disciplina trovata per "$searchQuery"'
                  : 'Nessuna disciplina attiva',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              disciplines.isEmpty
                  ? 'Le discipline appariranno dopo aver creato un palinsesto stagionale\no dopo aver aggiunto istruttori con specializzazioni'
                  : 'Modifica la ricerca o i filtri per vedere le discipline',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (disciplines.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to seasonal schedule management
                  Navigator.pushNamed(context, '/seasonal-schedule-management');
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Crea Palinsesto Stagionale'),
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
    var filtered =
        disciplines.where((discipline) {
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
        content: const Text(
          'Attivazione/disattivazione discipline in via di sviluppo',
        ),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
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
      builder:
          (context) => DisciplineEditorWidget(
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
    // Navigate to seasonal schedule management with discipline filter
    Navigator.pushNamed(
      context,
      '/seasonal-schedule-management',
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
        builder:
            (context) => AlertDialog(
              title: const Text('Conferma Eliminazione'),
              content: Text(
                'Sei sicuro di voler eliminare la disciplina ${discipline['name']}?\n\n'
                'ATTENZIONE: Questa operazione:\n'
                '• Rimuoverà la disciplina da tutti gli istruttori\n'
                '• Cancellerà tutti i palinsesti associati\n'
                '• Non può essere annullata\n\n'
                'Come amministratore principale, hai i privilegi per questa operazione.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
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
                  child: const Text('Elimina'),
                ),
              ],
            ),
      );
    } else {
      // Show restriction dialog for non-principal admins
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Attenzione'),
              content: Text(
                'Non è possibile eliminare direttamente ${discipline['name']}. '
                'Le discipline vengono gestite attraverso:\n\n'
                '• Profili istruttore e specializzazioni\n'
                '• Palinsesti stagionali e orari\n\n'
                'Modifica questi elementi per gestire le discipline.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Capito'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/instructor-management');
                  },
                  child: const Text('Gestisci Istruttori'),
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
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Eliminando disciplina...'),
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
              'Disciplina "$disciplineName" eliminata con successo',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Reload disciplines
        await _loadDisciplines();
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
          content: Text('Errore durante l\'eliminazione: ${error.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _showAddDisciplineDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Aggiungi Disciplina'),
            content: const Text(
              'Per aggiungere una nuova disciplina:\n\n'
              '• Aggiungi un istruttore con quella disciplina, oppure\n'
              '• Crea un palinsesto stagionale con lezioni della disciplina\n\n'
              'Le discipline appariranno automaticamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/instructor-management');
                },
                child: const Text('Gestisci Istruttori'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/seasonal-schedule-management');
                },
                child: const Text('Palinsesti'),
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
      builder:
          (context) => AlertDialog(
            title: Text('Aggiungi Nota - ${discipline['name']}'),
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
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/seasonal-schedule-management',
                    arguments: {'disciplineFilter': disciplineId},
                  );
                },
                child: const Text('Vai a Palinsesti'),
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
        action: SnackBarAction(label: 'Gestisci', onPressed: () {}),
      ),
    );
  }

  void _showBulkDeleteDialog() {
    if (isPrincipalAdmin) {
      // Allow bulk deletion for principal admin
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Eliminazione Multipla'),
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
                  child: const Text('Annulla'),
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
                  child: const Text('Elimina Tutto'),
                ),
              ],
            ),
      );
    } else {
      // Show restriction dialog for non-principal admins
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Gestione Discipline'),
              content: const Text(
                'Le discipline non possono essere eliminate direttamente. '
                'Vengono gestite automaticamente attraverso:\n\n'
                '• Profili istruttore\n'
                '• Palinsesti stagionali\n'
                '• Orari delle lezioni\n\n'
                'Modifica questi elementi per gestire le discipline.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Capito'),
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
        builder:
            (context) => AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Text(
                    'Eliminando ${selectedDisciplines.length} discipline...',
                  ),
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
        message = '$successCount discipline eliminate con successo';
        backgroundColor = Theme.of(context).colorScheme.primary;
      } else if (successCount == 0) {
        message = 'Errore: nessuna disciplina eliminata';
        backgroundColor = Theme.of(context).colorScheme.error;
      } else {
        message = '$successCount eliminate, $failureCount errori';
        backgroundColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          action: SnackBarAction(
            label: 'OK',
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
          content: Text('Errore durante l\'eliminazione: ${error.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showBulkScheduleDialog() {
    Navigator.pushNamed(context, '/seasonal-schedule-management');
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Gestisci Istruttori'),
                subtitle: const Text('Aggiungi specializzazioni'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/instructor-management');
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Palinsesti Stagionali'),
                subtitle: const Text('Crea orari per discipline'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/seasonal-schedule-management');
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Ricarica Dati'),
                onTap: () {
                  Navigator.pop(context);
                  _loadDisciplines();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Impostazioni'),
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
