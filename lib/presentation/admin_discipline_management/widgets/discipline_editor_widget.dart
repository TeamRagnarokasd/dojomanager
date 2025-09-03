import 'package:flutter/material.dart';

class DisciplineEditorWidget extends StatefulWidget {
  final Map<String, dynamic>? discipline;
  final Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;

  const DisciplineEditorWidget({
    super.key,
    this.discipline,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<DisciplineEditorWidget> createState() => _DisciplineEditorWidgetState();
}

class _DisciplineEditorWidgetState extends State<DisciplineEditorWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  // Form data
  bool _isActive = true;
  Color _selectedColor = const Color(0xFF2196F3);
  List<String> _instructors = [];
  List<String> _locations = [];
  Map<String, List<Map<String, dynamic>>> _schedule = {};

  // Available options
  final List<String> _availableInstructors = [
    'Marco Silva',
    'Elena Rossi',
    'Dmitri Volkov',
    'Ana Santos',
    'Igor Petrov',
    'Carlos Mendez',
    'Sofia Andersson',
  ];

  final List<String> _availableLocations = [
    'Palestra principale',
    'Sala BJJ secondo piano',
    'Gabbia MMA',
    'Tatami sambo',
    'Sala grappling',
  ];

  final List<Color> _availableColors = [
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFF5722), // Orange
    const Color(0xFF4CAF50), // Green
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFFFC107), // Amber
    const Color(0xFFE91E63), // Pink
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFF795548), // Brown
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.discipline != null) {
      final discipline = widget.discipline!;
      _nameController.text = discipline['name'] ?? '';
      _isActive = discipline['isActive'] ?? true;
      _selectedColor = discipline['color'] ?? _availableColors.first;
      _instructors = List<String>.from(discipline['instructors'] ?? []);
      _locations = List<String>.from(discipline['locations'] ?? []);
      _schedule = Map<String, List<Map<String, dynamic>>>.from(
        discipline['schedule']?.map<String, List<Map<String, dynamic>>>(
              (key, value) => MapEntry(
                key,
                List<Map<String, dynamic>>.from(
                  value.map((item) => Map<String, dynamic>.from(item)),
                ),
              ),
            ) ??
            {},
      );
    } else {
      // Initialize empty schedule for new discipline
      _schedule = {
        'Lunedì': [],
        'Martedì': [],
        'Mercoledì': [],
        'Giovedì': [],
        'Venerdì': [],
        'Sabato': [],
        'Domenica': [],
      };
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(77),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.discipline == null
                        ? 'Nuova Disciplina'
                        : 'Modifica Disciplina',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.info), text: 'Info Base'),
              Tab(icon: Icon(Icons.schedule), text: 'Orari'),
              Tab(icon: Icon(Icons.note), text: 'Note'),
            ],
            labelColor: _selectedColor,
            indicatorColor: _selectedColor,
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildScheduleTab(),
                _buildNotesTab(),
              ],
            ),
          ),

          // Save/Cancel buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(51),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveDiscipline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor,
                    ),
                    child: const Text('Salva'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nome Disciplina *',
              hintText: 'Es: BJJ, MMA, Sambo, Grappling',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          // Active toggle
          SwitchListTile(
            title: const Text('Disciplina Attiva'),
            subtitle: const Text('La disciplina è visibile e prenotabile'),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeColor: _selectedColor,
          ),

          const SizedBox(height: 20),

          // Color picker
          Text(
            'Colore Disciplina',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: _availableColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.onSurface, width: 3)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Instructors
          Text(
            'Istruttori',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInstructors.map((instructor) {
              final isSelected = _instructors.contains(instructor);
              return FilterChip(
                label: Text(instructor),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _instructors.add(instructor);
                    } else {
                      _instructors.remove(instructor);
                    }
                  });
                },
                selectedColor: _selectedColor.withAlpha(51),
                checkmarkColor: _selectedColor,
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Locations
          Text(
            'Luoghi di Allenamento',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLocations.map((location) {
              final isSelected = _locations.contains(location);
              return FilterChip(
                label: Text(location),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _locations.add(location);
                    } else {
                      _locations.remove(location);
                    }
                  });
                },
                selectedColor: _selectedColor.withAlpha(51),
                checkmarkColor: _selectedColor,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orari Settimanali',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configura gli orari per ogni giorno della settimana',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(153),
            ),
          ),
          const SizedBox(height: 16),
          ..._schedule.entries.map((entry) {
            final day = entry.key;
            final classes = entry.value;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(day),
                subtitle: Text('${classes.length} lezioni'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...classes.asMap().entries.map((classEntry) {
                          final index = classEntry.key;
                          final classInfo = classEntry.value;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            labelText: 'Orario',
                                            hintText: '20:30-21:30',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            classInfo['time'] = value;
                                          },
                                          controller: TextEditingController(
                                            text: classInfo['time'] ?? '',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        onPressed: () =>
                                            _removeClass(day, index),
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _instructors
                                            .contains(classInfo['instructor'])
                                        ? classInfo['instructor']
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Istruttore',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _instructors.map((instructor) {
                                      return DropdownMenuItem(
                                        value: instructor,
                                        child: Text(instructor),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        classInfo['instructor'] = value;
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: _locations
                                            .contains(classInfo['location'])
                                        ? classInfo['location']
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Luogo',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _locations.map((location) {
                                      return DropdownMenuItem(
                                        value: location,
                                        child: Text(location),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        classInfo['location'] = value;
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Nota (opzionale)',
                                      hintText:
                                          'Es: principianti, focus guard work',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      classInfo['note'] = value;
                                    },
                                    controller: TextEditingController(
                                      text: classInfo['note'] ?? '',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        // Add class button
                        OutlinedButton.icon(
                          onPressed: () => _addClass(day),
                          icon: const Icon(Icons.add),
                          label: const Text('Aggiungi Lezione'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _selectedColor,
                            side: BorderSide(color: _selectedColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Note Aggiuntive',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aggiungi informazioni extra sulla disciplina',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText:
                    'Es: Equipaggiamento necessario, prerequisiti, regole speciali...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addClass(String day) {
    setState(() {
      _schedule[day]!.add({
        'time': '',
        'instructor': _instructors.isNotEmpty ? _instructors.first : '',
        'location': _locations.isNotEmpty ? _locations.first : '',
        'note': '',
      });
    });
  }

  void _removeClass(String day, int index) {
    setState(() {
      _schedule[day]!.removeAt(index);
    });
  }

  void _saveDiscipline() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Il nome della disciplina è obbligatorio')),
      );
      return;
    }

    if (_instructors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un istruttore')),
      );
      return;
    }

    if (_locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un luogo')),
      );
      return;
    }

    final disciplineData = {
      'id': widget.discipline?['id'] ??
          _nameController.text.toLowerCase().replaceAll(' ', '_'),
      'name': _nameController.text.trim(),
      'isActive': _isActive,
      'color': _selectedColor,
      'instructors': _instructors,
      'locations': _locations,
      'schedule': _schedule,
      'notes': _noteController.text.trim(),
    };

    widget.onSave(disciplineData);
  }
}
