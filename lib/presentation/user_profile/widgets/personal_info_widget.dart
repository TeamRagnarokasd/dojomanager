import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../constants/app_constants.dart';
import '../../../services/user_profile_service.dart'
    hide getUserProfile, updateUserProfile;

class PersonalInfoWidget extends StatefulWidget {
  const PersonalInfoWidget({Key? key}) : super(key: key);

  @override
  State<PersonalInfoWidget> createState() => _PersonalInfoWidgetState();
}

class _PersonalInfoWidgetState extends State<PersonalInfoWidget> {
  final _supabase = Supabase.instance.client;
  bool _isEditing = false;
  bool _isLoading = true;

  // 🎯 RIPRISTINO: Separate controllers for Nome and Cognome
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxCodeController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthPlaceController =
      TextEditingController(); // 🎯 NEW: Birth place controller
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _capController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final profile = await UserProfileService.getUserProfile(userId);
      if (profile != null && mounted) {
        // 🎯 RIPRISTINO: Split full_name into Nome and Cognome
        final fullName = profile['full_name'] ?? '';
        final nameParts = fullName.trim().split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        setState(() {
          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
          _emailController.text = profile['email'] ?? '';
          _phoneController.text = profile['phone'] ?? '';
          _taxCodeController.text =
              profile['tax_code'] ?? profile['codice_fiscale'] ?? '';
          _birthDateController.text = profile['birth_date']?.toString() ?? '';
          _birthPlaceController.text =
              profile['birth_place'] ?? ''; // 🎯 NEW: Load birth place
          _addressController.text = profile['address_line'] ?? '';
          _cityController.text = profile['city'] ?? '';
          _provinceController.text = profile['province'] ?? '';
          _capController.text = profile['cap'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento del profilo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 🎯 RIPRISTINO: Combine Nome and Cognome back to full_name
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();

      await UserProfileService.updateUserProfile(
        userId: userId,
        fullName: fullName,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        cap: _capController.text.trim(),
        taxCode: _taxCodeController.text.trim(),
        birthDate: _birthDateController.text.trim(),
        birthPlace:
            _birthPlaceController.text.trim(), // 🎯 NEW: Save birth place
      );

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profilo aggiornato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'aggiornamento: $e'),
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
                'Informazioni Personali',
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
          // 🎯 RIPRISTINO: Separate Nome and Cognome fields
          _buildInfoField('Nome', _firstNameController, Icons.person),
          SizedBox(height: 2.h),
          _buildInfoField('Cognome', _lastNameController, Icons.person_outline),
          SizedBox(height: 2.h),
          _buildInfoField(
            'Email',
            _emailController,
            Icons.email,
            enabled: false,
          ),
          SizedBox(height: 2.h),
          _buildInfoField('Telefono', _phoneController, Icons.phone),
          SizedBox(height: 2.h),
          _buildInfoField(
            'Codice Fiscale',
            _taxCodeController,
            Icons.credit_card,
            textCapitalization: TextCapitalization.characters,
          ),
          SizedBox(height: 2.h),
          _buildInfoField(
            'Data di Nascita',
            _birthDateController,
            Icons.calendar_today,
            hintText: 'dd/mm/yyyy',
          ),
          SizedBox(height: 2.h),
          // 🎯 NEW: Birth place field
          _buildInfoField(
            'Luogo di Nascita',
            _birthPlaceController,
            Icons.location_on,
          ),
          SizedBox(height: 2.h),
          _buildInfoField('Indirizzo', _addressController, Icons.home),
          SizedBox(height: 2.h),
          _buildInfoField('Città', _cityController, Icons.location_city),
          SizedBox(height: 2.h),
          Row(
            children: [
              Expanded(
                child: _buildInfoField(
                  'Provincia',
                  _provinceController,
                  null,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: _buildInfoField(
                  'CAP',
                  _capController,
                  Icons.markunread_mailbox,
                ),
              ),
            ],
          ),
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
                  'Salva Modifiche',
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
            prefixIcon:
                icon != null
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _taxCodeController.dispose();
    _birthDateController.dispose();
    _birthPlaceController.dispose(); // 🎯 NEW: Dispose birth place controller
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _capController.dispose();
    super.dispose();
  }
}
