import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/instructor_management_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/discipline_service.dart';
import '../../../core/app_export.dart';

class InstructorProfileEditorWidget extends StatefulWidget {
  final Map<String, dynamic>? selectedInstructor;
  final VoidCallback onInstructorUpdated;
  final VoidCallback onInstructorDeleted;

  const InstructorProfileEditorWidget({
    super.key,
    required this.selectedInstructor,
    required this.onInstructorUpdated,
    required this.onInstructorDeleted,
  });

  @override
  State<InstructorProfileEditorWidget> createState() =>
      _InstructorProfileEditorWidgetState();
}

class _InstructorProfileEditorWidgetState
    extends State<InstructorProfileEditorWidget> {
  final InstructorManagementService _instructorService =
      InstructorManagementService();
  final SupabaseService _supabaseService = SupabaseService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _achievementsController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _languagesController = TextEditingController();

  String? _primaryDiscipline;
  List<String> _selectedDisciplines = [];
  List<String> _specializations = [];
  String? _profileImageUrl;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _disciplinesLoading = false;

  // Dynamic disciplines: list of {id, name}
  List<Map<String, String>> _availableDisciplines = [];

  @override
  void initState() {
    super.initState();
    _loadDisciplines();
    _loadInstructorData();
  }

  Future<void> _loadDisciplines() async {
    setState(() => _disciplinesLoading = true);
    try {
      final disciplines =
          await DisciplineService.instance.getActiveDisciplines();
      setState(() {
        _availableDisciplines = disciplines
            .map<Map<String, String>>((d) => {
                  'id': d['id']?.toString() ?? '',
                  'name': d['name']?.toString() ?? d['id']?.toString() ?? '',
                })
            .where((d) => d['id']!.isNotEmpty)
            .toList();
      });
    } catch (e) {
      // fallback: keep empty list
    } finally {
      setState(() => _disciplinesLoading = false);
    }
  }

  String _getDisciplineDisplayName(String id) {
    final match = _availableDisciplines.firstWhere(
      (d) => d['id'] == id,
      orElse: () => {'id': id, 'name': id.toUpperCase()},
    );
    return match['name'] ?? id.toUpperCase();
  }

  @override
  void didUpdateWidget(InstructorProfileEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedInstructor != oldWidget.selectedInstructor) {
      _loadInstructorData();
    }
  }

  void _loadInstructorData() {
    if (widget.selectedInstructor == null) {
      _clearForm();
      return;
    }

    final instructor = widget.selectedInstructor!;

    _bioController.text = instructor['bio'] ?? '';
    _yearsExperienceController.text =
        instructor['years_experience']?.toString() ?? '';
    _primaryDiscipline = instructor['primary_discipline'];
    _isActive = instructor['is_active'] ?? true;
    _profileImageUrl = instructor['profile_image_url'];

    // Handle disciplines array
    final disciplines = instructor['disciplines'] as List<dynamic>?;
    _selectedDisciplines = disciplines?.cast<String>() ?? [];

    // Handle achievements array
    final achievements = instructor['achievements'] as List<dynamic>?;
    _achievementsController.text = achievements?.join('\n') ?? '';

    // Handle certifications array
    final certifications = instructor['certifications'] as List<dynamic>?;
    _certificationsController.text = certifications?.join('\n') ?? '';

    // Handle languages array
    final languages = instructor['languages'] as List<dynamic>?;
    _languagesController.text = languages?.join(', ') ?? '';

    // Handle specializations array
    final specializations = instructor['specializations'] as List<dynamic>?;
    _specializations = specializations?.cast<String>() ?? [];

    setState(() {});
  }

  void _clearForm() {
    _bioController.clear();
    _yearsExperienceController.clear();
    _achievementsController.clear();
    _certificationsController.clear();
    _languagesController.clear();
    _primaryDiscipline = null;
    _selectedDisciplines.clear();
    _specializations.clear();
    _profileImageUrl = null;
    _isActive = true;
    setState(() {});
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      // Get current user ID for file path organization
      final currentUser = _supabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Utente non autenticato');
      }

      // Use current user's ID for folder structure
      final fileName =
          'instructor_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${currentUser.id}/$fileName';

      // Upload to Supabase storage with proper error handling
      await _supabaseService.client.storage
          .from('instructor-images')
          .uploadBinary(
            filePath,
            await image.readAsBytes(),
            fileOptions: const FileOptions(upsert: true, cacheControl: '3600'),
          );

      // Get the public URL for the uploaded image
      final imageUrl = _supabaseService.client.storage
          .from('instructor-images')
          .getPublicUrl(filePath);

      setState(() {
        _profileImageUrl = imageUrl;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('instructor_mgmt.image_upload_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = 'instructor_management.image_load_error'.tr();

        // Provide specific error messages for common issues
        if (e.toString().contains('row-level security')) {
          errorMessage = 'instructor_management.auth_error'.tr();
        } else if (e.toString().contains('Unauthorized')) {
          errorMessage =
              'Non hai i permessi necessari per caricare l\'immagine.';
        } else if (e.toString().contains('not found')) {
          errorMessage =
              'Bucket di storage non trovato. Verifica la configurazione.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'common.retry'.tr(),
              textColor: Colors.white,
              onPressed: _pickImage,
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateInstructor() async {
    if (!_formKey.currentState!.validate() ||
        widget.selectedInstructor == null) {
      return;
    }

    if (_primaryDiscipline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('instructor_management.select_main_discipline'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final instructorId = widget.selectedInstructor!['instructor_id'];

      // Prepare update data
      final updateData = {
        'bio': _bioController.text.trim(),
        'years_experience': int.tryParse(_yearsExperienceController.text),
        'primary_discipline': _primaryDiscipline,
        'disciplines': _selectedDisciplines,
        'specializations': _specializations,
        'achievements': _achievementsController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList(),
        'certifications': _certificationsController.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList(),
        'languages': _languagesController.text
            .split(',')
            .map((lang) => lang.trim())
            .where((lang) => lang.isNotEmpty)
            .toList(),
        'is_active': _isActive,
        'profile_image_url': _profileImageUrl,
      };

      await _instructorService.updateInstructorDetails(
        instructorId,
        updateData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('instructor_management.profile_updated'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        widget.onInstructorUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'instructor_mgmt.update_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteInstructor() async {
    if (widget.selectedInstructor == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          'instructor_management.confirm_deletion'.tr(),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'Sei sicuro di voler eliminare questo istruttore? Questa azione non può essere annullata.',
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'common.delete'.tr(),
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isUpdating = true);

      final instructorId = widget.selectedInstructor!['instructor_id'];
      await _instructorService.deleteInstructorProfile(instructorId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('instructor_mgmt.instructor_deleted'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        widget.onInstructorDeleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'instructor_mgmt.delete_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedInstructor == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'instructor_management.select_instructor_from_list'.tr(),
              style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]),
            ),
            Text(
              'per modificarne il profilo',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image Section
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(
                          color: const Color(0xFFFF0000),
                          width: 3,
                        ),
                      ),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF0000),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(57),
                              child: _profileImageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: _profileImageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: const Color(0xFF3A3A3A),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                          size: 50,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: const Color(
                                          0xFF3A3A3A,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                          size: 50,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFF3A3A3A),
                                      child: const Icon(
                                        Icons.add_a_photo,
                                        color: Colors.grey,
                                        size: 50,
                                      ),
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tocca per cambiare foto',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Basic Info Section
            Text(
              'instructor_management.general_info'.tr(),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Biography
            _buildTextFormField(
              controller: _bioController,
              label: 'Biografia',
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci una biografia';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Years of Experience
            _buildTextFormField(
              controller: _yearsExperienceController,
              label: 'Anni di Esperienza',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci gli anni di esperienza';
                }
                if (int.tryParse(value) == null) {
                  return 'Inserisci un numero valido';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Active Status
            Row(
              children: [
                Text(
                  'Stato Istruttore:',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  activeThumbColor: const Color(0xFFFF0000),
                ),
                Text(
                  _isActive ? 'common.active'.tr() : 'common.inactive'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _isActive ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Disciplines Section
            Text(
              'Discipline e Specializzazioni',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Primary Discipline
            _buildDropdownField(
              label: 'Disciplina Principale',
              value: _primaryDiscipline,
              items: _availableDisciplines.map((d) => d['id']!).toList(),
              onChanged: (value) {
                setState(() {
                  _primaryDiscipline = value;
                  if (value != null && !_selectedDisciplines.contains(value)) {
                    _selectedDisciplines.add(value);
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // All Disciplines
            Text(
              'Tutte le Discipline',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[300]),
            ),
            const SizedBox(height: 8),
            _disciplinesLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableDisciplines.map((discipline) {
                      final id = discipline['id']!;
                      final displayName = discipline['name']!;
                      final isSelected = _selectedDisciplines.contains(id);
                      return FilterChip(
                        label: Text(
                          displayName.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDisciplines.add(id);
                            } else {
                              if (id != _primaryDiscipline) {
                                _selectedDisciplines.remove(id);
                              }
                            }
                          });
                        },
                        selectedColor: const Color(0xFFFF0000),
                        checkmarkColor: Colors.white,
                        backgroundColor: const Color(0xFF3A3A3A),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFFF0000)
                              : Colors.grey,
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 30),

            // Additional Information Section
            Text(
              'instructor_management.additional_info'.tr(),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Combined Achievements and Certifications
            _buildTextFormField(
              controller: _achievementsController,
              label: 'Risultati Riconoscimenti e Certificazioni (uno per riga)',
              maxLines: 5,
              hintText:
                  'Inserisci risultati, riconoscimenti e certificazioni...',
            ),
            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _updateInstructor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'instructor_management.update_profile'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isUpdating ? null : _deleteInstructor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[300]),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF0000)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[300]),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: _disciplinesLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : null,
                    style: GoogleFonts.inter(color: Colors.white),
                    dropdownColor: const Color(0xFF2A2A2A),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    hint: Text(
                      'instructor_management.select_discipline_label'.tr(),
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                    items: items.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(
                          _getDisciplineDisplayName(item).toUpperCase(),
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _bioController.dispose();
    _yearsExperienceController.dispose();
    _achievementsController.dispose();
    _certificationsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }
}
