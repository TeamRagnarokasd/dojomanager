import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
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

  // Current user role - in real app, this comes from authentication
  UserRole _currentUserRole = UserRole.student;

  // Instructor data - Updated with new disciplines
  List<Map<String, dynamic>> instructors = [
    {
      'id': 'silva_001',
      'name': 'Marco Silva',
      'primaryDiscipline': 'BJJ',
      'disciplines': ['BJJ', 'Grappling'],
      'profileImage':
          'https://images.pexels.com/photos/1222271/pexels-photo-1222271.jpeg?w=400',
      'bio':
          'Cintura Nera 3º Dan BJJ, Campione Europeo IBJJF 2019. Oltre 15 anni di esperienza nell\'insegnamento del Brazilian Jiu-Jitsu. Specializzato in tecniche di guardia e submission grappling.',
      'certifications': [
        'Cintura Nera 3º Dan BJJ - Gracie Academy',
        'Instructor Certificate IBJJF',
        'First Aid & CPR Certified',
      ],
      'achievements': [
        'Campione Europeo IBJJF 2019 - Peso Medio',
        'Vicecampione Mondiale IBJJF 2018',
        'Campione Nazionale Grappling 2017, 2018, 2020',
      ],
      'experience': '15+ anni',
      'schedule': {
        'Lunedì': ['18:00-19:00 BJJ Principianti', '20:30-21:30 BJJ Avanzati'],
        'Mercoledì': ['19:00-20:30 BJJ Gi Training'],
        'Venerdì': ['20:00-21:30 BJJ No-Gi'],
      },
      'specializations': ['Guard Work', 'Submissions', 'Competition Training'],
      'languages': ['Italiano', 'Inglese', 'Portoghese'],
      'contactInfo': {
        'availability': 'Lezioni private: Martedì e Giovedì 16:00-18:00',
        'seminars': 'Disponibile per seminari weekend',
        'phone': '+39 333 1234567',
        'email': 'marco.silva@teamragnarok.com',
      },
      'socialMedia': {
        'instagram': '@marcosilvabjj',
        'facebook': 'Marco Silva BJJ',
      },
      'studentTestimonials': [
        {
          'student': 'Luca R.',
          'rating': 5,
          'comment':
              'Istruttore eccezionale, tecnica impeccabile e grande pazienza con i principianti.',
        },
        {
          'student': 'Maria B.',
          'rating': 5,
          'comment':
              'Grazie a Marco ho imparato le basi del BJJ in modo sicuro e progressivo.',
        },
      ],
      'isActive': true,
      'joinDate': '2018-03-15',
    },
    {
      'id': 'volkov_001',
      'name': 'Dmitri Volkov',
      'primaryDiscipline': 'MMA',
      'disciplines': ['MMA', 'SAMBO'],
      'profileImage':
          'https://images.pexels.com/photos/1681010/pexels-photo-1681010.jpeg?w=400',
      'bio':
          'Ex-fighter professionista MMA con record 12-3-0. Maestro di SAMBO Combat e specialista in striking per MMA. Formato in Russia presso la prestigiosa accademia Red Devil.',
      'certifications': [
        'Master of Sport in SAMBO - Russia',
        'Professional MMA Fighter License',
        'Certified MMA Coach - Mixed Martial Arts Academy',
      ],
      'achievements': [
        'Pro MMA Record: 12 vittorie, 3 sconfitte',
        'Campione Russo SAMBO Combat 2015',
        'Winner Cage Warriors Featherweight Tournament 2017',
      ],
      'experience': '20+ anni',
      'schedule': {
        'Martedì': ['19:00-20:30 MMA Striking Fundamentals'],
        'Giovedì': [
          '18:30-20:00 Grappling per MMA',
          '20:30-22:00 MMA Sparring Avanzato'
        ],
        'Sabato': ['10:00-11:30 MMA Conditioning'],
      },
      'specializations': [
        'Striking',
        'Sambo Throws',
        'MMA Conditioning',
        'Fight Psychology'
      ],
      'languages': ['Russo', 'Inglese', 'Italiano'],
      'contactInfo': {
        'availability': 'Preparazione fight camp su richiesta',
        'seminars': 'Seminari SAMBO Combat disponibili',
        'phone': '+39 347 9876543',
        'email': 'dmitri.volkov@teamragnarok.com',
      },
      'socialMedia': {
        'instagram': '@dmitrivolkovmma',
        'youtube': 'Dmitri Volkov MMA',
      },
      'studentTestimonials': [
        {
          'student': 'Francesco T.',
          'rating': 5,
          'comment':
              'Dmitri è un vero guerriero, mi ha insegnato non solo tecniche ma mentalità vincente.',
        },
        {
          'student': 'Andrea M.',
          'rating': 5,
          'comment':
              'Le sue lezioni di striking sono intense e tecnicamente perfette.',
        },
      ],
      'isActive': true,
      'joinDate': '2019-01-20',
    },
    {
      'id': 'petrov_001',
      'name': 'Igor Petrov',
      'primaryDiscipline': 'SAMBO',
      'disciplines': ['SAMBO'],
      'profileImage':
          'https://images.pexels.com/photos/1239291/pexels-photo-1239291.jpeg?w=400',
      'bio':
          'Maestro internazionale di SAMBO Sport e Combat. Medaglia di bronzo ai Mondiali SAMBO 2016. Specializzato nell\'insegnamento delle proiezioni e tecniche di lotta a terra russe.',
      'certifications': [
        'International SAMBO Master - FIAS',
        'Certified SAMBO Referee Level A',
        'Sports Massage Therapist',
      ],
      'achievements': [
        'Medaglia di Bronzo Mondiali SAMBO 2016',
        'Campione Europeo SAMBO Sport 2014, 2015',
        'Allenatore Team Nazionale Junior SAMBO',
      ],
      'experience': '18+ anni',
      'schedule': {
        'Lunedì': ['19:30-21:00 SAMBO Combat Throws'],
        'Mercoledì': ['18:00-19:30 SAMBO Sport'],
      },
      'specializations': [
        'Russian Throws',
        'Ground Control',
        'SAMBO Competition Prep'
      ],
      'languages': ['Russo', 'Inglese'],
      'contactInfo': {
        'availability': 'Preparazione competizioni SAMBO',
        'seminars': 'Workshop tecniche avanzate su richiesta',
        'phone': '+39 340 5551234',
        'email': 'igor.petrov@teamragnarok.com',
      },
      'socialMedia': {
        'instagram': '@igorpetrovsambo',
      },
      'studentTestimonials': [
        {
          'student': 'Roberto K.',
          'rating': 5,
          'comment':
              'Igor ha una tecnica incredibile, ogni lezione imparo qualcosa di nuovo.',
        },
      ],
      'isActive': true,
      'joinDate': '2020-09-10',
    },
    {
      'id': 'mendez_001',
      'name': 'Carlos Mendez',
      'primaryDiscipline': 'Grappling',
      'disciplines': ['Grappling', 'BJJ'],
      'profileImage':
          'https://images.pexels.com/photos/1681010/pexels-photo-1681010.jpeg?w=400',
      'bio':
          'Specialista in No-Gi Grappling e submission wrestling. Cintura Nera BJJ con focus su tecniche moderne di leg lock e heel hook. Campione ADCC Trials 2018.',
      'certifications': [
        'Cintura Nera BJJ - Alliance Team',
        'ADCC Certified Grappling Instructor',
        'Modern Leg Lock System Certified',
      ],
      'achievements': [
        'Campione ADCC Trials 2018',
        'Finalista EBI (Eddie Bravo Invitational) 2019',
        'Multiple-time IBJJF No-Gi Champion',
      ],
      'experience': '12+ anni',
      'schedule': {
        'Martedì': ['20:30-22:00 No-Gi Submission Wrestling'],
        'Giovedì': ['17:00-18:30 Grappling Principianti'],
        'Domenica': ['10:30-12:00 Open Mat Sparring'],
      },
      'specializations': [
        'Leg Locks',
        'No-Gi Techniques',
        'Modern Grappling',
        'Competition Strategy'
      ],
      'languages': ['Spagnolo', 'Inglese', 'Italiano'],
      'contactInfo': {
        'availability': 'Private coaching per competizioni',
        'seminars': 'Leg lock seminars disponibili',
        'phone': '+39 338 7654321',
        'email': 'carlos.mendez@teamragnarok.com',
      },
      'socialMedia': {
        'instagram': '@carlosmendezgrappling',
        'youtube': 'Carlos Mendez Grappling',
      },
      'studentTestimonials': [
        {
          'student': 'Giulia S.',
          'rating': 5,
          'comment':
              'Carlos mi ha aperto un mondo nuovo nel grappling, tecniche moderne e efficaci.',
        },
      ],
      'isActive': true,
      'joinDate': '2019-11-01',
    },
  ];

  // UI state
  String searchQuery = '';
  List<String> selectedDisciplines = [];
  bool showActiveOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _simulateUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _simulateUserRole() {
    // Simulate different user roles - in real app comes from auth
    final roles = [UserRole.student, UserRole.instructor, UserRole.admin];
    setState(() {
      _currentUserRole = roles[DateTime.now().second % 3];
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
        actions: [
          if (_currentUserRole == UserRole.admin)
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
                  value: 'export_data',
                  child: Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'download',
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 2.w),
                      Text('Esporta Dati',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
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
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildInstructorsList(),
            _buildDisciplineView(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorsList() {
    final filteredInstructors = _getFilteredInstructors();

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
                onSearchChanged: (query) => setState(() => searchQuery = query),
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
                      },
                    ),
                  ),
                  SizedBox(width: 3.w),
                  GestureDetector(
                    onTap: () =>
                        setState(() => showActiveOnly = !showActiveOnly),
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
          child: filteredInstructors.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: EdgeInsets.all(4.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 3.w,
                    mainAxisSpacing: 3.w,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filteredInstructors.length,
                  itemBuilder: (context, index) {
                    final instructor = filteredInstructors[index];
                    return InstructorCardWidget(
                      instructor: instructor,
                      onTap: () => _showInstructorProfile(instructor),
                      canEdit: _currentUserRole == UserRole.admin,
                      onEdit: _currentUserRole == UserRole.admin
                          ? () => _editInstructor(instructor['id'])
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDisciplineView() {
    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: AppConstants.disciplines.length,
      itemBuilder: (context, index) {
        final discipline = AppConstants.disciplines[index];
        final disciplineInstructors = instructors
            .where(
                (instructor) => instructor['disciplines'].contains(discipline))
            .toList();

        return _buildDisciplineSection(discipline, disciplineInstructors);
      },
    );
  }

  Widget _buildDisciplineSection(
      String discipline, List<Map<String, dynamic>> disciplineInstructors) {
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
                  discipline,
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
                  canEdit: _currentUserRole == UserRole.admin,
                  onEdit: _currentUserRole == UserRole.admin
                      ? () => _editInstructor(instructor['id'])
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
                : 'Modifica i filtri per vedere più risultati',
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredInstructors() {
    return instructors.where((instructor) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!instructor['name'].toLowerCase().contains(query) &&
            !instructor['disciplines'].any(
                (discipline) => discipline.toLowerCase().contains(query)) &&
            !instructor['specializations']
                .any((spec) => spec.toLowerCase().contains(query))) {
          return false;
        }
      }

      // Discipline filter
      if (selectedDisciplines.isNotEmpty) {
        if (!selectedDisciplines.any(
            (discipline) => instructor['disciplines'].contains(discipline))) {
          return false;
        }
      }

      // Active filter
      if (showActiveOnly && !instructor['isActive']) {
        return false;
      }

      return true;
    }).toList();
  }

  void _showInstructorProfile(Map<String, dynamic> instructor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InstructorProfileWidget(
        instructor: instructor,
        canEdit: _currentUserRole == UserRole.admin,
        onEdit: _currentUserRole == UserRole.admin
            ? () {
                Navigator.pop(context);
                _editInstructor(instructor['id']);
              }
            : null,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _editInstructor(String instructorId) {
    // Implementation for editing instructor (admin only)
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
      case 'export_data':
        _exportData();
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

  void _exportData() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Esportazione dati istruttori - Funzionalità in arrivo'),
        backgroundColor: AppTheme.warningLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

enum UserRole { student, instructor, admin }
