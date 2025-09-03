import 'package:flutter/material.dart';

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
  // Core discipline data
  List<Map<String, dynamic>> disciplines = [
    {
      'id': 'bjj',
      'name': 'BJJ',
      'isActive': true,
      'color': const Color(0xFF2196F3),
      'instructors': ['Marco Silva', 'Elena Rossi'],
      'locations': ['Sala BJJ secondo piano', 'Palestra principale'],
      'schedule': {
        'Lunedì': [
          {
            'time': '18:00-19:00',
            'instructor': 'Marco Silva',
            'location': 'Sala BJJ secondo piano',
            'note': 'Principianti'
          },
          {
            'time': '20:30-21:30',
            'instructor': 'Elena Rossi',
            'location': 'Sala BJJ secondo piano',
            'note': 'Avanzati - focus guard work'
          },
        ],
        'Mercoledì': [
          {
            'time': '19:00-20:30',
            'instructor': 'Marco Silva',
            'location': 'Palestra principale',
            'note': 'Gi training'
          },
        ],
        'Venerdì': [
          {
            'time': '20:00-21:30',
            'instructor': 'Elena Rossi',
            'location': 'Sala BJJ secondo piano',
            'note': 'No-Gi sparring'
          },
        ],
      },
    },
    {
      'id': 'mma',
      'name': 'MMA',
      'isActive': true,
      'color': const Color(0xFFFF5722),
      'instructors': ['Dmitri Volkov', 'Ana Santos'],
      'locations': ['Gabbia MMA', 'Palestra principale'],
      'schedule': {
        'Martedì': [
          {
            'time': '19:00-20:30',
            'instructor': 'Dmitri Volkov',
            'location': 'Gabbia MMA',
            'note': 'Striking fundamentals'
          },
        ],
        'Giovedì': [
          {
            'time': '18:30-20:00',
            'instructor': 'Ana Santos',
            'location': 'Palestra principale',
            'note': 'Grappling per MMA'
          },
          {
            'time': '20:30-22:00',
            'instructor': 'Dmitri Volkov',
            'location': 'Gabbia MMA',
            'note': 'Sparring avanzato'
          },
        ],
        'Sabato': [
          {
            'time': '10:00-11:30',
            'instructor': 'Ana Santos',
            'location': 'Gabbia MMA',
            'note': 'Conditioning e tecnica'
          },
        ],
      },
    },
    {
      'id': 'sambo',
      'name': 'SAMBO',
      'isActive': true,
      'color': const Color(0xFF4CAF50),
      'instructors': ['Igor Petrov'],
      'locations': ['Tatami sambo', 'Palestra principale'],
      'schedule': {
        'Lunedì': [
          {
            'time': '19:30-21:00',
            'instructor': 'Igor Petrov',
            'location': 'Tatami sambo',
            'note': 'Combat sambo - throws'
          },
        ],
        'Mercoledì': [
          {
            'time': '18:00-19:30',
            'instructor': 'Igor Petrov',
            'location': 'Palestra principale',
            'note': 'Sport sambo'
          },
        ],
      },
    },
    {
      'id': 'grappling',
      'name': 'Grappling',
      'isActive': true,
      'color': const Color(0xFF9C27B0),
      'instructors': ['Carlos Mendez', 'Sofia Andersson'],
      'locations': ['Sala grappling', 'Palestra principale'],
      'schedule': {
        'Martedì': [
          {
            'time': '20:30-22:00',
            'instructor': 'Carlos Mendez',
            'location': 'Sala grappling',
            'note': 'No-Gi submission wrestling'
          },
        ],
        'Giovedì': [
          {
            'time': '17:00-18:30',
            'instructor': 'Sofia Andersson',
            'location': 'Palestra principale',
            'note': 'Principianti - posizioni base'
          },
        ],
        'Domenica': [
          {
            'time': '10:30-12:00',
            'instructor': 'Carlos Mendez',
            'location': 'Sala grappling',
            'note': 'Open mat - sparring libero'
          },
        ],
      },
    },
  ];

  // Selection and editing state
  Set<String> selectedDisciplines = {};
  bool isEditMode = false;
  String? editingDisciplineId;

  // Search and filter
  String searchQuery = '';
  List<String> activeFilters = [];

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
            onPressed: _showSettingsMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with active disciplines and search
          DisciplineHeaderWidget(
            disciplines: disciplines,
            searchQuery: searchQuery,
            activeFilters: activeFilters,
            onSearchChanged: (query) => setState(() => searchQuery = query),
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
          Expanded(
            child: _buildDisciplineList(),
          ),
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
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tocca il pulsante + per aggiungere una nuova disciplina',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
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
    );
  }

  List<Map<String, dynamic>> _filterDisciplines() {
    var filtered = disciplines.where((discipline) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!discipline['name'].toLowerCase().contains(query) &&
            !discipline['instructors'].any(
                (instructor) => instructor.toLowerCase().contains(query)) &&
            !discipline['locations']
                .any((location) => location.toLowerCase().contains(query))) {
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
    setState(() {
      final index = disciplines.indexWhere((d) => d['id'] == disciplineId);
      if (index != -1) {
        disciplines[index]['isActive'] = !disciplines[index]['isActive'];
      }
    });

    final discipline = disciplines.firstWhere((d) => d['id'] == disciplineId);
    final action = discipline['isActive'] ? 'attivata' : 'disattivata';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${discipline['name']} $action'),
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () => _toggleDisciplineActive(disciplineId),
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
        onSave: (updatedDiscipline) {
          _updateDiscipline(disciplineId, updatedDiscipline);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _editDiscipline(String disciplineId) {
    _viewDisciplineDetails(disciplineId);
  }

  void _editSchedule(String disciplineId) {
    // Focus on schedule editing in the discipline editor
    _viewDisciplineDetails(disciplineId);
  }

  void _addNote(String disciplineId) {
    // Quick note addition dialog
    _showQuickNoteDialog(disciplineId);
  }

  void _deleteDiscipline(String disciplineId) {
    final discipline = disciplines.firstWhere((d) => d['id'] == disciplineId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Disciplina'),
        content: Text(
          'Sei sicuro di voler eliminare ${discipline['name']}? '
          'Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                disciplines.removeWhere((d) => d['id'] == disciplineId);
                selectedDisciplines.remove(disciplineId);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${discipline['name']} eliminata')),
              );
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showAddDisciplineDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DisciplineEditorWidget(
        discipline: null, // New discipline
        onSave: (newDiscipline) {
          _addDiscipline(newDiscipline);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _addDiscipline(Map<String, dynamic> discipline) {
    setState(() {
      disciplines.add(discipline);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${discipline['name']} aggiunta')),
    );
  }

  void _updateDiscipline(
      String disciplineId, Map<String, dynamic> updatedDiscipline) {
    setState(() {
      final index = disciplines.indexWhere((d) => d['id'] == disciplineId);
      if (index != -1) {
        disciplines[index] = updatedDiscipline;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updatedDiscipline['name']} aggiornata')),
    );
  }

  void _showQuickNoteDialog(String disciplineId) {
    final discipline = disciplines.firstWhere((d) => d['id'] == disciplineId);
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aggiungi Nota - ${discipline['name']}'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText:
                'Es: Lunedì 20:30-21:30 grappling - sala BJJ secondo piano',
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
              if (noteController.text.trim().isNotEmpty) {
                // Add note to discipline (simplified implementation)
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nota aggiunta')),
                );
              }
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  void _showBulkEditDialog() {
    // Implementation for bulk editing selected disciplines
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modifica multipla in sviluppo')),
    );
  }

  void _showBulkDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Discipline Selezionate'),
        content: Text(
          'Sei sicuro di voler eliminare ${selectedDisciplines.length} discipline? '
          'Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                disciplines
                    .removeWhere((d) => selectedDisciplines.contains(d['id']));
                selectedDisciplines.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Discipline eliminate')),
              );
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showBulkScheduleDialog() {
    // Implementation for bulk schedule updates
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aggiornamento orari multiplo in sviluppo')),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('Importa/Esporta'),
            onTap: () {
              Navigator.pop(context);
              // Implementation for import/export
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Discipline'),
            onTap: () {
              Navigator.pop(context);
              // Implementation for backup
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
