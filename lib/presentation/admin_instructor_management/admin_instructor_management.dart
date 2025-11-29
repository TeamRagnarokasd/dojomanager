import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/instructor_management_service.dart';

class AdminInstructorManagement extends StatefulWidget {
  const AdminInstructorManagement({Key? key}) : super(key: key);

  @override
  State<AdminInstructorManagement> createState() =>
      _AdminInstructorManagementState();
}

class _AdminInstructorManagementState extends State<AdminInstructorManagement>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _filteredInstructors = [];
  Map<String, dynamic>? _selectedInstructor;
  bool _isLoading = true;
  String _searchQuery = '';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _searchController = TextEditingController();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _loadInstructors();
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _bioController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstructors() async {
    try {
      final instructors = await InstructorManagementService.getAllInstructors();
      if (mounted) {
        setState(() {
          _instructors = instructors;
          _filteredInstructors = instructors;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Errore nel caricamento degli istruttori: $error');
      }
    }
  }

  void _filterInstructors(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredInstructors = _instructors;
      } else {
        _filteredInstructors =
            _instructors
                .where(
                  (instructor) =>
                      instructor['full_name']
                              ?.toString()
                              .toLowerCase()
                              .contains(_searchQuery) ==
                          true ||
                      instructor['email']?.toString().toLowerCase().contains(
                            _searchQuery,
                          ) ==
                          true,
                )
                .toList();
      }
    });
  }

  Future<void> _selectInstructor(Map<String, dynamic> instructor) async {
    try {
      final details = await InstructorManagementService.getInstructorDetails(
        instructor['id'],
      );

      if (details != null && mounted) {
        setState(() {
          _selectedInstructor = details;
          _nameController.text = details['full_name'] ?? '';
          _phoneController.text = details['phone'] ?? '';
          _emergencyContactController.text = details['emergency_contact'] ?? '';
          _emergencyPhoneController.text = details['emergency_phone'] ?? '';
          // Note: bio would come from instructor_profiles table
        });
      }
    } catch (error) {
      _showErrorSnackBar('Errore nel caricamento dettagli: $error');
    }
  }

  Future<void> _updateInstructor() async {
    if (_selectedInstructor == null) return;

    try {
      final updatedInstructor =
          await InstructorManagementService.updateInstructor(
            instructorId: _selectedInstructor!['id'],
            fullName:
                _nameController.text.trim().isNotEmpty
                    ? _nameController.text.trim()
                    : null,
            phone:
                _phoneController.text.trim().isNotEmpty
                    ? _phoneController.text.trim()
                    : null,
            emergencyContact:
                _emergencyContactController.text.trim().isNotEmpty
                    ? _emergencyContactController.text.trim()
                    : null,
            emergencyPhone:
                _emergencyPhoneController.text.trim().isNotEmpty
                    ? _emergencyPhoneController.text.trim()
                    : null,
          );

      if (updatedInstructor != null && mounted) {
        setState(() {
          _selectedInstructor = updatedInstructor;
        });

        await _loadInstructors();
        _showSuccessSnackBar('Istruttore aggiornato con successo');
      }
    } catch (error) {
      _showErrorSnackBar('Errore nell\'aggiornamento: $error');
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_selectedInstructor == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final imageUrl =
            await InstructorManagementService.uploadInstructorImage(
              instructorId: _selectedInstructor!['id'],
              imageBytes: bytes,
              fileName: fileName,
            );

        if (imageUrl != null && mounted) {
          setState(() {
            _selectedInstructor!['profile_image_url'] = imageUrl;
          });

          await _loadInstructors();
          _showSuccessSnackBar('Immagine caricata con successo');
        }
      }
    } catch (error) {
      _showErrorSnackBar('Errore nel caricamento immagine: $error');
    }
  }

  Future<void> _toggleInstructorStatus() async {
    if (_selectedInstructor == null) return;

    try {
      final newStatus = !(_selectedInstructor!['is_active'] ?? true);
      final success = await InstructorManagementService.toggleInstructorStatus(
        _selectedInstructor!['id'],
        newStatus,
      );

      if (success && mounted) {
        setState(() {
          _selectedInstructor!['is_active'] = newStatus;
        });

        await _loadInstructors();
        _showSuccessSnackBar(
          newStatus ? 'Istruttore attivato' : 'Istruttore disattivato',
        );
      }
    } catch (error) {
      _showErrorSnackBar('Errore nel cambio stato: $error');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        title: Text(
          'Gestione Istruttori',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20.sp),
        ),
        leading: IconButton(
          icon: Icon(Icons.home, color: Colors.white),
          onPressed:
              () => Navigator.pushReplacementNamed(
                context,
                '/enhanced-admin-dashboard',
              ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: Icon(Icons.list), text: 'Lista Istruttori'),
            Tab(icon: Icon(Icons.edit), text: 'Modifica Profilo'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [_buildInstructorsList(), _buildInstructorEditor()],
        ),
      ),
    );
  }

  Widget _buildInstructorsList() {
    return Column(
      children: [
        // Search Bar
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withAlpha(26),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _filterInstructors,
            decoration: InputDecoration(
              hintText: 'Cerca istruttore per nome o email...',
              prefixIcon: Icon(Icons.search, color: Colors.deepOrange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.deepOrange.withAlpha(77)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.deepOrange, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),

        // Instructors List
        Expanded(
          child:
              _isLoading
                  ? Center(
                    child: CircularProgressIndicator(color: Colors.deepOrange),
                  )
                  : _filteredInstructors.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Nessun istruttore trovato'
                              : 'Nessun risultato per "$_searchQuery"',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.separated(
                    padding: EdgeInsets.all(4.w),
                    itemCount: _filteredInstructors.length,
                    separatorBuilder: (context, index) => SizedBox(height: 2.h),
                    itemBuilder: (context, index) {
                      final instructor = _filteredInstructors[index];
                      final isSelected =
                          _selectedInstructor?['id'] == instructor['id'];

                      return InkWell(
                        onTap: () {
                          _selectInstructor(instructor);
                          _tabController.animateTo(1);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.deepOrange.withAlpha(26)
                                    : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.deepOrange
                                      : Theme.of(
                                        context,
                                      ).colorScheme.outline.withAlpha(51),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).shadowColor.withAlpha(13),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 6.w,
                                backgroundImage:
                                    instructor['profile_image_url'] != null
                                        ? NetworkImage(
                                          instructor['profile_image_url'],
                                        )
                                        : null,
                                child:
                                    instructor['profile_image_url'] == null
                                        ? Icon(
                                          Icons.person,
                                          color: Colors.deepOrange,
                                          size: 6.w,
                                        )
                                        : null,
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      instructor['full_name'] ?? 'N/A',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isSelected
                                                ? Colors.deepOrange
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      instructor['email'] ?? 'N/A',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 2.w,
                                            vertical: 0.5.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                instructor['is_active'] == true
                                                    ? Colors.green.withAlpha(26)
                                                    : Colors.red.withAlpha(26),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            instructor['is_active'] == true
                                                ? 'ATTIVO'
                                                : 'INATTIVO',
                                            style: TextStyle(
                                              color:
                                                  instructor['is_active'] ==
                                                          true
                                                      ? Colors.green
                                                      : Colors.red,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 9.sp,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 2.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 2.w,
                                            vertical: 0.5.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrange.withAlpha(
                                              26,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            instructor['role']
                                                    ?.toString()
                                                    .toUpperCase() ??
                                                'N/A',
                                            style: TextStyle(
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 9.sp,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color:
                                    isSelected
                                        ? Colors.deepOrange
                                        : Theme.of(context).colorScheme.outline,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildInstructorEditor() {
    if (_selectedInstructor == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            SizedBox(height: 2.h),
            Text(
              'Seleziona un istruttore dalla lista',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            SizedBox(height: 1.h),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: Text('Vai alla Lista'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image Section
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withAlpha(26),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.deepOrange.withAlpha(77),
                        width: 2,
                      ),
                    ),
                    child:
                        _selectedInstructor!['profile_image_url'] != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                _selectedInstructor!['profile_image_url'],
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Icon(
                                      Icons.person,
                                      color: Colors.deepOrange,
                                      size: 15.w,
                                    ),
                              ),
                            )
                            : Icon(
                              Icons.add_a_photo,
                              color: Colors.deepOrange,
                              size: 15.w,
                            ),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Tocca per cambiare foto profilo',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Form Fields
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informazioni Personali',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3.h),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome Completo',
                      prefixIcon: Icon(Icons.person, color: Colors.deepOrange),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.deepOrange),
                      ),
                    ),
                  ),

                  SizedBox(height: 2.h),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefono',
                      prefixIcon: Icon(Icons.phone, color: Colors.deepOrange),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.deepOrange),
                      ),
                    ),
                  ),

                  SizedBox(height: 2.h),

                  TextField(
                    controller: _emergencyContactController,
                    decoration: InputDecoration(
                      labelText: 'Contatto di Emergenza',
                      prefixIcon: Icon(
                        Icons.contact_phone,
                        color: Colors.deepOrange,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.deepOrange),
                      ),
                    ),
                  ),

                  SizedBox(height: 2.h),

                  TextField(
                    controller: _emergencyPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Telefono di Emergenza',
                      prefixIcon: Icon(
                        Icons.emergency,
                        color: Colors.deepOrange,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.deepOrange),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 3.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _updateInstructor,
                  icon: Icon(Icons.save),
                  label: Text('Salva Modifiche'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleInstructorStatus,
                  icon: Icon(
                    _selectedInstructor!['is_active'] == true
                        ? Icons.pause_circle
                        : Icons.play_circle,
                  ),
                  label: Text(
                    _selectedInstructor!['is_active'] == true
                        ? 'Disattiva'
                        : 'Attiva',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selectedInstructor!['is_active'] == true
                            ? Colors.red
                            : Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 3.h),

          // Info Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepOrange.withAlpha(26),
                    Colors.orange.withAlpha(13),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informazioni di Sistema',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),

                  _buildInfoRow(
                    Icons.email,
                    'Email',
                    _selectedInstructor!['email'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    Icons.admin_panel_settings,
                    'Ruolo',
                    _selectedInstructor!['role']?.toString().toUpperCase() ??
                        'N/A',
                  ),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Creato',
                    _selectedInstructor!['created_at'] != null
                        ? DateTime.parse(
                          _selectedInstructor!['created_at'],
                        ).toLocal().toString().split(' ')[0]
                        : 'N/A',
                  ),
                  _buildInfoRow(
                    Icons.update,
                    'Aggiornato',
                    _selectedInstructor!['updated_at'] != null
                        ? DateTime.parse(
                          _selectedInstructor!['updated_at'],
                        ).toLocal().toString().split(' ')[0]
                        : 'N/A',
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.8.h),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepOrange, size: 18),
          SizedBox(width: 3.w),
          Text(
            '$label:',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}