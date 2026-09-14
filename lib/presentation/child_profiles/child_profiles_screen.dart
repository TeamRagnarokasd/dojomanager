import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../services/child_profile_service.dart';
import '../../services/terms_document_service.dart';
import './widgets/child_terms_acceptance_dialog.dart';

/// Screen for managing child/minor profiles linked to the adult guardian.
class ChildProfilesScreen extends StatefulWidget {
  const ChildProfilesScreen({Key? key}) : super(key: key);

  @override
  State<ChildProfilesScreen> createState() => _ChildProfilesScreenState();
}

class _ChildProfilesScreenState extends State<ChildProfilesScreen> {
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  bool _hasDiscount = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final children = await ChildProfileService.getChildProfiles();
      final hasDiscount =
          await ChildProfileService.guardianHasActiveSubscription();
      if (mounted) {
        setState(() {
          _children = children;
          _hasDiscount = hasDiscount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddChildForm({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ChildProfileForm(
        existing: existing,
        onSaved: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }

  Future<void> _deleteChild(Map<String, dynamic> child) async {
    final name = child['full_name'] as String? ?? 'questo profilo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Rimuovi Profilo',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Vuoi rimuovere il profilo di $name? Gli abbonamenti associati rimarranno nello storico.',
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annulla',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Rimuovi',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ChildProfileService.deleteChildProfile(child['id'] as String);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profilo rimosso'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Profili Figli/Minori',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFFF0000)),
            tooltip: 'Aggiungi figlio/a',
            onPressed: () => _showAddChildForm(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF0000)),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Discount banner
                  if (_hasDiscount)
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 2.h),
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              '🎉 Hai un abbonamento attivo! Sconto "Total Submission Kids" disponibile: €45 invece di €50.',
                              style: GoogleFonts.inter(
                                color: Colors.green[300],
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Info box
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(3.w),
                    margin: EdgeInsets.only(bottom: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFFF0000),
                              size: 18,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'Come funziona',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          '• Aggiungi i profili dei tuoi figli/minori\n'
                          '• Usa il selettore in dashboard per passare al profilo del figlio\n'
                          '• Gli acquisti fatti nel profilo figlio vengono associati a lui\n'
                          '• Le ricevute sono sempre intestate a te (adulto pagante)',
                          style: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontSize: 11.sp,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Children list
                  if (_children.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        child: Column(
                          children: [
                            Icon(
                              Icons.child_care,
                              color: Colors.grey[600],
                              size: 48,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Nessun profilo figlio aggiunto',
                              style: GoogleFonts.inter(
                                color: Colors.grey[500],
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            ElevatedButton.icon(
                              onPressed: () => _showAddChildForm(),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                'Aggiungi figlio/a',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF0000),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'Profili Registrati (${_children.length})',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    ..._children.map(
                      (child) => _ChildCard(
                        child: child,
                        isActive: ChildProfileService.activeChildProfileId ==
                            child['id'],
                        onEdit: () => _showAddChildForm(existing: child),
                        onDelete: () => _deleteChild(child),
                        onPhotoUpdated: _loadData,
                        onSwitch: () async {
                          final isCurrentlyActive =
                              ChildProfileService.activeChildProfileId ==
                                  child['id'];
                          await ChildProfileService.setActiveProfile(
                            isCurrentlyActive ? null : child['id'] as String,
                          );
                          setState(() {});
                        },
                      ),
                    ),
                    SizedBox(height: 2.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddChildForm(),
                        icon: const Icon(Icons.add, color: Color(0xFFFF0000)),
                        label: Text(
                          'Aggiungi altro figlio/a',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF0000),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFF0000)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ─── Child Card ──────────────────────────────────────────────────────────────

class _ChildCard extends StatefulWidget {
  final Map<String, dynamic> child;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSwitch;
  final VoidCallback? onPhotoUpdated;

  const _ChildCard({
    required this.child,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
    required this.onSwitch,
    this.onPhotoUpdated,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  String? _signedPhotoUrl;
  bool _isUploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _ChildCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPath = widget.child['profile_photo_url'] as String?;
    final oldPath = oldWidget.child['profile_photo_url'] as String?;
    if (newPath != oldPath) {
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    final storagePath = widget.child['profile_photo_url'] as String?;
    if (storagePath != null && storagePath.isNotEmpty) {
      final url = await ChildProfileService.getChildProfilePhotoUrl(
        storagePath,
      );
      if (mounted) setState(() => _signedPhotoUrl = url);
    }
  }

  Future<void> _updateProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
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
      if (!kIsWeb) {
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
        final childId = widget.child['id'] as String;
        final bytes = await image.readAsBytes();
        final storagePath = await ChildProfileService.uploadChildProfilePhoto(
          childProfileId: childId,
          fileBytes: bytes,
          fileName: image.name,
        );
        final signedUrl = await ChildProfileService.getChildProfilePhotoUrl(
          storagePath,
        );
        if (mounted) {
          setState(() => _signedPhotoUrl = signedUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profilo aggiornata con successo'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onPhotoUpdated?.call();
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
    final child = widget.child;
    final name = child['full_name'] as String? ??
        '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim();
    final birthDate = child['birth_date'] as String? ?? '';
    final taxCode = child['tax_code'] as String? ?? '';
    final imageConsent = child['image_consent'] as bool? ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: widget.isActive
            ? const Color(0xFFFF0000).withValues(alpha: 0.1)
            : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isActive
              ? const Color(0xFFFF0000).withValues(alpha: 0.5)
              : Colors.grey[800]!,
          width: widget.isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Profile photo with camera button ──────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isActive
                          ? const Color(0xFFFF0000).withValues(alpha: 0.2)
                          : Colors.grey[800],
                      border: Border.all(
                        color: widget.isActive
                            ? const Color(0xFFFF0000).withValues(alpha: 0.5)
                            : Colors.grey[700]!,
                        width: 1.5,
                      ),
                    ),
                    child: _signedPhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12.w),
                            child: Image.network(
                              _signedPhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.child_care,
                                color: widget.isActive
                                    ? const Color(0xFFFF0000)
                                    : Colors.grey[400],
                                size: 20,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.child_care,
                            color: widget.isActive
                                ? const Color(0xFFFF0000)
                                : Colors.grey[400],
                            size: 20,
                          ),
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _updateProfilePhoto,
                      child: Container(
                        width: 5.w,
                        height: 5.w,
                        decoration: BoxDecoration(
                          color: _isUploadingPhoto
                              ? Colors.grey[700]
                              : const Color(0xFFFF0000),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: _isUploadingPhoto
                            ? Padding(
                                padding: EdgeInsets.all(1.w),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 2.5.w,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (birthDate.isNotEmpty)
                      Text(
                        'Nato/a il: $birthDate',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 11.sp,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.isActive)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 2.w,
                    vertical: 0.4.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ATTIVO',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFF0000),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (taxCode.isNotEmpty) ...[
            SizedBox(height: 1.h),
            Text(
              'C.F.: $taxCode',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 11.sp,
              ),
            ),
          ],
          SizedBox(height: 1.h),
          // Image consent badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: imageConsent
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: imageConsent
                    ? Colors.green.withValues(alpha: 0.4)
                    : Colors.orange.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  imageConsent
                      ? Icons.photo_camera
                      : Icons.no_photography_outlined,
                  color: imageConsent ? Colors.green[400] : Colors.orange[400],
                  size: 14,
                ),
                SizedBox(width: 1.w),
                Text(
                  imageConsent
                      ? 'Liberatoria immagini: ACCETTATA'
                      : 'Liberatoria immagini: NON ACCETTATA',
                  style: GoogleFonts.inter(
                    color:
                        imageConsent ? Colors.green[300] : Colors.orange[300],
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onSwitch,
                  icon: Icon(
                    widget.isActive ? Icons.person : Icons.swap_horiz,
                    size: 14,
                    color:
                        widget.isActive ? Colors.grey : const Color(0xFFFF0000),
                  ),
                  label: Text(
                    widget.isActive ? 'Torna Adulto' : 'Passa a questo',
                    style: GoogleFonts.inter(
                      color: widget.isActive
                          ? Colors.grey
                          : const Color(0xFFFF0000),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: widget.isActive
                          ? Colors.grey[700]!
                          : const Color(0xFFFF0000),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 1.h),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              IconButton(
                onPressed: widget.onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
                tooltip: 'Modifica',
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
                tooltip: 'Rimuovi',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Child Profile Form ───────────────────────────────────────────────────────

class _ChildProfileForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _ChildProfileForm({this.existing, required this.onSaved});

  @override
  State<_ChildProfileForm> createState() => _ChildProfileFormState();
}

class _ChildProfileFormState extends State<_ChildProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _taxCodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _medicalNotesCtrl = TextEditingController();
  DateTime? _birthDate;
  bool _isSaving = false;

  // Medical certificate
  final ImagePicker _picker = ImagePicker();
  Uint8List? _certBytes;
  String? _certFileName;
  bool _certUploaded = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _firstNameCtrl.text = e['first_name'] as String? ?? '';
      _lastNameCtrl.text = e['last_name'] as String? ?? '';
      _birthPlaceCtrl.text = e['birth_place'] as String? ?? '';
      _taxCodeCtrl.text =
          e['tax_code'] as String? ?? e['codice_fiscale'] as String? ?? '';
      _phoneCtrl.text = e['phone'] as String? ?? '';
      _emailCtrl.text = e['email'] as String? ?? '';
      _addressCtrl.text = e['address_line'] as String? ?? '';
      _cityCtrl.text = e['city'] as String? ?? '';
      _provinceCtrl.text = e['province'] as String? ?? '';
      _capCtrl.text = e['cap'] as String? ?? '';
      _emergencyNameCtrl.text = e['emergency_contact_name'] as String? ?? '';
      _emergencyPhoneCtrl.text = e['emergency_contact_phone'] as String? ?? '';
      _medicalNotesCtrl.text = e['medical_notes'] as String? ?? '';
      final bd = e['birth_date'] as String?;
      if (bd != null && bd.isNotEmpty) {
        try {
          _birthDate = DateTime.parse(bd);
        } catch (_) {}
      }
      // Show existing cert status
      _certUploaded =
          (e['medical_certificate_url'] as String?)?.isNotEmpty == true;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _taxCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _capCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _medicalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2010),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFFF0000)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickCertificate(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _certBytes = bytes;
          _certFileName = image.name;
          _certUploaded = false; // new file selected, not yet saved
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore selezione immagine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final childFullName =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

    // For new profiles only: show terms acceptance dialog
    bool imageConsent = false;
    if (!_isEditing) {
      final result = await showDialog<ChildTermsResult>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ChildTermsAcceptanceDialog(childName: childFullName),
      );
      if (result == null || !result.accepted) return;
      imageConsent = result.imageConsent;
    }

    // If no certificate provided, show 30-day warning dialog
    if (_certBytes == null && !_certUploaded) {
      final proceed = await _showNoCertificateWarning();
      if (!proceed) return;
    }

    setState(() => _isSaving = true);
    try {
      String? savedChildId;

      if (_isEditing) {
        final updated = await ChildProfileService.updateChildProfile(
          childProfileId: widget.existing!['id'] as String,
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          birthDate: _birthDate,
          birthPlace: _birthPlaceCtrl.text,
          taxCode: _taxCodeCtrl.text,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          addressLine: _addressCtrl.text,
          city: _cityCtrl.text,
          province: _provinceCtrl.text,
          cap: _capCtrl.text,
          emergencyContactName: _emergencyNameCtrl.text,
          emergencyContactPhone: _emergencyPhoneCtrl.text,
          medicalNotes: _medicalNotesCtrl.text,
        );
        savedChildId = updated['id'] as String?;
      } else {
        final created = await ChildProfileService.createChildProfile(
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          birthDate: _birthDate,
          birthPlace: _birthPlaceCtrl.text,
          taxCode: _taxCodeCtrl.text,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          addressLine: _addressCtrl.text,
          city: _cityCtrl.text,
          province: _provinceCtrl.text,
          cap: _capCtrl.text,
          emergencyContactName: _emergencyNameCtrl.text,
          emergencyContactPhone: _emergencyPhoneCtrl.text,
          medicalNotes: _medicalNotesCtrl.text,
          imageConsent: imageConsent,
        );
        savedChildId = created['id'] as String?;

        // Generate and save the terms acceptance document for the guardian
        try {
          final guardianProfile =
              await ChildProfileService.getGuardianProfile();
          final guardianId = guardianProfile?['id'] as String? ??
              guardianProfile?['user_id'] as String? ??
              '';
          final guardianName =
              '${guardianProfile?['first_name'] ?? ''} ${guardianProfile?['last_name'] ?? ''}'
                  .trim();
          final guardianEmail = guardianProfile?['email'] as String? ?? '';

          if (guardianId.isNotEmpty) {
            await TermsDocumentService().saveChildTermsAcceptanceDocument(
              guardianUserId: guardianId,
              guardianName:
                  guardianName.isNotEmpty ? guardianName : 'Genitore/Tutore',
              guardianEmail: guardianEmail,
              childName: childFullName,
              imageConsent: imageConsent,
            );
          }
        } catch (docError) {
          debugPrint('Could not generate child terms document: $docError');
        }
      }

      // Upload certificate if selected
      if (_certBytes != null && savedChildId != null) {
        try {
          await ChildProfileService.uploadChildMedicalCertificate(
            childProfileId: savedChildId,
            fileBytes: _certBytes!,
            fileName: _certFileName ?? 'certificato.jpg',
          );
        } catch (certError) {
          debugPrint('Certificate upload failed: $certError');
          // Mark as pending if upload failed
          await ChildProfileService.markChildCertificatePending(savedChildId);
        }
      } else if (!_certUploaded && savedChildId != null) {
        // No certificate: mark as pending (30-day grace period)
        await ChildProfileService.markChildCertificatePending(savedChildId);
      }

      widget.onSaved();
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

  Future<bool> _showNoCertificateWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.orange.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[400], size: 26),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Certificato Medico Mancante',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Non hai caricato il certificato medico sportivo.\n\n'
          'Puoi completare la registrazione ora, ma hai 30 giorni per caricarlo. '
          'Trascorso questo periodo, il profilo del minore verrà sospeso fino al caricamento del documento.',
          style: GoogleFonts.inter(
            color: Colors.grey[300],
            fontSize: 12.sp,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Carica ora',
              style: GoogleFonts.inter(
                color: const Color(0xFFFF0000),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Continua senza',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
        decoration: InputDecoration(
          labelText: label + (required ? ' *' : ''),
          labelStyle: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 12.sp,
          ),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 3.w,
            vertical: 1.5.h,
          ),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 10.w,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                _isEditing ? 'Modifica Profilo Figlio' : 'Aggiungi Figlio/a',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),

              // Personal Info
              Text(
                'Dati Personali',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF0000),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1.h),
              Row(
                children: [
                  Expanded(
                    child: _field(_firstNameCtrl, 'Nome', required: true),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _field(_lastNameCtrl, 'Cognome', required: true),
                  ),
                ],
              ),
              // Birth date picker
              GestureDetector(
                onTap: _pickBirthDate,
                child: Container(
                  margin: EdgeInsets.only(bottom: 1.5.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 1.5.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        _birthDate != null
                            ? 'Data di nascita: ${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                            : 'Data di nascita (opzionale)',
                        style: GoogleFonts.inter(
                          color: _birthDate != null
                              ? Colors.white
                              : Colors.grey[400],
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _field(_birthPlaceCtrl, 'Luogo di nascita'),
              _field(_taxCodeCtrl, 'Codice Fiscale'),
              _field(_phoneCtrl, 'Telefono', keyboardType: TextInputType.phone),
              _field(
                _emailCtrl,
                'Email',
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: 1.h),
              Text(
                'Residenza',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF0000),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1.h),
              _field(_addressCtrl, 'Indirizzo'),
              Row(
                children: [
                  Expanded(flex: 2, child: _field(_cityCtrl, 'Città')),
                  SizedBox(width: 2.w),
                  Expanded(child: _field(_provinceCtrl, 'Prov.')),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: _field(
                      _capCtrl,
                      'CAP',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 1.h),
              Text(
                'Contatto Emergenza',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF0000),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1.h),
              _field(_emergencyNameCtrl, 'Nome contatto emergenza'),
              _field(
                _emergencyPhoneCtrl,
                'Telefono emergenza',
                keyboardType: TextInputType.phone,
              ),

              SizedBox(height: 1.h),
              Text(
                'Note Mediche',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF0000),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1.h),
              Padding(
                padding: EdgeInsets.only(bottom: 1.5.h),
                child: TextFormField(
                  controller: _medicalNotesCtrl,
                  maxLines: 3,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13.sp,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Note mediche / allergie (opzionale)',
                    labelStyle: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 12.sp,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 1.5.h,
                    ),
                  ),
                ),
              ),

              // ── Certificato Medico ──────────────────────────────────
              SizedBox(height: 1.h),
              Text(
                'Certificato Medico Sportivo',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFF0000),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 1.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _certBytes != null || _certUploaded
                        ? Colors.green.withValues(alpha: 0.6)
                        : Colors.grey[700]!,
                    width: _certBytes != null || _certUploaded ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_certUploaded && _certBytes == null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[400],
                            size: 20,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'Certificato già caricato',
                              style: GoogleFonts.inter(
                                color: Colors.green[400],
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                    ] else if (_certBytes != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[400],
                            size: 20,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'Certificato selezionato: ${_certFileName ?? ''}',
                              style: GoogleFonts.inter(
                                color: Colors.green[400],
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            Icons.upload_file,
                            color: Colors.grey[500],
                            size: 20,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'Nessun certificato caricato',
                              style: GoogleFonts.inter(
                                color: Colors.grey[500],
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _pickCertificate(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: Text(
                              'Fotocamera',
                              style: GoogleFonts.inter(fontSize: 11.sp),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF0000),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 1.h),
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _pickCertificate(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: Text(
                              'Galleria',
                              style: GoogleFonts.inter(fontSize: 11.sp),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF0000),
                              side: const BorderSide(color: Color(0xFFFF0000)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 1.h),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange[400],
                            size: 14,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              'Facoltativo ora: hai 30 giorni per caricarlo, '
                              'altrimenti il profilo verrà sospeso.',
                              style: GoogleFonts.inter(
                                color: Colors.orange[300],
                                fontSize: 10.sp,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF0000),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Salva Modifiche' : 'Aggiungi Figlio/a',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
