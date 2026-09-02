import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../constants/app_constants.dart';
import '../../../services/supabase_service.dart';
import '../../../services/auth_service.dart';

class PersonalInfoWidget extends StatefulWidget {
  final String? userId;
  final VoidCallback? onProfileUpdated;
  final bool isChildProfile;

  const PersonalInfoWidget({
    Key? key,
    this.userId,
    this.onProfileUpdated,
    this.isChildProfile = false,
  }) : super(key: key);

  @override
  State<PersonalInfoWidget> createState() => _PersonalInfoWidgetState();
}

class _PersonalInfoWidgetState extends State<PersonalInfoWidget> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isEditing = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _taxCodeController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _birthPlaceController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _capController = TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();

  // 🎯 NEW: Parent/Guardian controllers for minors
  final TextEditingController _parentGuardianNameController =
      TextEditingController();
  final TextEditingController _parentGuardianSurnameController =
      TextEditingController();
  final TextEditingController _parentGuardianEmailController =
      TextEditingController();
  final TextEditingController _parentGuardianPhoneController =
      TextEditingController();
  final TextEditingController _parentGuardianRelationController =
      TextEditingController();
  final TextEditingController _parentGuardianCodiceFiscaleController =
      TextEditingController();

  bool _isMinor = false;
  String _roleTitle = ''; // 🎯 NEW: Store role_title for display
  int _loadToken = 0;

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final loadToken = ++_loadToken;
    try {
      final client = SupabaseService.instance.client;

      String? targetUserId =
          widget.userId ?? AuthService.instance.currentUser?.id;

      // 🎯 FIX: If this is a child profile, query child_profiles table instead
      if (widget.isChildProfile && targetUserId != null) {
        final response = await client
            .from('child_profiles')
            .select('*')
            .eq('id', targetUserId)
            .maybeSingle();

        if (response == null) {
          if (!mounted || loadToken != _loadToken) return;
          _safeSetState(() {
            _userProfile = null;
            _isLoading = false;
          });
          return;
        }

        if (!mounted || loadToken != _loadToken) return;
        _safeSetState(() {
          _userProfile = response;
          _firstNameController.text = response['first_name'] ?? '';
          _lastNameController.text = response['last_name'] ?? '';
          _emailController.text = response['email'] ?? '';
          _taxCodeController.text =
              response['tax_code'] ?? response['codice_fiscale'] ?? '';
          _phoneController.text = response['phone'] ?? '';
          _birthPlaceController.text = response['birth_place'] ?? '';
          _addressController.text = response['address_line'] ?? '';
          _cityController.text = response['city'] ?? '';
          _provinceController.text = response['province'] ?? '';
          _capController.text = response['cap'] ?? '';
          _emergencyNameController.text =
              response['emergency_contact_name'] ?? '';
          _emergencyPhoneController.text =
              response['emergency_contact_phone'] ?? '';
          _roleTitle = 'Minore';
          _isMinor = true;

          // Format birth_date as DD/MM/YYYY
          final birthDate = response['birth_date'];
          if (birthDate != null && birthDate.toString().isNotEmpty) {
            try {
              final parsedDate = DateTime.parse(birthDate);
              _birthDateController.text =
                  '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
            } catch (e) {
              _birthDateController.text = birthDate.toString();
            }
          } else {
            _birthDateController.text = '';
          }

          _isLoading = false;
        });

        // 🎯 AUTO-FILL: Fetch guardian data from user_profiles using guardian_id
        final guardianId = response['guardian_id'] as String?;
        if (guardianId != null && guardianId.isNotEmpty) {
          try {
            final guardianData = await client
                .from('user_profiles')
                .select(
                    'first_name, last_name, email, phone, tax_code, codice_fiscale')
                .eq('id', guardianId)
                .maybeSingle();

            if (guardianData != null && mounted && loadToken == _loadToken) {
              _safeSetState(() {
                _parentGuardianNameController.text =
                    guardianData['first_name'] ?? '';
                _parentGuardianSurnameController.text =
                    guardianData['last_name'] ?? '';
                _parentGuardianEmailController.text =
                    guardianData['email'] ?? '';
                _parentGuardianPhoneController.text =
                    guardianData['phone'] ?? '';
                _parentGuardianCodiceFiscaleController.text =
                    guardianData['tax_code'] ??
                        guardianData['codice_fiscale'] ??
                        '';
                // Relation defaults to 'Genitore' if not already set
                if (_parentGuardianRelationController.text.isEmpty) {
                  _parentGuardianRelationController.text = 'Genitore';
                }
              });
            }
          } catch (e) {
            print('⚠️ Could not load guardian data: $e');
          }
        }

        return;
      }

      // 🎯 ACTION 1: FORCE SELECT ALL - Use wildcard selector; maybeSingle() so missing profile doesn't throw
      final response = await client
          .from('user_profiles')
          .select('*')
          .eq('id', targetUserId!)
          .maybeSingle();

      if (response == null) {
        if (!mounted || loadToken != _loadToken) return;
        _safeSetState(() {
          _userProfile = null;
          _isLoading = false;
        });
        return;
      }

      // 🎯 ACTION 2: DIRECT RAW ASSIGNMENT - No intermediate model objects
      final data = response; // Raw JSON map

      if (!mounted || loadToken != _loadToken) return;
      _safeSetState(() {
        _userProfile = data;

        // 1. ANAGRAFICA (Personal Info)
        _firstNameController.text = data['first_name'] ?? '';
        _lastNameController.text = data['last_name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _taxCodeController.text = data['tax_code'] ?? '';
        _roleTitle = data['role_title'] ??
            'roles.student'.tr(); // 🎯 NEW: Load role_title

        // 🎯 Format birth_date as DD/MM/YYYY
        final birthDate = data['birth_date'];
        if (birthDate != null && birthDate.toString().isNotEmpty) {
          try {
            final parsedDate = DateTime.parse(birthDate);
            _birthDateController.text =
                '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
          } catch (e) {
            _birthDateController.text = birthDate.toString();
          }
        } else {
          _birthDateController.text = '';
        }

        _birthPlaceController.text = data['birth_place'] ?? '';
        _phoneController.text = data['phone'] ?? '';

        // 2. INDIRIZZO (Address)
        _addressController.text = data['address_line'] ?? '';
        _cityController.text = data['city'] ?? '';
        _provinceController.text = data['province'] ?? '';
        _capController.text = data['cap'] ?? '';

        // 3. EMERGENZA (Emergency Contact)
        _emergencyNameController.text = data['emergency_contact'] ?? '';
        _emergencyPhoneController.text = data['emergency_phone'] ?? '';

        // 4. CERTIFICATO MEDICO (Visual Logic)
        // Check if 'medical_certificate_url' exists in 'data' map to show/hide the button logic
        // (This logic is handled by medical_certificate_status_widget.dart)

        // 🎯 Parent/Guardian fields for minors
        _isMinor = data['is_minor'] ?? false;
        _parentGuardianNameController.text = data['parent_guardian_name'] ?? '';
        _parentGuardianSurnameController.text =
            data['parent_guardian_surname'] ?? '';
        _parentGuardianEmailController.text =
            data['parent_guardian_email'] ?? '';
        _parentGuardianPhoneController.text =
            data['parent_guardian_phone'] ?? '';
        _parentGuardianRelationController.text =
            data['parent_guardian_relation'] ?? '';
        _parentGuardianCodiceFiscaleController.text =
            data['parent_guardian_codice_fiscale'] ?? '';

        _isLoading = false;
      });

      print(
        '✅ Profile data loaded for user: $targetUserId (Name: ${_firstNameController.text} ${_lastNameController.text}, Role: $_roleTitle)',
      );
    } catch (e) {
      print('❌ Error loading user profile: $e');
      if (!mounted || loadToken != _loadToken) return;
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    try {
      final client = SupabaseService.instance.client;

      String? targetUserId =
          widget.userId ?? AuthService.instance.currentUser?.id;

      // 🎯 CRITICAL: Update all fields including first_name, last_name, and full_name
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = '$firstName $lastName'.trim();

      // 🎯 CRITICAL: Convert DD/MM/YYYY back to YYYY-MM-DD for database
      String? birthDateForDb;
      final birthDateInput = _birthDateController.text.trim();
      if (birthDateInput.isNotEmpty) {
        try {
          // Try parsing DD/MM/YYYY format
          final parts = birthDateInput.split('/');
          if (parts.length == 3) {
            birthDateForDb =
                '${parts[2]}-${parts[1]}-${parts[0]}'; // Convert to YYYY-MM-DD
          } else {
            birthDateForDb =
                birthDateInput; // Keep as-is if not in expected format
          }
        } catch (e) {
          birthDateForDb = birthDateInput;
        }
      }

      final updateData = {
        'first_name': firstName,
        'last_name': lastName,
        'full_name': fullName, // Keep full_name in sync
        'phone': _phoneController.text.trim(),
        'tax_code': _taxCodeController.text.trim().toUpperCase(),
        'codice_fiscale':
            _taxCodeController.text.trim().toUpperCase(), // Sync both fields
        'birth_date': birthDateForDb,
        'birth_place': _birthPlaceController.text.trim(),
        'address_line': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'province': _provinceController.text.trim().toUpperCase(),
        'cap': _capController.text.trim(),
        'emergency_contact': _emergencyNameController.text.trim(),
        'emergency_phone': _emergencyPhoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 🎯 NEW: Add parent/guardian fields if user is a minor
      if (_isMinor) {
        updateData.addAll({
          'parent_guardian_name': _parentGuardianNameController.text.trim(),
          'parent_guardian_surname':
              _parentGuardianSurnameController.text.trim(),
          'parent_guardian_email': _parentGuardianEmailController.text.trim(),
          'parent_guardian_phone': _parentGuardianPhoneController.text.trim(),
          'parent_guardian_relation':
              _parentGuardianRelationController.text.trim(),
          'parent_guardian_codice_fiscale':
              _parentGuardianCodiceFiscaleController.text.trim().toUpperCase(),
        });
      }

      await client
          .from('user_profiles')
          .update(updateData)
          .eq('id', targetUserId!);

      if (!mounted) return;
      _safeSetState(() => _isEditing = false);

      // Trigger parent refresh
      widget.onProfileUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.profile_updated'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✅ Profile saved successfully: $firstName $lastName');
    } catch (e) {
      print('❌ Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'profile.profile_save_error'.tr(namedArgs: {'error': '$e'}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    if (_userProfile == null) {
      return Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        ),
        child: Center(
          child: Text(
            'profile.profile_unavailable'.tr(),
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'profile.personal_info'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.close : Icons.edit,
                  color: Colors.red,
                ),
                onPressed: () => setState(() => _isEditing = !_isEditing),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Nome and Cognome fields
          Row(
            children: [
              Expanded(
                child: _buildInfoField(
                  'profile.first_name'.tr(),
                  _firstNameController,
                  Icons.person,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildInfoField(
                  'profile.last_name'.tr(),
                  _lastNameController,
                  Icons.person_outline,
                ),
              ),
            ],
          ),

          // 🎯 NEW: Display role_title row under Nome/Cognome as requested
          SizedBox(height: 2.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(26),
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              border: Border.all(color: Colors.red.withAlpha(77)),
            ),
            child: Row(
              children: [
                Icon(Icons.work_outline, color: Colors.red, size: 20.sp),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile.role'.tr(),
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        _roleTitle.isEmpty
                            ? 'profile.default_student_role'.tr()
                            : _roleTitle,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),
          _buildInfoField(
            'common.email'.tr(),
            _emailController,
            Icons.email,
            enabled: false,
          ),
          SizedBox(height: 2.h),
          _buildInfoField('profile.phone'.tr(), _phoneController, Icons.phone),
          SizedBox(height: 2.h),
          _buildInfoField(
            'profile.tax_code'.tr(),
            _taxCodeController,
            Icons.credit_card,
            textCapitalization: TextCapitalization.characters,
          ),
          SizedBox(height: 2.h),
          _buildInfoField(
            'profile.birth_date'.tr(),
            _birthDateController,
            Icons.calendar_today,
            hintText: 'profile.date_format_hint'.tr(),
          ),
          SizedBox(height: 2.h),
          _buildInfoField(
            'profile.birth_place'.tr(),
            _birthPlaceController,
            Icons.location_on,
          ),
          SizedBox(height: 2.h),
          _buildInfoField(
            'profile.address'.tr(),
            _addressController,
            Icons.home,
          ),
          SizedBox(height: 2.h),
          _buildInfoField(
            'profile.city'.tr(),
            _cityController,
            Icons.location_city,
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildInfoField(
                  'profile.province'.tr(),
                  _provinceController,
                  null,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildInfoField(
                  'profile.zip_code'.tr(),
                  _capController,
                  Icons.markunread_mailbox,
                ),
              ),
            ],
          ),

          // 🎯 Emergency Contact Section
          SizedBox(height: 3.h),
          Divider(color: Colors.grey[800]),
          SizedBox(height: 2.h),
          Text(
            'profile.emergency_contact'.tr(),
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          _buildInfoField(
            'profile.emergency_contact_name'.tr(),
            _emergencyNameController,
            Icons.contact_emergency,
          ),
          SizedBox(height: 2.h),
          _buildInfoField(
            'profile.emergency_phone'.tr(),
            _emergencyPhoneController,
            Icons.phone_in_talk,
          ),

          // 🎯 NEW: Parent/Guardian Section (only for minors)
          if (_isMinor) ...[
            SizedBox(height: 3.h),
            Divider(color: Colors.grey[800]),
            SizedBox(height: 2.h),
            Row(
              children: [
                Icon(Icons.family_restroom, color: Colors.red, size: 20.sp),
                SizedBox(width: 2.w),
                Text(
                  'profile.parent_guardian_info'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Expanded(
                  child: _buildInfoField(
                    'profile.parent_guardian_name'.tr(),
                    _parentGuardianNameController,
                    Icons.person,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _buildInfoField(
                    'profile.last_name'.tr(),
                    _parentGuardianSurnameController,
                    Icons.person_outline,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            _buildInfoField(
              'profile.relation'.tr(),
              _parentGuardianRelationController,
              Icons.people,
              hintText: 'profile.relation_hint'.tr(),
            ),
            SizedBox(height: 2.h),
            _buildInfoField(
              'profile.parent_guardian_email'.tr(),
              _parentGuardianEmailController,
              Icons.email,
            ),
            SizedBox(height: 2.h),
            _buildInfoField(
              'profile.parent_guardian_phone'.tr(),
              _parentGuardianPhoneController,
              Icons.phone,
            ),
            SizedBox(height: 2.h),
            _buildInfoField(
              'profile.parent_guardian_tax_code'.tr(),
              _parentGuardianCodiceFiscaleController,
              Icons.credit_card,
              textCapitalization: TextCapitalization.characters,
            ),
          ],

          if (_isEditing) ...[
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
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
                  'profile.save_changes'.tr(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoField(
    String label,
    TextEditingController controller,
    IconData? icon, {
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? hintText,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12.sp),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          enabled: _isEditing && enabled,
          textCapitalization: textCapitalization,
          style: GoogleFonts.inter(
            color: (_isEditing && enabled) ? Colors.white : Colors.grey[300],
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.red, size: 20.sp)
                : null,
            filled: true,
            fillColor:
                (_isEditing && enabled) ? Color(0xFF2A2A2A) : Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 1.5.h,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _loadToken++; // Cancel any in-flight profile load/save
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _taxCodeController.dispose();
    _birthDateController.dispose();
    _birthPlaceController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _capController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _parentGuardianNameController.dispose();
    _parentGuardianSurnameController.dispose();
    _parentGuardianEmailController.dispose();
    _parentGuardianPhoneController.dispose();
    _parentGuardianRelationController.dispose();
    _parentGuardianCodiceFiscaleController.dispose();
    super.dispose();
  }
}
