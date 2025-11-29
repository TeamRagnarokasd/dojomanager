import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/instructor_management_service.dart';

class InstructorManagementWidget extends StatefulWidget {
  const InstructorManagementWidget({Key? key}) : super(key: key);

  @override
  State<InstructorManagementWidget> createState() =>
      _InstructorManagementWidgetState();
}

class _InstructorManagementWidgetState
    extends State<InstructorManagementWidget> {
  List<Map<String, dynamic>> _instructors = [];
  Map<String, dynamic>? _selectedInstructor;
  bool _isLoading = true;
  bool _isExpanded = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInstructors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInstructors() async {
    try {
      final instructors = await InstructorManagementService.getAllInstructors();
      if (mounted) {
        setState(() {
          _instructors = instructors;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento degli istruttori: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento dettagli: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Istruttore aggiornato con successo'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'aggiornamento: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Immagine caricata con successo'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento immagine: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'Istruttore attivato' : 'Istruttore disattivato',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel cambio stato: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).cardColor,
                Theme.of(context).cardColor.withAlpha(242),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange.withAlpha(26),
                      Colors.orange.withAlpha(13),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withAlpha(38),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepOrange.withAlpha(77),
                        ),
                      ),
                      child: Icon(
                        Icons.person_4,
                        color: Colors.deepOrange,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Controllo Istruttori',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Gestisci profili, foto e corsi degli istruttori',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.deepOrange,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              if (_isExpanded) ...[
                Container(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instructors List
                      if (_isLoading)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(4.w),
                            child: CircularProgressIndicator(
                              color: Colors.deepOrange,
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          'Seleziona Istruttore',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2.h),

                        Container(
                          height: 12.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _instructors.length,
                            separatorBuilder:
                                (context, index) => SizedBox(width: 3.w),
                            itemBuilder: (context, index) {
                              final instructor = _instructors[index];
                              final isSelected =
                                  _selectedInstructor?['id'] ==
                                  instructor['id'];

                              return GestureDetector(
                                onTap: () => _selectInstructor(instructor),
                                child: Container(
                                  width: 20.w,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Colors.deepOrange.withAlpha(38)
                                            : Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? Colors.deepOrange
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withAlpha(77),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 2.5.h,
                                        backgroundImage:
                                            instructor['profile_image_url'] !=
                                                    null
                                                ? NetworkImage(
                                                  instructor['profile_image_url'],
                                                )
                                                : null,
                                        child:
                                            instructor['profile_image_url'] ==
                                                    null
                                                ? Icon(
                                                  Icons.person,
                                                  color: Colors.deepOrange,
                                                )
                                                : null,
                                      ),
                                      SizedBox(height: 1.h),
                                      Text(
                                        instructor['full_name'] ?? 'N/A',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          color:
                                              isSelected
                                                  ? Colors.deepOrange
                                                  : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        if (_selectedInstructor != null) ...[
                          SizedBox(height: 3.h),
                          Divider(color: Colors.deepOrange.withAlpha(77)),
                          SizedBox(height: 2.h),

                          // Profile Management Section
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Section
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: _pickAndUploadImage,
                                    child: Container(
                                      width: 20.w,
                                      height: 20.w,
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.withAlpha(26),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.deepOrange.withAlpha(
                                            77,
                                          ),
                                        ),
                                      ),
                                      child:
                                          _selectedInstructor!['profile_image_url'] !=
                                                  null
                                              ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                child: Image.network(
                                                  _selectedInstructor!['profile_image_url'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Icon(
                                                        Icons.person,
                                                        color:
                                                            Colors.deepOrange,
                                                        size: 8.w,
                                                      ),
                                                ),
                                              )
                                              : Icon(
                                                Icons.add_a_photo,
                                                color: Colors.deepOrange,
                                                size: 8.w,
                                              ),
                                    ),
                                  ),
                                  SizedBox(height: 1.h),
                                  Text(
                                    'Tocca per\ncambiare foto',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: Colors.deepOrange,
                                      fontSize: 9.sp,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),

                              SizedBox(width: 4.w),

                              // Form Section
                              Expanded(
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _nameController,
                                      decoration: InputDecoration(
                                        labelText: 'Nome Completo',
                                        prefixIcon: Icon(
                                          Icons.person,
                                          color: Colors.deepOrange,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        labelText: 'Telefono',
                                        prefixIcon: Icon(
                                          Icons.phone,
                                          color: Colors.deepOrange,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _updateInstructor,
                                            icon: Icon(Icons.save),
                                            label: Text('Salva Modifiche'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.deepOrange,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 2.w),
                                        ElevatedButton.icon(
                                          onPressed: _toggleInstructorStatus,
                                          icon: Icon(
                                            _selectedInstructor!['is_active'] ==
                                                    true
                                                ? Icons.pause_circle
                                                : Icons.play_circle,
                                          ),
                                          label: Text(
                                            _selectedInstructor!['is_active'] ==
                                                    true
                                                ? 'Disattiva'
                                                : 'Attiva',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                _selectedInstructor!['is_active'] ==
                                                        true
                                                    ? Colors.red
                                                    : Colors.green,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 2.h),

                          // Quick Info
                          Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withAlpha(13),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.deepOrange.withAlpha(51),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email,
                                      color: Colors.deepOrange,
                                      size: 16,
                                    ),
                                    SizedBox(width: 2.w),
                                    Expanded(
                                      child: Text(
                                        _selectedInstructor!['email'] ?? 'N/A',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 1.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings,
                                      color: Colors.deepOrange,
                                      size: 16,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Ruolo: ${_selectedInstructor!['role'] ?? 'N/A'}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2.w,
                                        vertical: 0.5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _selectedInstructor!['is_active'] ==
                                                    true
                                                ? Colors.green.withAlpha(26)
                                                : Colors.red.withAlpha(26),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _selectedInstructor!['is_active'] ==
                                                true
                                            ? 'ATTIVO'
                                            : 'INATTIVO',
                                        style: TextStyle(
                                          color:
                                              _selectedInstructor!['is_active'] ==
                                                      true
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}