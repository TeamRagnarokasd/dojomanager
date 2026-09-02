import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class InstructorListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> instructors;
  final Function(Map<String, dynamic>) onInstructorSelected;
  final VoidCallback onRefresh;

  const InstructorListWidget({
    super.key,
    required this.instructors,
    required this.onInstructorSelected,
    required this.onRefresh,
  });

  @override
  State<InstructorListWidget> createState() => _InstructorListWidgetState();
}

class _InstructorListWidgetState extends State<InstructorListWidget> {
  String _searchQuery = '';
  String _selectedDiscipline = 'Tutte';

  List<String> get _disciplines {
    final disciplines = <String>{'Tutte'};
    for (final instructor in widget.instructors) {
      final instructorDisciplines = instructor['disciplines'] as List<dynamic>?;
      if (instructorDisciplines != null) {
        disciplines.addAll(instructorDisciplines.cast<String>());
      }
    }
    return disciplines.toList();
  }

  List<Map<String, dynamic>> get _filteredInstructors {
    return widget.instructors.where((instructor) {
      final name = instructor['full_name']?.toString().toLowerCase() ?? '';
      final matchesSearch = name.contains(_searchQuery.toLowerCase());

      if (_selectedDiscipline == 'Tutte') return matchesSearch;

      final disciplines = instructor['disciplines'] as List<dynamic>?;
      final matchesDiscipline =
          disciplines?.contains(_selectedDiscipline) ?? false;

      return matchesSearch && matchesDiscipline;
    }).toList();
  }

  void _handleInstructorTap(Map<String, dynamic> instructor) {
    // Navigate to the profile editor for both complete and incomplete profiles
    widget.onInstructorSelected(instructor);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: const Color(0xFFFF0000),
      child: CustomScrollView(
        slivers: [
          // Search and Filter Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: TextField(
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Cerca per nome...',
                        hintStyle: GoogleFonts.inter(color: Colors.grey),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Discipline Filter
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDiscipline,
                        style: GoogleFonts.inter(color: Colors.white),
                        dropdownColor: const Color(0xFF2A2A2A),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey,
                        ),
                        items: _disciplines.map((discipline) {
                          return DropdownMenuItem(
                            value: discipline,
                            child: Text(
                              discipline == 'Tutte'
                                  ? 'Tutte le discipline'
                                  : discipline.toUpperCase(),
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDiscipline = value ?? 'Tutte';
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Instructors List
          _filteredInstructors.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun istruttore trovato',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Prova a modificare i filtri di ricerca',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final instructor = _filteredInstructors[index];
                        return _buildInstructorCard(instructor);
                      },
                      childCount: _filteredInstructors.length,
                    ),
                  ),
                ),
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildInstructorCard(Map<String, dynamic> instructor) {
    final disciplines = instructor['disciplines'] as List<dynamic>?;
    final primaryDiscipline =
        instructor['primary_discipline']?.toString() ?? '';
    final isActive = instructor['is_active'] ?? true;
    final isIncomplete = instructor['profile_incomplete'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isIncomplete
              ? Colors.orange.withAlpha(128)
              : isActive
                  ? const Color(0xFF333333)
                  : Colors.grey[800]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleInstructorTap(instructor),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isIncomplete
                          ? Colors.orange
                          : isActive
                              ? const Color(0xFFFF0000)
                              : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: instructor['profile_image_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: instructor['profile_image_url'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFF3A3A3A),
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 30,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: const Color(0xFF3A3A3A),
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 30,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF3A3A3A),
                            child: const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 30,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Instructor Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              instructor['full_name'] ?? 'Nome non disponibile',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isActive ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                          if (isIncomplete)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Text(
                                'Profilo da completare',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (!isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Text(
                                'Inattivo',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isIncomplete)
                        Text(
                          'Tocca per completare il profilo istruttore',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.orange.withAlpha(200),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else ...[
                        Text(
                          'Disciplina principale: ${primaryDiscipline.toUpperCase()}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFFF0000),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (disciplines != null && disciplines.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: disciplines.take(3).map((discipline) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3A3A3A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    discipline.toString().toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.grey[300],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (instructor['years_experience'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${instructor['years_experience']} anni di esperienza',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: isIncomplete ? Colors.orange : Colors.grey[600],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
