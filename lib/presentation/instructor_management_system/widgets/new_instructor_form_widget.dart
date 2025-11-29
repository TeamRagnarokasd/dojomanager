import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' if (dart.library.io) 'dart:io';
import '../../../services/instructor_management_service.dart';

class NewInstructorFormWidget extends StatefulWidget {
  final VoidCallback onInstructorCreated;

  const NewInstructorFormWidget({super.key, required this.onInstructorCreated});

  @override
  State<NewInstructorFormWidget> createState() =>
      _NewInstructorFormWidgetState();
}

class _NewInstructorFormWidgetState extends State<NewInstructorFormWidget> {
  final InstructorManagementService _instructorService =
      InstructorManagementService();
  final ImagePicker _imagePicker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _achievementsController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _languagesController = TextEditingController();

  String? _primaryDiscipline;
  List<String> _selectedDisciplines = [];
  XFile? _selectedImageFile;
  Uint8List? _webImageBytes;
  bool _isCreating = false;
  bool _isPasswordVisible = false;

  final List<String> _availableDisciplines = [
    'bjj',
    'mma',
    'sambo',
    'grappling',
    'fitness',
  ];

  String _getDisciplineDisplayName(String discipline) {
    switch (discipline) {
      case 'bjj':
        return 'BJJ';
      case 'mma':
        return 'MMA';
      case 'sambo':
        return 'SAMBO';
      case 'grappling':
        return 'GRAPPLING';
      case 'fitness':
        return 'Prep. Atletica';
      default:
        return discipline.toUpperCase();
    }
  }

  Future<bool> _validateSelectedImage() async {
    if (_selectedImageFile == null) return false;

    try {
      if (kIsWeb) {
        // On web, check if we have bytes
        return _webImageBytes != null && _webImageBytes!.isNotEmpty;
      } else {
        // On mobile, check file exists and has content
        final file = File(_selectedImageFile!.path);
        final exists = await file.exists();
        if (exists) {
          final length = await file.length();
          return length > 0;
        }
        return false;
      }
    } catch (e) {
      print('Error validating image: $e');
      return false;
    }
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

      // Handle platform-specific image processing
      if (kIsWeb) {
        // On web, read image as bytes
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) {
          _showErrorMessage(
              'File immagine non valido. Seleziona un\'altra immagine.');
          return;
        }

        setState(() {
          _selectedImageFile = image;
          _webImageBytes = bytes;
        });
      } else {
        // On mobile, validate file exists
        final file = File(image.path);
        final exists = await file.exists();
        final length = exists ? await file.length() : 0;

        if (!exists || length == 0) {
          _showErrorMessage(
              'File immagine non valido. Seleziona un\'altra immagine.');
          return;
        }

        setState(() {
          _selectedImageFile = image;
          _webImageBytes = null;
        });
      }

      // Show success message
      _showSuccessMessage('Immagine caricata con successo!');
    } catch (e) {
      print('Error picking image: $e');
      _showErrorMessage('Errore nel caricamento dell\'immagine. Riprova.');
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3), // Extended duration
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4), // Extended duration for errors
        ),
      );
    }
  }

  Future<void> _createInstructor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_primaryDiscipline == null) {
      _showErrorMessage('Seleziona una disciplina principale');
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Prepare instructor data
      final instructorData = {
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'bio': _bioController.text.trim(),
        'years_experience': int.tryParse(_yearsExperienceController.text),
        'primary_discipline': _primaryDiscipline,
        'disciplines': _selectedDisciplines,
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
        'profile_image_file': _selectedImageFile,
        'web_image_bytes': _webImageBytes,
      };

      // Add detailed logging to track the creation process
      print(
          '🔄 Starting instructor creation with data: ${instructorData.keys.toList()}');

      await _instructorService.createNewInstructor(instructorData);

      print('✅ Instructor creation completed successfully');

      if (mounted) {
        // Clear form after successful creation
        _clearForm();

        // Show detailed success message with password info
        _showSuccessMessage(
            'Nuovo istruttore creato con successo! L\'istruttore può ora accedere con la password fornita.');

        // Close dialog and trigger refresh with a slight delay to ensure success message is visible
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop();
            widget.onInstructorCreated();
          }
        });
      }
    } catch (e) {
      print('❌ Error creating instructor: $e');

      if (mounted) {
        // Provide more specific error messages
        String errorMessage = 'Errore nella creazione dell\'istruttore.';

        if (e.toString().contains('email esiste già')) {
          errorMessage =
              'Un istruttore con questa email esiste già nel sistema.';
        } else if (e.toString().contains('permission denied') ||
            e.toString().contains('amministratori')) {
          errorMessage =
              'Non hai i permessi necessari per creare un nuovo istruttore.';
        } else if (e.toString().contains('network') ||
            e.toString().contains('connection')) {
          errorMessage =
              'Errore di connessione. Verifica la tua connessione internet e riprova.';
        } else {
          errorMessage = 'Errore nella creazione: ${e.toString()}';
        }

        _showErrorMessage(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  // Add method to clear form after successful creation
  void _clearForm() {
    _fullNameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _phoneController.clear();
    _bioController.clear();
    _yearsExperienceController.clear();
    _achievementsController.clear();
    _certificationsController.clear();
    _languagesController.clear();

    setState(() {
      _primaryDiscipline = null;
      _selectedDisciplines.clear();
      _selectedImageFile = null;
      _webImageBytes = null;
      _isPasswordVisible = false;
    });
  }

  Widget _buildImagePreview() {
    if (_selectedImageFile == null) {
      return Container(
        color: const Color(0xFF3A3A3A),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.grey,
              size: 35,
            ),
            const SizedBox(height: 6),
            Text(
              'Aggiungi\nFoto',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Show loading while validating
    return FutureBuilder<bool>(
      future: _validateSelectedImage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: const Color(0xFF3A3A3A),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          // Valid image - show preview based on platform
          if (kIsWeb && _webImageBytes != null) {
            return Image.memory(
              _webImageBytes!,
              fit: BoxFit.cover,
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF3A3A3A),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.orange,
                    size: 40,
                  ),
                );
              },
            );
          } else if (!kIsWeb && _selectedImageFile != null) {
            return Image.file(
              File(_selectedImageFile!.path),
              fit: BoxFit.cover,
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF3A3A3A),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.orange,
                    size: 40,
                  ),
                );
              },
            );
          }
        }

        // Invalid image or error
        return Container(
          color: const Color(0xFF3A3A3A),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.orange,
                size: 30,
              ),
              const SizedBox(height: 4),
              Text(
                'Immagine\nnon valida',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF0000),
                        const Color(0xFFFF0000).withAlpha(204),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuovo Istruttore',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Crea un profilo istruttore completo',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Profile Image Section
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
                                    color: _selectedImageFile != null
                                        ? Colors.green
                                        : const Color(0xFFFF0000),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_selectedImageFile != null
                                              ? Colors.green
                                              : const Color(0xFFFF0000))
                                          .withAlpha(77),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(60),
                                  child: _buildImagePreview(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedImageFile != null
                                    ? Colors.green.withAlpha(26)
                                    : Colors.grey.withAlpha(26),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _selectedImageFile != null
                                      ? Colors.green.withAlpha(77)
                                      : Colors.grey.withAlpha(77),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectedImageFile != null
                                        ? Icons.check_circle_outline
                                        : Icons.add_photo_alternate_outlined,
                                    color: _selectedImageFile != null
                                        ? Colors.green
                                        : Colors.grey[400],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedImageFile != null
                                        ? 'Immagine selezionata ✓'
                                        : 'Tocca per aggiungere foto',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _selectedImageFile != null
                                          ? Colors.green
                                          : Colors.grey[400],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Personal Information
                      _buildSectionTitle(
                        'Informazioni Personali',
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _fullNameController,
                        label: 'Nome Completo *',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci il nome completo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _emailController,
                        label: 'Email *',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci l\'email';
                          }
                          if (!value.contains('@')) {
                            return 'Inserisci un\'email valida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // NEW: Password field
                      _buildPasswordField(
                        controller: _passwordController,
                        label: 'Password *',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci una password';
                          }
                          if (value.length < 6) {
                            return 'La password deve avere almeno 6 caratteri';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Password help text
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withAlpha(77)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.blue, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'L\'istruttore potrà accedere con questa password e modificarla dal proprio profilo',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _phoneController,
                        label: 'Telefono',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),

                      // Professional Information
                      _buildSectionTitle(
                        'Informazioni Professionali',
                        Icons.work_outline,
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _bioController,
                        label: 'Biografia *',
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci una biografia';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _yearsExperienceController,
                        label: 'Anni di Esperienza *',
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
                      const SizedBox(height: 24),

                      // Enhanced Disciplines Section
                      _buildSectionTitle('Discipline', Icons.fitness_center),
                      const SizedBox(height: 16),

                      _buildDropdownField(
                        label: 'Disciplina Principale *',
                        value: _primaryDiscipline,
                        items: _availableDisciplines,
                        onChanged: (value) {
                          setState(() {
                            _primaryDiscipline = value;
                            if (value != null &&
                                !_selectedDisciplines.contains(value)) {
                              _selectedDisciplines.add(value);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Tutte le Discipline',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _availableDisciplines.map((discipline) {
                          final isSelected = _selectedDisciplines.contains(
                            discipline,
                          );
                          return FilterChip(
                            label: Text(
                              _getDisciplineDisplayName(discipline),
                              style: GoogleFonts.inter(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[400],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDisciplines.add(discipline);
                                } else {
                                  if (discipline != _primaryDiscipline) {
                                    _selectedDisciplines.remove(discipline);
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
                                  : Colors.grey[600]!,
                            ),
                            elevation: isSelected ? 4 : 0,
                            shadowColor: const Color(
                              0xFFFF0000,
                            ).withAlpha(77),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Additional Information
                      _buildSectionTitle(
                        'Informazioni Aggiuntive',
                        Icons.info_outline,
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _achievementsController,
                        label: 'Risultati e Riconoscimenti (uno per riga)',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _certificationsController,
                        label: 'Certificazioni (una per riga)',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      _buildTextFormField(
                        controller: _languagesController,
                        label: 'Lingue (separate da virgola)',
                        hintText: 'Italiano, Inglese, Spagnolo...',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Enhanced Action Buttons
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _isCreating ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2A2A2A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[600]!),
                      ),
                    ),
                    child: Text(
                      'Annulla',
                      style: GoogleFonts.inter(
                        color: Colors.grey[300],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createInstructor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFFFF0000).withAlpha(102),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreating
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Creazione...',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_add,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Crea Istruttore',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF0000), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
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
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF0000), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              dropdownColor: const Color(0xFF2A2A2A),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              hint: Text(
                'Seleziona disciplina',
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
              ),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    _getDisciplineDisplayName(item),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                    ),
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

  // NEW: Password field builder
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          obscureText: !_isPasswordVisible,
          validator: validator,
          decoration: InputDecoration(
            hintText: 'Inserisci la password per l\'accesso',
            hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF0000), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _yearsExperienceController.dispose();
    _achievementsController.dispose();
    _certificationsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }
}
