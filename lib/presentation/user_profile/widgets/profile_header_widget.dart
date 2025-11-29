import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../constants/app_constants.dart';
import '../../../services/supabase_service.dart';
import '../../../services/user_profile_service.dart';

class ProfileHeaderWidget extends StatefulWidget {
  const ProfileHeaderWidget({Key? key}) : super(key: key);

  @override
  State<ProfileHeaderWidget> createState() => _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends State<ProfileHeaderWidget> {
  String? _userAvatar;
  String _userName = '';
  String _userRole = '';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final UserProfileService _userProfileService = UserProfileService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;

      if (user == null) return;

      final response = await client
          .from('user_profiles')
          .select('full_name, role, profile_image_url')
          .eq('id', user.id)
          .single();

      setState(() {
        _userName = response['full_name'] ?? 'Utente';
        _userRole = _formatRole(response['role'] ?? 'student');
        _userAvatar = response['profile_image_url'];
      });
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'student':
        return 'Team Ragnarok Member';
      case 'instructor':
        return 'Istruttore';
      case 'admin':
        return 'Amministratore';
      case 'principal_admin':
        return 'Amministratore Principale';
      default:
        return 'Team Ragnarok Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withAlpha(51), Colors.black87],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(color: Colors.red.withAlpha(77)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 25.w,
                height: 25.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 3),
                  color: Colors.grey[800],
                ),
                child: _userAvatar != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(25.w),
                        child: Image.network(
                          _userAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        ),
                      )
                    : _buildDefaultAvatar(),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isLoading ? null : _updateProfilePhoto,
                  child: Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey : Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _isLoading
                        ? Padding(
                            padding: EdgeInsets.all(1.w),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 4.w,
                          ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            _userName.isEmpty ? 'Caricamento...' : _userName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _userRole,
            style: GoogleFonts.inter(
              color: Colors.red,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                AppConstants.teamLogo,
                width: 6.w,
                height: 3.h,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 2.w),
              Text(
                'MMA • BJJ • SAMBO • GRAPPLING',
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 25.w,
      height: 25.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[700],
      ),
      child: Icon(
        Icons.person,
        color: Colors.grey[400],
        size: 12.w,
      ),
    );
  }

  Future<void> _updateProfilePhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aggiorna Foto Profilo',
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
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _photoOption(
                  icon: Icons.photo_library,
                  label: 'Galleria',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _photoOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 15.w,
            height: 15.w,
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(51),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red),
            ),
            child: Icon(
              icon,
              color: Colors.red,
              size: 6.w,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11.sp,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);

    // Request permissions
    if (source == ImageSource.camera) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permesso fotocamera necessario'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadProfileImage(image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante la selezione dell\'immagine'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadProfileImage(XFile image) async {
    try {
      // Use the improved upload service
      final result = await _userProfileService.uploadProfilePhoto(image);

      if (result['success'] == true) {
        setState(() {
          _userAvatar = result['profile_image_url'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result['message'] ?? 'Foto profilo aggiornata con successo!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ??
                'Errore durante l\'aggiornamento della foto'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Riprova',
              onPressed: () => _updateProfilePhoto(),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore imprevisto durante il caricamento'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Riprova',
            onPressed: () => _updateProfilePhoto(),
          ),
        ),
      );
    }
  }
}
