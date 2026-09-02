import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../services/supabase_service.dart';
import '../../services/child_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../constants/app_constants.dart';

/// Full profile screen for admin to view and edit a child/minor profile.
/// Navigated to from admin_management_system when tapping a child card.
class AdminChildProfileScreen extends StatefulWidget {
  const AdminChildProfileScreen({Key? key}) : super(key: key);

  @override
  State<AdminChildProfileScreen> createState() =>
      _AdminChildProfileScreenState();
}

class _AdminChildProfileScreenState extends State<AdminChildProfileScreen> {
  Map<String, dynamic>? _child;
  Map<String, dynamic>? _parentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isUploadingCert = false;
  bool _isUploadingDoc = false;
  String? _profilePhotoSignedUrl;

  // Edit controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _taxCodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _medicalNotesCtrl = TextEditingController();
  bool _imageConsent = false;
  DateTime? _birthDate;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadData();
    }
  }

  void _loadData() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final child = args['child'] as Map<String, dynamic>?;
      final parent = args['parent'] as Map<String, dynamic>?;
      if (child != null) {
        _child = child;
        _parentUser = parent;
        _populateControllers(child);
        setState(() => _isLoading = false);
        _loadProfilePhoto(child);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfilePhoto(Map<String, dynamic> child) async {
    final storagePath = child['profile_photo_url'] as String?;
    if (storagePath != null && storagePath.isNotEmpty) {
      final url = await ChildProfileService.getChildProfilePhotoUrl(
        storagePath,
      );
      if (mounted) setState(() => _profilePhotoSignedUrl = url);
    }
  }

  void _populateControllers(Map<String, dynamic> child) {
    _firstNameCtrl.text = child['first_name']?.toString() ?? '';
    _lastNameCtrl.text = child['last_name']?.toString() ?? '';
    _taxCodeCtrl.text =
        (child['tax_code'] ?? child['codice_fiscale'])?.toString() ?? '';
    _phoneCtrl.text = child['phone']?.toString() ?? '';
    _cityCtrl.text = child['city']?.toString() ?? '';
    _addressCtrl.text = child['address_line']?.toString() ?? '';
    _provinceCtrl.text = child['province']?.toString() ?? '';
    _capCtrl.text = child['cap']?.toString() ?? '';
    _emergencyNameCtrl.text = child['emergency_contact_name']?.toString() ?? '';
    _emergencyPhoneCtrl.text =
        child['emergency_contact_phone']?.toString() ?? '';
    _medicalNotesCtrl.text = child['medical_notes']?.toString() ?? '';
    _imageConsent = child['image_consent'] as bool? ?? false;
    final birthDateStr = child['birth_date'] as String?;
    if (birthDateStr != null) {
      try {
        _birthDate = DateTime.parse(birthDateStr);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _taxCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _provinceCtrl.dispose();
    _capCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _medicalNotesCtrl.dispose();
    super.dispose();
  }

  String get _childFullName {
    final first = _firstNameCtrl.text.isNotEmpty
        ? _firstNameCtrl.text
        : (_child?['first_name'] ?? '');
    final last = _lastNameCtrl.text.isNotEmpty
        ? _lastNameCtrl.text
        : (_child?['last_name'] ?? '');
    return '$first $last'.trim();
  }

  String? get _childAge {
    if (_birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age--;
    }
    return '$age anni';
  }

  Future<void> _saveChanges() async {
    final childId = _child?['id']?.toString();
    if (childId == null) return;

    setState(() => _isSaving = true);
    try {
      final client = SupabaseService.instance.client;
      final data = <String, dynamic>{
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'image_consent': _imageConsent,
      };
      if (_taxCodeCtrl.text.trim().isNotEmpty) {
        data['tax_code'] = _taxCodeCtrl.text.trim().toUpperCase();
        data['codice_fiscale'] = _taxCodeCtrl.text.trim().toUpperCase();
      }
      if (_phoneCtrl.text.trim().isNotEmpty)
        data['phone'] = _phoneCtrl.text.trim();
      if (_cityCtrl.text.trim().isNotEmpty)
        data['city'] = _cityCtrl.text.trim();
      if (_addressCtrl.text.trim().isNotEmpty)
        data['address_line'] = _addressCtrl.text.trim();
      if (_provinceCtrl.text.trim().isNotEmpty)
        data['province'] = _provinceCtrl.text.trim();
      if (_capCtrl.text.trim().isNotEmpty) data['cap'] = _capCtrl.text.trim();
      if (_emergencyNameCtrl.text.trim().isNotEmpty)
        data['emergency_contact_name'] = _emergencyNameCtrl.text.trim();
      if (_emergencyPhoneCtrl.text.trim().isNotEmpty)
        data['emergency_contact_phone'] = _emergencyPhoneCtrl.text.trim();
      if (_medicalNotesCtrl.text.trim().isNotEmpty)
        data['medical_notes'] = _medicalNotesCtrl.text.trim();
      if (_birthDate != null)
        data['birth_date'] = _birthDate!.toIso8601String().split('T')[0];

      await client.from('child_profiles').update(data).eq('id', childId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profilo minore aggiornato con successo'),
            backgroundColor: Colors.green,
          ),
        );
        // Update local state
        setState(() {
          _child = {...?_child, ...data};
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2010),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF0000),
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E1E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _updateProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(
              'Aggiorna Foto Profilo',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Scegli come aggiornare la foto del minore',
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 12.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(
                  icon: Icons.camera_alt,
                  label: 'Fotocamera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _photoOption(
                  icon: Icons.photo_library,
                  label: 'Galleria',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
            SizedBox(height: 3.h),
          ],
        ),
      ),
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35.w,
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.red.withAlpha(102)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18.w,
              height: 18.w,
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(51),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Icon(icon, color: Colors.red, size: 8.w),
            ),
            SizedBox(height: 1.5.h),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);

    if (source == ImageSource.camera) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permesso fotocamera necessario'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Impostazioni',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isUploadingPhoto = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (image != null) {
        final childId = _child?['id']?.toString();
        if (childId == null) return;

        final bytes = await image.readAsBytes();
        final storagePath = await ChildProfileService.uploadChildProfilePhoto(
          childProfileId: childId,
          fileBytes: bytes,
          fileName: image.name,
        );

        final signedUrl = await ChildProfileService.getChildProfilePhotoUrl(
          storagePath,
        );

        // Re-fetch the child record from DB to ensure local state is in sync
        try {
          final freshChild = await SupabaseService.instance.client
              .from('child_profiles')
              .select('*')
              .eq('id', childId)
              .single();
          if (mounted) {
            setState(() {
              _child = Map<String, dynamic>.from(freshChild);
              _profilePhotoSignedUrl = signedUrl;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _profilePhotoSignedUrl = signedUrl;
              _child = {...?_child, 'profile_photo_url': storagePath};
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profilo aggiornata con successo'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Profilo Minore',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_child == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Profilo Minore',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
          ),
        ),
        body: Center(
          child: Text(
            'Profilo non trovato',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profilo Minore',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Image.asset(
            AppConstants.teamLogo,
            width: 8.w,
            height: 4.h,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header card ──────────────────────────────────────────
            _buildHeaderCard(),
            SizedBox(height: 3.h),

            // ── Parent info ──────────────────────────────────────────
            if (_parentUser != null) _buildParentInfoCard(),
            if (_parentUser != null) SizedBox(height: 3.h),

            // ── Personal info ────────────────────────────────────────
            _buildSectionCard(
              title: 'Informazioni Personali',
              icon: Icons.person,
              children: [
                _buildRow(
                  label: 'Nome',
                  controller: _firstNameCtrl,
                  icon: Icons.person,
                ),
                SizedBox(height: 1.5.h),
                _buildRow(
                  label: 'Cognome',
                  controller: _lastNameCtrl,
                  icon: Icons.person_outline,
                ),
                SizedBox(height: 1.5.h),
                _buildRow(
                  label: 'Codice Fiscale',
                  controller: _taxCodeCtrl,
                  icon: Icons.badge,
                  textCapitalization: TextCapitalization.characters,
                ),
                SizedBox(height: 1.5.h),
                _buildRow(
                  label: 'Telefono',
                  controller: _phoneCtrl,
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 1.5.h),
                // Birth date picker
                GestureDetector(
                  onTap: _pickBirthDate,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 1.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake, color: Colors.grey[400], size: 18),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            _birthDate != null
                                ? 'Data di nascita: ${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}${_childAge != null ? ' (${_childAge!})' : ''}'
                                : 'Data di nascita: non impostata',
                            style: GoogleFonts.inter(
                              color: _birthDate != null
                                  ? Colors.white
                                  : Colors.grey[500],
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar,
                          color: const Color(0xFFFF0000),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),

            // ── Address ──────────────────────────────────────────────
            _buildSectionCard(
              title: 'Indirizzo',
              icon: Icons.location_on,
              children: [
                _buildRow(
                  label: 'Indirizzo',
                  controller: _addressCtrl,
                  icon: Icons.home,
                ),
                SizedBox(height: 1.5.h),
                _buildRow(
                  label: 'Città',
                  controller: _cityCtrl,
                  icon: Icons.location_city,
                ),
                SizedBox(height: 1.5.h),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildRow(
                        label: 'Provincia',
                        controller: _provinceCtrl,
                        icon: Icons.map,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: _buildRow(
                        label: 'CAP',
                        controller: _capCtrl,
                        icon: Icons.pin,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 3.h),

            // ── Emergency contact ────────────────────────────────────
            _buildSectionCard(
              title: 'Contatto di Emergenza',
              icon: Icons.emergency,
              children: [
                _buildRow(
                  label: 'Nome contatto',
                  controller: _emergencyNameCtrl,
                  icon: Icons.person_pin,
                ),
                SizedBox(height: 1.5.h),
                _buildRow(
                  label: 'Telefono emergenza',
                  controller: _emergencyPhoneCtrl,
                  icon: Icons.phone_in_talk,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            SizedBox(height: 3.h),

            // ── Medical notes ────────────────────────────────────────
            _buildSectionCard(
              title: 'Note Mediche',
              icon: Icons.medical_services,
              children: [
                TextField(
                  controller: _medicalNotesCtrl,
                  maxLines: 4,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Inserisci eventuali note mediche...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFF0000)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),

            // ── Medical Certificate Status ────────────────────────────
            _buildSectionCard(
              title: 'Certificato Medico Sportivo',
              icon: Icons.health_and_safety,
              children: [_buildMedicalCertificateStatus()],
            ),
            SizedBox(height: 3.h),

            // ── Image consent ────────────────────────────────────────
            _buildSectionCard(
              title: 'Liberatoria Immagini',
              icon: Icons.photo_camera,
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: _imageConsent
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _imageConsent
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _imageConsent
                            ? Icons.photo_camera
                            : Icons.no_photography_outlined,
                        color: _imageConsent ? Colors.green : Colors.orange,
                        size: 22,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Liberatoria immagini',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _imageConsent
                                  ? 'Consenso alla pubblicazione immagini: CONCESSO'
                                  : 'Consenso alla pubblicazione immagini: NON CONCESSO',
                              style: GoogleFonts.inter(
                                color: _imageConsent
                                    ? Colors.green[400]
                                    : Colors.orange[400],
                                fontSize: 11.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _imageConsent,
                        activeThumbColor: Colors.green,
                        onChanged: (val) => setState(() => _imageConsent = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),

            // ── Documents upload ─────────────────────────────────────
            _buildSectionCard(
              title: 'Documenti',
              icon: Icons.folder_open,
              children: [_buildDocumentsSection()],
            ),
            SizedBox(height: 4.h),

            // ── Save button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(
                  _isSaving ? 'Salvataggio...' : 'Salva Modifiche',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final name = _childFullName.isNotEmpty ? _childFullName : 'Profilo Minore';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: _imageConsent
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // ── Profile photo with camera button ──────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  color: Colors.blue.withValues(alpha: 0.15),
                ),
                child: _profilePhotoSignedUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18.w),
                        child: Image.network(
                          _profilePhotoSignedUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.child_care,
                            color: Colors.blue[300],
                            size: 28,
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: Colors.blue,
                                strokeWidth: 2,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : Icon(Icons.child_care, color: Colors.blue[300], size: 28),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isUploadingPhoto ? null : _updateProfilePhoto,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: BoxDecoration(
                        color: _isUploadingPhoto
                            ? Colors.grey[700]
                            : const Color(0xFFFF0000),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploadingPhoto
                          ? Padding(
                              padding: EdgeInsets.all(1.5.w),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 3.5.w,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 0.3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Minore',
                        style: GoogleFonts.inter(
                          color: Colors.blue[300],
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_childAge != null) ...[
                      SizedBox(width: 2.w),
                      Icon(Icons.cake, size: 12, color: Colors.grey[500]),
                      SizedBox(width: 1.w),
                      Text(
                        _childAge!,
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Icon(
                      _imageConsent
                          ? Icons.photo_camera
                          : Icons.no_photography_outlined,
                      size: 12,
                      color: _imageConsent
                          ? Colors.green[400]
                          : Colors.orange[400],
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      _imageConsent ? 'Liberatoria OK' : 'No liberatoria',
                      style: GoogleFonts.inter(
                        color: _imageConsent
                            ? Colors.green[400]
                            : Colors.orange[400],
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentInfoCard() {
    final parentName =
        _parentUser?['full_name']?.toString() ?? 'Genitore/Tutore';
    final parentEmail = _parentUser?['email']?.toString() ?? '';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFFFF0000), size: 20),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Genitore/Tutore',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 11.sp,
                  ),
                ),
                Text(
                  parentName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (parentEmail.isNotEmpty)
                  Text(
                    parentEmail,
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 11.sp,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(1.5.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: const Color(0xFFFF0000), size: 16),
              ),
              SizedBox(width: 2.w),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12.sp),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 18),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF0000)),
        ),
      ),
    );
  }

  Widget _buildMedicalCertificateStatus() {
    final certUrl = _child?['medical_certificate_url'] as String?;
    final certPending =
        _child?['medical_certificate_pending'] as bool? ?? false;
    final certUploadedAt =
        _child?['medical_certificate_uploaded_at'] as String?;

    final bool hasCert = certUrl != null && certUrl.isNotEmpty;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusSubtext;

    if (hasCert) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Certificato caricato';
      statusSubtext = certUploadedAt != null
          ? 'Caricato il: ${_formatDate(certUploadedAt)}'
          : 'Documento presente';
    } else if (certPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
      statusText = 'In attesa di caricamento';
      statusSubtext = 'Il genitore ha 30 giorni per caricare il certificato';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Certificato non caricato';
      statusSubtext = 'Nessun certificato medico sportivo presente';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      statusSubtext,
                      style: GoogleFonts.inter(
                        color: statusColor.withValues(alpha: 0.8),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.5.h),
        // Upload button for medical certificate
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUploadingCert ? null : _uploadMedicalCertificate,
            icon: _isUploadingCert
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    hasCert ? Icons.upload_file : Icons.add_circle_outline,
                    size: 18,
                  ),
            label: Text(
              _isUploadingCert
                  ? 'Caricamento...'
                  : hasCert
                  ? 'Sostituisci Certificato'
                  : 'Carica Certificato Medico',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasCert
                  ? Colors.orange.withValues(alpha: 0.8)
                  : const Color(0xFFFF0000),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadMedicalCertificate() async {
    final childId = _child?['id']?.toString();
    if (childId == null) return;

    // Show source picker
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(
              'Carica Certificato Medico',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(
                  icon: Icons.camera_alt,
                  label: 'Fotocamera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                _photoOption(
                  icon: Icons.photo_library,
                  label: 'Galleria',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
            SizedBox(height: 3.h),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (source == ImageSource.camera) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permesso fotocamera necessario'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isUploadingCert = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        // Ask for expiry date
        DateTime? expiryDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          helpText: 'Data scadenza certificato',
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFFF0000),
                onPrimary: Colors.white,
                surface: Color(0xFF1E1E1E),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );

        final bytes = await image.readAsBytes();
        await ChildProfileService.uploadChildMedicalCertificate(
          childProfileId: childId,
          fileBytes: bytes,
          fileName: image.name,
          expiryDate: expiryDate,
        );

        // Re-fetch child to update state
        final freshChild = await SupabaseService.instance.client
            .from('child_profiles')
            .select('*')
            .eq('id', childId)
            .single();

        if (mounted) {
          setState(() {
            _child = Map<String, dynamic>.from(freshChild);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Certificato medico caricato con successo'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento certificato: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCert = false);
    }
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Carica documenti aggiuntivi per il minore (moduli, autorizzazioni, ecc.)',
          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 11.sp),
        ),
        SizedBox(height: 1.5.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUploadingDoc ? null : _uploadDocument,
            icon: _isUploadingDoc
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.upload_file, size: 18),
            label: Text(
              _isUploadingDoc ? 'Caricamento...' : 'Carica Documento',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadDocument() async {
    final childId = _child?['id']?.toString();
    if (childId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Text(
              'Carica Documento',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 3.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(
                  icon: Icons.camera_alt,
                  label: 'Fotocamera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                _photoOption(
                  icon: Icons.photo_library,
                  label: 'Galleria',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
            SizedBox(height: 3.h),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (source == ImageSource.camera) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permesso fotocamera necessario'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isUploadingDoc = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        final userId =
            SupabaseService.instance.client.auth.currentUser?.id ?? 'admin';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final ext = image.name.contains('.')
            ? image.name.split('.').last
            : 'jpg';
        final storagePath =
            'child_documents/$userId/$childId/${timestamp}_documento.$ext';

        await SupabaseService.instance.client.storage
            .from('user_docs')
            .uploadBinary(storagePath, bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento caricato con successo'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento documento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingDoc = false);
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
