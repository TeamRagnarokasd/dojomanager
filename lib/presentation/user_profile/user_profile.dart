import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../constants/app_constants.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/child_profile_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/main_navigation_wrapper.dart';
import './widgets/account_security_widget.dart';
import './widgets/admin_user_credentials_widget.dart';
import './widgets/emergency_contacts_widget.dart';
import './widgets/medical_certificate_status_widget.dart';
import './widgets/personal_info_widget.dart';
import './widgets/profile_header_widget.dart';
import './widgets/settings_section_widget.dart';
import './widgets/subscription_details_widget.dart';
import './widgets/user_documents_widget.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({Key? key}) : super(key: key);

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  bool _notificationsEnabled = true;
  bool _autoRenewal = true;
  String _selectedTheme = 'dark';

  Map<String, dynamic>? _viewedUser;
  bool _isViewingOtherUser = false;
  bool _isLoading = true;
  String? _viewedUserId;
  bool _hasInitialized = false;
  bool _isPrincipalAdmin = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasInitialized) {
      _hasInitialized = true;
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;

      // Check if current viewer is principal admin
      final client = SupabaseService.instance.client;
      final currentAuthUser = client.auth.currentUser;
      if (currentAuthUser != null) {
        final isEmailAdmin =
            currentAuthUser.email == 'lutadordeeliteravenna@gmail.com';
        if (!isEmailAdmin) {
          try {
            final profile = await client
                .from('user_profiles')
                .select('role')
                .eq('id', currentAuthUser.id)
                .maybeSingle();
            if (mounted) {
              setState(() {
                _isPrincipalAdmin =
                    isEmailAdmin || profile?['role'] == 'principal_admin';
              });
            }
          } catch (_) {}
        } else {
          if (mounted) setState(() => _isPrincipalAdmin = true);
        }
      }

      if (args != null && args is Map<String, dynamic>) {
        // 🎯 CRITICAL FIX: Ensure user ID is properly extracted from arguments
        if (mounted) {
          setState(() {
            _viewedUser = args;
            _viewedUserId = args['id'] as String?;
            _isViewingOtherUser = true;
            _isLoading = false;
          });
        }

        // 🎯 DEBUG: Log the exact user ID being viewed
        print('🔍 Admin viewing user ID: $_viewedUserId');
        print('🔍 User data from args: ${args.keys.toList()}');
      } else {
        // 🎯 FIX 1: Check if a child profile is active — if so, load child data
        if (ChildProfileService.isChildProfileActive) {
          await _loadActiveChildProfile();
        } else {
          await _loadCurrentUserProfile();
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Loads the currently active child profile from the child_profiles table.
  Future<void> _loadActiveChildProfile() async {
    final childId = ChildProfileService.activeChildProfileId;
    if (childId == null) {
      await _loadCurrentUserProfile();
      return;
    }
    try {
      final client = SupabaseService.instance.client;
      final childData = await client
          .from('child_profiles')
          .select('*')
          .eq('id', childId)
          .maybeSingle();

      if (childData != null) {
        // Build a display-compatible map from child_profiles fields
        final firstName = childData['first_name'] as String? ?? '';
        final lastName = childData['last_name'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        final displayData = <String, dynamic>{
          ...childData,
          'id': childId,
          'full_name': fullName.isNotEmpty ? fullName : 'Profilo Minore',
          'role': 'student',
          'is_child_profile': true,
        };
        if (mounted) {
          setState(() {
            _viewedUser = displayData;
            _viewedUserId = childId;
            _isViewingOtherUser = false;
            _isLoading = false;
          });
        }
      } else {
        // Child not found, fall back to adult profile
        await _loadCurrentUserProfile();
      }
    } catch (e) {
      print('❌ Error loading child profile: $e');
      await _loadCurrentUserProfile();
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    final client = SupabaseService.instance.client;
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // 🎯 DEBUG: Log current user viewing own profile
      print('🔍 User viewing own profile: ${currentUser.id}');

      final profileData = await client
          .from('user_profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (profileData != null) {
        if (mounted) {
          setState(() {
            _viewedUser = profileData;
            _viewedUserId = currentUser.id;
            _isViewingOtherUser = false;
            _isLoading = false;
          });
        }
        return;
      }

      // No profile row: create minimal profile for authenticated user (e.g. student created outside registration)
      print(
        '⚠️ No user_profiles row for ${currentUser.id}, creating minimal profile',
      );
      final email = currentUser.email ?? '';
      final fullName =
          currentUser.userMetadata?['full_name'] as String? ??
          email.split('@').first;
      try {
        await client.from('user_profiles').upsert({
          'id': currentUser.id,
          'email': email,
          'full_name': fullName,
          'role': 'student',
          'status': 'approved',
          'is_active': true,
        }, onConflict: 'id');
      } catch (insertError) {
        print('⚠️ Could not create profile row: $insertError');
      }

      // Retry fetch (either we just created it or we use fallback below)
      final retryData = await client
          .from('user_profiles')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _viewedUser =
              retryData ??
              {
                'id': currentUser.id,
                'email': email,
                'full_name': fullName,
                'role': 'student',
                'status': 'approved',
                'is_active': true,
              };
          _viewedUserId = currentUser.id;
          _isViewingOtherUser = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading current user profile: $e');
      if (mounted) {
        setState(() {
          _viewedUserId = currentUser.id;
          _viewedUser = {
            'id': currentUser.id,
            'email': currentUser.email ?? '',
            'full_name':
                currentUser.userMetadata?['full_name'] as String? ??
                (currentUser.email ?? '').split('@').first,
            'role': 'student',
            'status': 'approved',
            'is_active': true,
          };
          _isViewingOtherUser = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'profile.title'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20.sp < 18 ? 18 : 20.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: _isViewingOtherUser,
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    // 🎯 CRITICAL FIX: Ensure userId is never null when passed to child widgets
    final effectiveUserId = _viewedUserId;

    if (effectiveUserId == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'profile.title'.tr(),
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          automaticallyImplyLeading: _isViewingOtherUser,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              SizedBox(height: 2.h),
              Text(
                'profile.user_id_unavailable'.tr(),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 16.sp),
              ),
              SizedBox(height: 2.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('common.go_back'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    final bool _isChildProfile = _viewedUser?['is_child_profile'] == true;

    return MainNavigationWrapper(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            _isViewingOtherUser
                ? 'profile.title_with_name'.tr(
                    namedArgs: {
                      'name':
                          _viewedUser?['full_name'] as String? ??
                          'common.user'.tr(),
                    },
                  )
                : _isChildProfile
                ? 'Profilo Minore - ${_viewedUser?['full_name'] ?? ''}'
                : 'profile.title'.tr(),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20.sp < 18 ? 18 : 20.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.black,
          elevation: 0,
          automaticallyImplyLeading: _isViewingOtherUser,
          actions: [
            if (_isViewingOtherUser && _isPrincipalAdmin)
              IconButton(
                onPressed: _showPasspartoutDialog,
                icon: Icon(
                  Icons.key,
                  color: _viewedUser?['booking_passpartout'] == true
                      ? Colors.amber
                      : Colors.grey[500],
                  size: 22,
                ),
                tooltip: _viewedUser?['booking_passpartout'] == true
                    ? 'Passpartout ATTIVO'
                    : 'Passpartout DISATTIVO',
              ),
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
            children: [
              // 🎯 CRITICAL: Pass non-null userId to all child widgets
              ProfileHeaderWidget(
                userId: effectiveUserId,
                isChildProfile: _isChildProfile,
              ),
              SizedBox(height: 3.h),
              PersonalInfoWidget(
                userId: effectiveUserId,
                isChildProfile: _isChildProfile,
              ),
              SizedBox(height: 3.h),
              MedicalCertificateStatusWidget(userId: effectiveUserId),
              SizedBox(height: 3.h),
              UserDocumentsWidget(userId: effectiveUserId),
              SizedBox(height: 3.h),
              SubscriptionDetailsWidget(
                userId: effectiveUserId,
                autoRenewal: _autoRenewal,
                onAutoRenewalChanged: (value) =>
                    setState(() => _autoRenewal = value),
                isAdminView: _isViewingOtherUser,
              ),
              SizedBox(height: 3.h),
              // Child profiles section (only for own adult profile, not admin view, not child profile view)
              if (!_isViewingOtherUser && !_isChildProfile)
                _buildChildProfilesSection(),
              if (!_isViewingOtherUser && !_isChildProfile)
                SizedBox(height: 3.h),
              if (!_isViewingOtherUser && !_isChildProfile)
                SettingsSectionWidget(
                  notificationsEnabled: _notificationsEnabled,
                  onNotificationChanged: (value) =>
                      setState(() => _notificationsEnabled = value),
                ),
              if (!_isViewingOtherUser && !_isChildProfile)
                SizedBox(height: 3.h),
              EmergencyContactsWidget(userId: effectiveUserId),
              SizedBox(height: 3.h),
              if (!_isViewingOtherUser && !_isChildProfile)
                AccountSecurityWidget(),
              if (!_isViewingOtherUser && !_isChildProfile)
                SizedBox(height: 3.h),
              // Admin: show credential editor when viewing another user's profile
              if (_isViewingOtherUser)
                AdminUserCredentialsWidget(
                  targetUserId: effectiveUserId,
                  targetUserEmail: _viewedUser?['email']?.toString() ?? '',
                  targetUserName:
                      _viewedUser?['full_name']?.toString() ?? 'Utente',
                ),
              if (_isViewingOtherUser) SizedBox(height: 3.h),
              if (!_isViewingOtherUser && !_isChildProfile)
                _buildLogoutButton(),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChildProfilesSection() {
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
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.child_care,
                  color: Color(0xFFFF0000),
                  size: 20,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profili Figli/Minori',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Gestisci i profili dei tuoi figli',
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.childProfiles);
              },
              icon: const Icon(Icons.manage_accounts, size: 18),
              label: Text(
                'Gestisci Profili Figli',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF0000),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showLogoutDialog(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
          ),
        ),
        child: Text(
          'common.logout'.tr(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        title: Text(
          'auth.confirm_logout_title'.tr(),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'auth.confirm_logout_message'.tr(),
          style: GoogleFonts.inter(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            child: Text(
              'common.logout'.tr(),
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      await AuthService.instance.logout();
    } catch (error) {
      print('Logout error: $error');
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _togglePasspartout() async {
    if (_viewedUserId == null) return;
    final currentValue = _viewedUser?['booking_passpartout'] == true;
    final newValue = !currentValue;
    try {
      final client = SupabaseService.instance.client;
      await client
          .from('user_profiles')
          .update({'booking_passpartout': newValue})
          .eq('id', _viewedUserId!);
      // Log activity
      try {
        await client.from('admin_activity_log').insert({
          'admin_id': client.auth.currentUser?.id,
          'action_type': 'PASSPARTOUT_UPDATE',
          'description':
              'Passpartout prenotazione ${newValue ? 'abilitato' : 'disabilitato'} per ${_viewedUser?['full_name'] ?? _viewedUserId}',
          'target_user_id': _viewedUserId,
          'metadata': {
            'passpartout_enabled': newValue,
            'updated_at': DateTime.now().toIso8601String(),
          },
        });
      } catch (_) {}
      // Refresh local state
      if (mounted) {
        setState(() {
          _viewedUser = {...?_viewedUser, 'booking_passpartout': newValue};
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? "🗝️ Passpartout abilitato: l'utente può prenotare senza abbonamento"
                  : "🔒 Passpartout disabilitato",
            ),
            backgroundColor: newValue ? Colors.amber[800] : Colors.grey[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Errore nell'aggiornamento del passpartout"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPasspartoutDialog() {
    final hasPasspartout = _viewedUser?['booking_passpartout'] == true;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            Icon(Icons.key, color: hasPasspartout ? Colors.amber : Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'Passpartout Prenotazione',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Utente: ${_viewedUser?['full_name'] ?? 'N/A'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasPasspartout
                  ? '✅ Passpartout ATTIVO.\n\nL\'utente può prenotare qualsiasi lezione senza abbonamento specifico (richiede solo iscrizione annuale attiva).\n\nVuoi disabilitarlo?'
                  : '🔒 Passpartout DISATTIVO.\n\nAbilitandolo, l\'utente potrà prenotare qualsiasi lezione senza abbonamento specifico, con il solo requisito dell\'iscrizione annuale attiva e in corso di validità.',
              style: TextStyle(color: Colors.grey[300]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _togglePasspartout();
            },
            icon: Icon(hasPasspartout ? Icons.lock : Icons.key, size: 16),
            label: Text(hasPasspartout ? 'Disabilita' : 'Abilita'),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasPasspartout ? Colors.red : Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
