import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DisciplineCardWidget extends StatefulWidget {
  final Map<String, dynamic> discipline;
  final bool isSelected;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onEditSchedule;
  final VoidCallback onAddNote;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const DisciplineCardWidget({
    super.key,
    required this.discipline,
    required this.isSelected,
    required this.isEditMode,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onEditSchedule,
    required this.onAddNote,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  State<DisciplineCardWidget> createState() => _DisciplineCardWidgetState();
}

class _DisciplineCardWidgetState extends State<DisciplineCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.discipline['isActive'] ?? true;
    final disciplineColor =
        (widget.discipline['color'] as Color?) ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onTapDown: (_) => _animationController.forward(),
              onTapUp: (_) => _animationController.reverse(),
              onTapCancel: () => _animationController.reverse(),
              child: Dismissible(
                key: Key(widget.discipline['id']),
                direction: DismissDirection.horizontal,
                background: _buildSwipeBackground(context, true),
                secondaryBackground: _buildSwipeBackground(context, false),
                onDismissed: (direction) {
                  if (direction == DismissDirection.startToEnd) {
                    widget.onEditSchedule();
                  } else {
                    widget.onDelete();
                  }
                },
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Show confirmation for delete
                    return await _showDeleteConfirmation(context);
                  }
                  return false; // Don't actually dismiss for schedule edit
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: widget.isSelected
                        ? Border.all(color: disciplineColor, width: 2)
                        : Border.all(
                            color: theme.colorScheme.outline.withAlpha(51)),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isSelected
                            ? disciplineColor.withAlpha(51)
                            : theme.shadowColor.withAlpha(26),
                        blurRadius: widget.isSelected ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Main card content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with title, status and actions
                            Row(
                              children: [
                                // Discipline color indicator
                                Container(
                                  width: 4,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: disciplineColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Title and status
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            widget.discipline['name'],
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isActive
                                                  ? theme.colorScheme.onSurface
                                                  : theme.colorScheme.onSurface
                                                      .withAlpha(153),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? Colors.green.withAlpha(26)
                                                  : Colors.grey.withAlpha(26),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isActive
                                                  ? 'Attiva'
                                                  : 'Disattivata',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: isActive
                                                    ? Colors.green[700]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_getTotalWeeklyHours()} ore/settimana • ${_getActiveStudentsCount()} studenti',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withAlpha(153),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Selection checkbox (in edit mode)
                                if (widget.isEditMode)
                                  Checkbox(
                                    value: widget.isSelected,
                                    onChanged: (_) => widget.onTap(),
                                    activeColor: disciplineColor,
                                  )
                                else
                                  // Quick actions
                                  PopupMenuButton<String>(
                                    onSelected: _handleMenuAction,
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 12),
                                            Text('Modifica'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'schedule',
                                        child: Row(
                                          children: [
                                            Icon(Icons.schedule, size: 20),
                                            SizedBox(width: 12),
                                            Text('Modifica Orari'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'note',
                                        child: Row(
                                          children: [
                                            Icon(Icons.note_add, size: 20),
                                            SizedBox(width: 12),
                                            Text('Aggiungi Nota'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(
                                              isActive
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(isActive
                                                ? 'Disattiva'
                                                : 'Attiva'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                            SizedBox(width: 12),
                                            Text('Elimina',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Instructors and locations
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoChip(
                                    context,
                                    Icons.person,
                                    'Istruttori',
                                    (widget.discipline['instructors']
                                            as List<String>)
                                        .join(', '),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoChip(
                                    context,
                                    Icons.location_on,
                                    'Luoghi',
                                    (widget.discipline['locations']
                                            as List<String>)
                                        .join(', '),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Next class info
                            _buildNextClassInfo(context),

                            // Expand button
                            Center(
                              child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => _isExpanded = !_isExpanded),
                                icon: Icon(_isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more),
                                label: Text(_isExpanded
                                    ? 'Meno dettagli'
                                    : 'Mostra orari'),
                                style: TextButton.styleFrom(
                                  foregroundColor: disciplineColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Expanded schedule section
                      if (_isExpanded)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            ),
                          ),
                          child: _buildScheduleSection(context),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwipeBackground(BuildContext context, bool isLeft) {
    final theme = Theme.of(context);

    return Container(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      decoration: BoxDecoration(
        color: isLeft ? Colors.blue : Colors.red,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLeft ? Icons.schedule : Icons.delete,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            isLeft ? 'Modifica\nOrari' : 'Elimina',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNextClassInfo(BuildContext context) {
    final theme = Theme.of(context);
    final nextClass = _getNextClass();

    if (nextClass == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              'Nessuna lezione programmata',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (widget.discipline['color'] as Color).withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 16,
            color: widget.discipline['color'] as Color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prossima lezione: ${nextClass['day']} ${nextClass['time']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.discipline['color'] as Color,
                  ),
                ),
                if (nextClass['note']?.isNotEmpty == true)
                  Text(
                    nextClass['note'],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = widget.discipline['schedule'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: theme.colorScheme.outline.withAlpha(51)),
          const SizedBox(height: 12),
          Text(
            'Orari Settimanali',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...schedule.entries.map((entry) {
            final dayName = entry.key;
            final classes = entry.value as List<Map<String, dynamic>>;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: widget.discipline['color'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...classes.map((classInfo) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withAlpha(51),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color:
                                    theme.colorScheme.onSurface.withAlpha(153),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                classInfo['time'],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color:
                                    theme.colorScheme.onSurface.withAlpha(153),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                classInfo['instructor'],
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color:
                                    theme.colorScheme.onSurface.withAlpha(153),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                classInfo['location'],
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          if (classInfo['note']?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.note,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(153),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      classInfo['note'],
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(204),
                                      ),
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
          }),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        widget.onEdit();
        break;
      case 'schedule':
        widget.onEditSchedule();
        break;
      case 'note':
        widget.onAddNote();
        break;
      case 'toggle':
        widget.onToggleActive();
        break;
      case 'delete':
        widget.onDelete();
        break;
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Elimina Disciplina'),
            content: Text(
              'Sei sicuro di voler eliminare ${widget.discipline['name']}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _getTotalWeeklyHours() {
    final schedule = widget.discipline['schedule'] as Map<String, dynamic>;
    double totalHours = 0;

    schedule.values.forEach((dayClasses) {
      for (var classInfo in dayClasses as List<Map<String, dynamic>>) {
        final timeRange = classInfo['time'] as String;
        final duration = _calculateClassDuration(timeRange);
        totalHours += duration;
      }
    });

    return totalHours.toStringAsFixed(1);
  }

  double _calculateClassDuration(String timeRange) {
    // Simple duration calculation from "HH:MM-HH:MM" format
    final parts = timeRange.split('-');
    if (parts.length != 2) return 1.0;

    try {
      final startParts = parts[0].split(':');
      final endParts = parts[1].split(':');

      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      return (endMinutes - startMinutes) / 60.0;
    } catch (e) {
      return 1.0; // Default duration
    }
  }

  String _getActiveStudentsCount() {
    // Mock data - in real app would come from database
    return '${15 + (widget.discipline['name'].hashCode % 20)}';
  }

  Map<String, dynamic>? _getNextClass() {
    final schedule = widget.discipline['schedule'] as Map<String, dynamic>;
    final now = DateTime.now();
    final currentDay = _getCurrentDayName();

    // Find next class (simplified logic)
    final todayClasses = schedule[currentDay] as List<Map<String, dynamic>>?;

    if (todayClasses != null && todayClasses.isNotEmpty) {
      final nextClass = Map<String, dynamic>.from(todayClasses.first);
      nextClass['day'] = currentDay;
      return nextClass;
    }

    // Find next day with classes
    final dayOrder = [
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
      'Domenica'
    ];
    for (var day in dayOrder) {
      final dayClasses = schedule[day] as List<Map<String, dynamic>>?;
      if (dayClasses != null && dayClasses.isNotEmpty) {
        final nextClass = Map<String, dynamic>.from(dayClasses.first);
        nextClass['day'] = day;
        return nextClass;
      }
    }

    return null;
  }

  String _getCurrentDayName() {
    const days = [
      'Lunedì',
      'Martedì',
      'Mercoledì',
      'Giovedì',
      'Venerdì',
      'Sabato',
      'Domenica'
    ];
    final now = DateTime.now();
    return days[now.weekday - 1];
  }
}
