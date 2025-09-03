import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DisciplineHeaderWidget extends StatelessWidget {
  final List<Map<String, dynamic>> disciplines;
  final String searchQuery;
  final List<String> activeFilters;
  final Function(String) onSearchChanged;
  final Function(List<String>) onFilterChanged;
  final Function(String) onDisciplineToggle;

  const DisciplineHeaderWidget({
    super.key,
    required this.disciplines,
    required this.searchQuery,
    required this.activeFilters,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onDisciplineToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cerca discipline, istruttori, luoghi...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => onSearchChanged(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),

          // Active disciplines chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discipline Attive',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: disciplines.map((discipline) {
                    return _buildDisciplineChip(context, discipline);
                  }).toList(),
                ),
              ],
            ),
          ),

          // Filter chips
          if (activeFilters.isNotEmpty || _hasAvailableFilters())
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtri',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _buildFilterChips(context),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDisciplineChip(
      BuildContext context, Map<String, dynamic> discipline) {
    final theme = Theme.of(context);
    final isActive = discipline['isActive'] ?? true;

    return GestureDetector(
      onTap: () => onDisciplineToggle(discipline['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (discipline['color'] as Color?) ?? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? (discipline['color'] as Color?) ?? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: ((discipline['color'] as Color?) ??
                            theme.colorScheme.primary)
                        .withAlpha(77),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withAlpha(153),
                    width: 1,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              discipline['name'],
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: isActive
                  ? Colors.white.withAlpha(204)
                  : theme.colorScheme.onSurface.withAlpha(153),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasAvailableFilters() {
    return disciplines.any((d) => d['isActive'] == true) &&
        disciplines.any((d) => d['isActive'] == false);
  }

  List<Widget> _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    // Active/Inactive filters
    if (_hasAvailableFilters()) {
      chips.add(_buildFilterChip(
        context,
        'Attive',
        'active',
        activeFilters.contains('active'),
        Icons.check_circle,
        theme.colorScheme.primary,
      ));

      chips.add(_buildFilterChip(
        context,
        'Disattivate',
        'inactive',
        activeFilters.contains('inactive'),
        Icons.cancel,
        Colors.grey[600]!,
      ));
    }

    // Instructor filter
    final allInstructors = disciplines
        .expand((d) => d['instructors'] as List<String>)
        .toSet()
        .toList();

    if (allInstructors.length > 1) {
      chips.add(_buildInstructorFilterChip(context, allInstructors));
    }

    return chips;
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String filterId,
    bool isSelected,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        final newFilters = List<String>.from(activeFilters);
        if (selected) {
          newFilters.add(filterId);
        } else {
          newFilters.remove(filterId);
        }
        onFilterChanged(newFilters);
      },
      backgroundColor: theme.colorScheme.surface,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildInstructorFilterChip(
      BuildContext context, List<String> instructors) {
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      child: Chip(
        avatar: Icon(
          Icons.person,
          size: 16,
          color: theme.colorScheme.onSurface,
        ),
        label: Text(
          'Istruttore',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
      ),
      itemBuilder: (context) => instructors.map((instructor) {
        return PopupMenuItem<String>(
          value: instructor,
          child: Text(instructor),
        );
      }).toList(),
      onSelected: (instructor) {
        // Filter by instructor
        onSearchChanged(instructor);
      },
    );
  }
}
