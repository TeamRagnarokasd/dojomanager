import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/instructor_management_service.dart';
import '../../widgets/custom_error_widget.dart';
import './widgets/add_instructor_widget.dart';
import './widgets/instructor_list_widget.dart';
import './widgets/instructor_profile_editor_widget.dart';

class InstructorManagementSystem extends StatefulWidget {
  const InstructorManagementSystem({super.key});

  @override
  State<InstructorManagementSystem> createState() =>
      _InstructorManagementSystemState();
}

class _InstructorManagementSystemState extends State<InstructorManagementSystem>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final InstructorManagementService _instructorService =
      InstructorManagementService();

  List<Map<String, dynamic>> _instructors = [];
  Map<String, dynamic>? _selectedInstructor;
  bool _isLoading = true;
  String? _error;
  int _totalInstructors = 0;
  int _activeInstructors = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInstructors();

    // Add tab listener to refresh data when switching tabs
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInstructors() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final instructors =
          await _instructorService.getAllInstructorsWithProfiles();

      setState(() {
        _instructors = instructors;
        _totalInstructors = instructors.length;
        _activeInstructors =
            instructors.where((i) => i['is_active'] == true).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onInstructorSelected(Map<String, dynamic> instructor) {
    setState(() {
      _selectedInstructor = instructor;
      _tabController.animateTo(1); // Switch to Modifica Profilo tab
    });
    HapticFeedback.mediumImpact();
  }

  void _onInstructorUpdated() {
    _loadInstructors();
    setState(() {
      _selectedInstructor = null;
    });
  }

  void _onInstructorAdded() {
    _loadInstructors();
    _tabController.animateTo(0); // Switch back to Lista Istruttori
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(
              context,
              AppRoutes.enhancedAdminDashboard,
            );
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestione Istruttori',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Team Ragnarok',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFFF0000),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Statistics Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      'Totale Istruttori',
                      _totalInstructors.toString(),
                      Icons.people,
                    ),
                    _buildStatCard(
                      'Attivi',
                      _activeInstructors.toString(),
                      Icons.check_circle,
                    ),
                    _buildStatCard('Discipline', '5', Icons.fitness_center),
                  ],
                ),
              ),
              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Lista Istruttori'),
                    Tab(text: 'Modifica Profilo'),
                    Tab(text: 'Aggiungi Istruttore'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              ),
            )
          : _error != null
              ? CustomErrorWidget(
                  errorMessage: _error!,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Lista Istruttori Tab
                    InstructorListWidget(
                      instructors: _instructors,
                      onInstructorSelected: _onInstructorSelected,
                      onRefresh: _loadInstructors,
                    ),
                    // Modifica Profilo Tab
                    InstructorProfileEditorWidget(
                      selectedInstructor: _selectedInstructor,
                      onInstructorUpdated: _onInstructorUpdated,
                      onInstructorDeleted: () {
                        _onInstructorUpdated();
                        _tabController.animateTo(0);
                      },
                    ),
                    // Aggiungi Istruttore Tab
                    AddInstructorWidget(onInstructorAdded: _onInstructorAdded),
                  ],
                ),
      floatingActionButton: _tabController.index == 0
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF0000).withAlpha(102),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  _tabController.animateTo(2);
                },
                backgroundColor: const Color(0xFFFF0000),
                foregroundColor: Colors.white,
                elevation: 0,
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: Text(
                  'Aggiungi Istruttore',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFF0000), size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
