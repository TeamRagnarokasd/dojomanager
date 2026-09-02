import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../services/instructor_service.dart';
import './widgets/instructor_card_widget.dart';
import './widgets/instructor_profile_widget.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
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
      final instructors = await InstructorService.getInstructors(
        activeOnly: showActiveOnly,
      );

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
            content: Text(
              'instructor_directory.load_error'.tr(
                namedArgs: {'detail': e.toString()},
              ),
            ),
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
                (discipline) => discipline.toLowerCase().contains(query),
              ) ||
              instructor.specializations.any(
                (spec) => spec.toLowerCase().contains(query),
              ))) {
            return false;
          }
        }

        // Discipline filter
        if (selectedDisciplines.isNotEmpty) {
          if (!selectedDisciplines.any(
            (discipline) => instructor.disciplines.contains(discipline),
          )) {
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
          'instructor_directory.team_title'.tr(),
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
                          Text(
                            'instructor_directory.add_instructor'.tr(),
                            style: const TextStyle(color: Colors.white),
                          ),
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
                          Text(
                            'instructor_directory.manage_disciplines'.tr(),
                            style: const TextStyle(color: Colors.white),
                          ),
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
                          Text(
                            'instructor_directory.refresh'.tr(),
                            style: const TextStyle(color: Colors.white),
                          ),
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
          tabs: [
            Tab(text: 'instructor_directory.tab_list'.tr()),
            Tab(text: 'instructor_directory.tab_by_discipline'.tr()),
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
                children: [_buildInstructorsList(), _buildDisciplineView()],
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
            'instructor_directory.loading'.tr(),
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
                      childAspectRatio: 0.65,
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

    // Group instructors by ALL their disciplines (not just primary)
    for (final instructor in _filteredInstructors) {
      for (final discipline in instructor.disciplines) {
        final normalizedDiscipline = discipline.toLowerCase();
        disciplineGroups
            .putIfAbsent(normalizedDiscipline, () => [])
            .add(instructor);
      }
    }

    // Build the list of unique disciplines from loaded instructors (dynamic, no hardcoding)
    final allDisciplines = <String>{};
    for (final instructor in _instructors) {
      allDisciplines.addAll(instructor.disciplines);
    }
    final sortedDisciplines = allDisciplines.toList()..sort();

    if (sortedDisciplines.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _initializeData,
      child: ListView.builder(
        padding: EdgeInsets.all(4.w),
        itemCount: sortedDisciplines.length,
        itemBuilder: (context, index) {
          final discipline = sortedDisciplines[index];
          final disciplineInstructors =
              disciplineGroups[discipline.toLowerCase()] ?? [];

          return _buildDisciplineSection(discipline, disciplineInstructors);
        },
      ),
    );
  }

  Widget _buildDisciplineSection(
    String discipline,
    List<InstructorProfile> disciplineInstructors,
  ) {
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
                    'instructor_directory.instructors_count'.tr(
                      namedArgs: {
                        'count': disciplineInstructors.length.toString(),
                      },
                    ),
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
                  'instructor_directory.no_instructor_for'.tr(
                    namedArgs: {'discipline': discipline},
                  ),
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
                childAspectRatio: 0.65,
              ),
              itemCount: disciplineInstructors.length,
              itemBuilder: (context, index) {
                final instructor = disciplineInstructors[index];
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey[600]),
          SizedBox(height: 2.h),
          Text(
            'instructor_directory.empty_title'.tr(),
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            searchQuery.isNotEmpty
                ? 'instructor_directory.empty_search'.tr()
                : 'instructor_directory.empty_default'.tr(),
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
                'instructor_directory.add_first'.tr(),
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
        content: Text('instructor_directory.edit_coming_soon'.tr()),
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
        content: Text('instructor_directory.add_coming_soon'.tr()),
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
