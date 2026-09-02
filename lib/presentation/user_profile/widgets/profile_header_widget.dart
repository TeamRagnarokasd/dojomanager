import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/app_export.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/profile_typography.dart';
import '../../../services/supabase_service.dart';
import '../../../services/user_profile_service.dart';

class ProfileHeaderWidget extends StatefulWidget {
  final String? userId;
  final bool isChildProfile;

  const ProfileHeaderWidget({
    Key? key,
    this.userId,
    this.isChildProfile = false,
  }) : super(key: key);

  @override
  State<ProfileHeaderWidget> createState() => _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends State<ProfileHeaderWidget> {
  String? _userAvatar;
  String _userName = '';
  String _userRole = '';
  String _roleTitle = ''; // 🎯 NEW: Display role from role_title column
  bool _isLoading = false;
  bool _isCurrentUser = true;
  final ImagePicker _picker = ImagePicker();
  final UserProfileService _userProfileService = UserProfileService();

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUser();
    _loadUserProfile();
  }

  Future<void> _checkIfCurrentUser() async {
    try {
      final client = SupabaseService.instance.client;
      final currentUser = client.auth.currentUser;

      if (currentUser != null && widget.userId != null) {
        if (mounted) {
          setState(() {
            _isCurrentUser = currentUser.id == widget.userId;
          });
        }
      } else if (widget.userId == null) {
        if (mounted) {
          setState(() {
            _isCurrentUser = true;
          });
        }
      }
    } catch (e) {
      print('Error checking if current user: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final client = SupabaseService.instance.client;

      String? targetUserId = widget.userId ?? client.auth.currentUser?.id;

      if (targetUserId == null) {
        print('❌ Error: No user ID available');
        return;
      }

      // 🎯 FIX: If this is a child profile, query child_profiles table instead
      if (widget.isChildProfile) {
        final response = await client
            .from('child_profiles')
            .select('first_name, last_name, full_name, profile_photo_url')
            .eq('id', targetUserId)
            .maybeSingle();

        if (mounted) {
          setState(() {
            final firstName = response?['first_name'] as String? ?? '';
            final lastName = response?['last_name'] as String? ?? '';
            final fullName =
                response?['full_name'] as String? ??
                '$firstName $lastName'.trim();
            _userName = fullName.isNotEmpty ? fullName : 'Profilo Minore';
            _userRole = 'Allievo';
            _roleTitle = 'Minore';
            _userAvatar = response?['profile_photo_url'];
            _isCurrentUser = false;
          });
        }
        return;
      }

      final response = await client
          .from('user_profiles')
          .select(
            'first_name, last_name, full_name, role, role_title, profile_image_url',
          )
          .eq('id', targetUserId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userName = response?['full_name'] ?? 'common.user'.tr();
          _userRole = _formatRole(response?['role'] ?? 'student');
          _roleTitle =
              response?['role_title'] ??
              'profile.default_student_role'
                  .tr(); // 🎯 NEW: Load role_title from database
          _userAvatar = response?['profile_image_url'];
        });

        if (response != null) {
          print(
            '✅ Profile loaded: ${response['full_name']}, role: $_roleTitle, avatar: ${_userAvatar != null ? "exists" : "null"}',
          );
        }
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'student':
        return 'roles.team_member'.tr();
      case 'instructor':
        return 'roles.instructor'.tr();
      case 'admin':
        return 'roles.admin'.tr();
      case 'principal_admin':
        return 'roles.principal_admin'.tr();
      default:
        return 'roles.team_member'.tr();
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
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 3),
                  color: Colors.grey[800],
                ),
                child: _userAvatar != null && _userAvatar!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30.w),
                        child: Image.network(
                          _userAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: Colors.red,
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      )
                    : _buildDefaultAvatar(),
              ),
              if (_isCurrentUser)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLoading ? null : _updateProfilePhoto,
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          color: _isLoading ? Colors.grey[700] : Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(77),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? Padding(
                                padding: EdgeInsets.all(2.w),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 6.w,
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          // 🎯 NEW: Display role_title BEFORE name as requested
          Text(
            _roleTitle.isEmpty
                ? 'profile.default_student_role'.tr()
                : _roleTitle,
            style: GoogleFonts.inter(
              color: Colors.red,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 0.5.h),
          Text(
            _userName.isEmpty ? 'common.loading'.tr() : _userName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
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
                'profile.disciplines_tagline'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: ProfileTypography.caption,
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
      width: 30.w,
      height: 30.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[700],
      ),
      child: Icon(Icons.person, color: Colors.grey[400], size: 15.w),
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
              'profile.update_profile_photo'.tr(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'profile.choose_photo_method'.tr(),
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: ProfileTypography.subtitle,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _photoOption(
                  icon: Icons.camera_alt,
                  label: 'profile.take_photo'.tr(),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _photoOption(
                  icon: Icons.photo_library,
                  label: 'profile.choose_from_gallery'.tr(),
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
                fontSize: ProfileTypography.subtitle,
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
              content: Text('profile.camera_permission_required'.tr()),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'common.settings'.tr(),
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
    setState(() => _isLoading = true);

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (image != null) {
        await _uploadProfileImage(image);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.image_selection_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadProfileImage(XFile image) async {
    try {
      print('🔄 Starting profile photo upload...');

      final result = await _userProfileService.uploadProfilePhoto(image);

      if (!mounted) return;

      if (result['success'] == true) {
        await _loadUserProfile();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    result['message'] ?? 'profile.photo_updated_success'.tr(),
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'profile.photo_update_error'.tr(),
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'common.retry'.tr(),
              textColor: Colors.white,
              onPressed: () => _updateProfilePhoto(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.upload_unexpected_error'.tr()),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'common.retry'.tr(),
              textColor: Colors.white,
              onPressed: () => _updateProfilePhoto(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
