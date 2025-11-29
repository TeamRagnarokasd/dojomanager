import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../services/instructor_service.dart';
import './widgets/discipline_filter_widget.dart';
import './widgets/instructor_card_widget.dart';
import './widgets/instructor_profile_widget.dart';
import './widgets/instructor_search_widget.dart';

class InstructorDirectory extends StatefulWidget {
  const InstructorDirectory({super.key});

  @override
  State<InstructorDirectory> createState() => _InstructorDirectoryState();
}

class _InstructorDirectoryState extends State<InstructorDirectory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // UI state
  String searchQuery = '';
  List<String> selectedDisciplines = [];
  bool showActiveOnly = true;
  bool _isLoading = true;
  bool _isAdmin = false;
  List<InstructorProfile> _instructors = [];
  List<InstructorProfile> _filteredInstructors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      setState(() => _isLoading = true);

      // Check if user is admin
      final isAdmin = await InstructorService.isCurrentUserAdmin();

      // Load instructors
      final instructors =
          await InstructorService.getInstructors(activeOnly: showActiveOnly);

      setState(() {
        _isAdmin = isAdmin;
        _instructors = instructors;
        _filteredInstructors = instructors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento degli istruttori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredInstructors = _instructors.where((instructor) {
        // Search filter
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          if (!(instructor.fullName?.toLowerCase().contains(query) == true ||
              instructor.disciplines.any(
                  (discipline) => discipline.toLowerCase().contains(query)) ||
              instructor.specializations
                  .any((spec) => spec.toLowerCase().contains(query)))) {
            return false;
          }
        }

        // Discipline filter
        if (selectedDisciplines.isNotEmpty) {
          if (!selectedDisciplines.any(
              (discipline) => instructor.disciplines.contains(discipline))) {
            return false;
          }
        }

        // Active filter
        if (showActiveOnly && !instructor.isActive) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Team Ragnarok Instructors',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _isAdmin
            ? [
                PopupMenuButton<String>(
                  color: Colors.grey[800],
                  icon: CustomIconWidget(
                    iconName: 'more_vert',
                    color: Colors.white,
                    size: 24,
                  ),
                  onSelected: (value) => _handleAdminAction(value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'add_instructor',
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'person_add',
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 2.w),
                          Text('Aggiungi Istruttore',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'manage_disciplines',
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'sports_martial_arts',
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 2.w),
                          Text('Gestisci Discipline',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'refresh',
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 2.w),
                          Text('Aggiorna',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  icon: CustomIconWidget(
                    iconName: 'refresh',
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => _initializeData(),
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lista Istruttori'),
            Tab(text: 'Per Disciplina'),
          ],
          indicatorColor: const Color(0xFFFF0000),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: AssetImage(AppConstants.teamLogo),
            fit: BoxFit.contain,
            alignment: Alignment.center,
            opacity: 0.1,
          ),
        ),
        child: _isLoading
            ? _buildLoadingState()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildInstructorsList(),
                  _buildDisciplineView(),
                ],
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFF0000)),
          ),
          SizedBox(height: 2.h),
          Text(
            'Caricamento istruttori...',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorsList() {
    return Column(
      children: [
        // Search and filters
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(
              bottom: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              InstructorSearchWidget(
                searchQuery: searchQuery,
                onSearchChanged: (query) {
                  setState(() => searchQuery = query);
                  _applyFilters();
                },
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: DisciplineFilterWidget(
                      disciplines: AppConstants.disciplines,
                      selectedDisciplines: selectedDisciplines,
                      onSelectionChanged: (disciplines) {
                        setState(() => selectedDisciplines = disciplines);
                        _applyFilters();
                      },
                    ),
                  ),
                  SizedBox(width: 3.w),
                  GestureDetector(
                    onTap: () {
                      setState(() => showActiveOnly = !showActiveOnly);
                      _initializeData(); // Reload data with new filter
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.5.w),
                      decoration: BoxDecoration(
                        color: showActiveOnly
                            ? const Color(0xFFFF0000)
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(25),
                        border: showActiveOnly
                            ? null
                            : Border.all(color: Colors.grey[700]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showActiveOnly) ...[
                            CustomIconWidget(
                              iconName: 'check',
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 1.w),
                          ],
                          Text(
                            'Solo Attivi',
                            style: AppTheme.lightTheme.textTheme.bodyMedium
                                ?.copyWith(
                              color: showActiveOnly
                                  ? Colors.white
                                  : Colors.grey[300],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Instructors grid
        Expanded(
          child: _filteredInstructors.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _initializeData,
                  child: GridView.builder(
                    padding: EdgeInsets.all(4.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 3.w,
                      mainAxisSpacing: 3.w,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _filteredInstructors.length,
                    itemBuilder: (context, index) {
                      final instructor = _filteredInstructors[index];
                      return InstructorCardWidget(
                        instructor: instructor,
                        onTap: () => _showInstructorProfile(instructor),
                        canEdit: _isAdmin,
                        onEdit: _isAdmin
                            ? () => _editInstructor(instructor.id)
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDisciplineView() {
    final disciplineGroups = <String, List<InstructorProfile>>{};

    // Group instructors by primary discipline
    for (final instructor in _filteredInstructors) {
      final discipline = instructor.primaryDiscipline;
      disciplineGroups.putIfAbsent(discipline, () => []).add(instructor);
    }

    return RefreshIndicator(
      onRefresh: _initializeData,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: AppConstants.disciplines.length,
        itemBuilder: (context, index) {
          final discipline = AppConstants.disciplines[index];
          final disciplineInstructors =
              disciplineGroups[discipline.toLowerCase()] ?? [];

          return _buildDisciplineSection(discipline, disciplineInstructors);
        },
      ),
    );
  }

  Widget _buildDisciplineSection(
      String discipline, List<InstructorProfile> disciplineInstructors) {
    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Discipline header
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF0000).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'sports_martial_arts',
                  color: const Color(0xFFFF0000),
                  size: 24,
                ),
                SizedBox(width: 3.w),
                Text(
                  discipline.toUpperCase(),
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${disciplineInstructors.length} istruttori',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),

          // Instructors for this discipline
          if (disciplineInstructors.isEmpty)
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Center(
                child: Text(
                  'Nessun istruttore disponibile per $discipline',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 3.w,
                mainAxisSpacing: 3.w,
                childAspectRatio: 0.75,
              ),
              itemCount: disciplineInstructors.length,
              itemBuilder: (context, index) {
                final instructor = disciplineInstructors[index];
                return InstructorCardWidget(
                  instructor: instructor,
                  onTap: () => _showInstructorProfile(instructor),
                  canEdit: _isAdmin,
                  onEdit:
                      _isAdmin ? () => _editInstructor(instructor.id) : null,
                );
              },
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
            Icons.person_search,
            size: 80,
            color: Colors.grey[600],
          ),
          SizedBox(height: 2.h),
          Text(
            'Nessun istruttore trovato',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            searchQuery.isNotEmpty
                ? 'Prova a modificare la ricerca'
                : 'Nessun istruttore disponibile al momento',
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
          ),
          if (_isAdmin) ...[
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: () => _handleAdminAction('add_instructor'),
              icon: CustomIconWidget(
                iconName: 'person_add',
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                'Aggiungi Primo Istruttore',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInstructorProfile(InstructorProfile instructor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InstructorProfileWidget(
        instructor: instructor,
        canEdit: _isAdmin,
        onEdit: _isAdmin
            ? () {
                Navigator.pop(context);
                _editInstructor(instructor.id);
              }
            : null,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _editInstructor(String instructorId) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Modifica istruttore - Funzionalità in arrivo'),
        backgroundColor: AppTheme.primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _handleAdminAction(String action) {
    switch (action) {
      case 'add_instructor':
        _addInstructor();
        break;
      case 'manage_disciplines':
        _manageDisciplines();
        break;
      case 'refresh':
        _initializeData();
        break;
    }
  }

  void _addInstructor() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aggiunta istruttore - Funzionalità in arrivo'),
        backgroundColor: AppTheme.successLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _manageDisciplines() {
    Navigator.pushNamed(context, '/admin-discipline-management');
  }
}
