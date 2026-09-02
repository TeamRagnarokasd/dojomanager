import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/registration_data_manager.dart';
import '../student_registration_personal_info/widgets/progress_indicator_widget.dart';

/// Step 2 of 4: Emergency Contacts
/// Collects emergency contact information with validation
class StudentRegistrationEmergencyContacts extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const StudentRegistrationEmergencyContacts({super.key, this.existingData});

  @override
  State<StudentRegistrationEmergencyContacts> createState() =>
      _StudentRegistrationEmergencyContactsState();
}

class _StudentRegistrationEmergencyContactsState
    extends State<StudentRegistrationEmergencyContacts> {
  final _formKey = GlobalKey<FormState>();

  // Emergency Contact 1 (Required)
  final _emergencyContact1NameController = TextEditingController();
  final _emergencyContact1PhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    // ✅ FIX: Load from RegistrationDataManager
    if (RegistrationDataManager.hasEmergencyContacts()) {
      final contacts = RegistrationDataManager.emergencyContacts;
      if (contacts.isNotEmpty) {
        _emergencyContact1NameController.text = contacts[0]['nome'] ?? '';
        _emergencyContact1PhoneController.text = contacts[0]['telefono'] ?? '';
      }
    }
  }

  bool _isFormValid() {
    return _emergencyContact1NameController.text.trim().isNotEmpty &&
        _emergencyContact1PhoneController.text.trim().isNotEmpty;
  }

  void _goBack() {
    // ✅ FIX: Save before going back
    _saveToDataManager();
    Navigator.pop(context);
  }

  void _proceedToNextPage() {
    if (_formKey.currentState!.validate() && _isFormValid()) {
      // ✅ FIX: Save to RegistrationDataManager
      _saveToDataManager();

      Navigator.pushNamed(
        context,
        AppRoutes.studentRegistrationMedicalCertificate,
      );
    }
  }

  void _saveToDataManager() {
    RegistrationDataManager.emergencyContacts.clear();

    // Always add first contact (required)
    RegistrationDataManager.emergencyContacts.add({
      'nome': _emergencyContact1NameController.text.trim(),
      'telefono': _emergencyContact1PhoneController.text.trim(),
    });
  }

  @override
  void dispose() {
    _emergencyContact1NameController.dispose();
    _emergencyContact1PhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
        title: Text(
          'registration.title'.tr(),
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          RegistrationProgressIndicator(
            currentStep: 2,
            totalSteps: 4,
            stepLabels: [
              'registration.personal_info'.tr(),
              'registration.emergency_contacts'.tr(),
              'profile.medical_certificate'.tr(),
              'registration.step_terms'.tr(),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Contatti di Emergenza',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'student_registration.min_one_emergency'.tr(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Emergency Contact 1 (Required)
                    _buildContactSection(
                      title:
                          'student_registration.emergency_contact_title'.tr(),
                      nameController: _emergencyContact1NameController,
                      phoneController: _emergencyContact1PhoneController,
                      isRequired: true,
                    ),

                    SizedBox(height: 4.h),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFFF0000), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size(double.infinity, 6.h),
                      ),
                      child: Text(
                        'common.back'.tr(),
                        style: TextStyle(
                          color: const Color(0xFFFF0000),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isFormValid() ? _proceedToNextPage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        disabledBackgroundColor: const Color(0xFF404040),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size(double.infinity, 6.h),
                      ),
                      child: Text(
                        'student_registration.next'.tr(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection({
    required String title,
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required bool isRequired,
  }) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: nameController,
            label: 'student_registration.full_name_label'.tr(
              namedArgs: {'required': isRequired ? '*' : ''},
            ),
            hint: 'student_registration.full_name_hint'.tr(),
            validator: isRequired
                ? (value) {
                    if (value?.isEmpty ?? true) {
                      return 'common.required_field'.tr();
                    }
                    return null;
                  }
                : null,
          ),
          SizedBox(height: 2.h),
          _buildTextField(
            controller: phoneController,
            label: 'student_registration.phone_number_label'.tr(
              namedArgs: {'required': isRequired ? '*' : ''},
            ),
            hint: '+39 123 456 7890',
            keyboardType: TextInputType.phone,
            validator: isRequired
                ? (value) {
                    if (value?.isEmpty ?? true) {
                      return 'common.required_field'.tr();
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF404040)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF0000), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          ),
        ),
      ],
    );
  }
}
