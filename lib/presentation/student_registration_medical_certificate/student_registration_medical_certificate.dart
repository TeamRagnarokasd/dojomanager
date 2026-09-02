import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/registration_data_manager.dart';
import '../student_registration_personal_info/widgets/progress_indicator_widget.dart';

/// Step 3 of 4: Medical Certificate (Optional)
/// Handles document upload and certificate details with optional flow
class StudentRegistrationMedicalCertificate extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const StudentRegistrationMedicalCertificate({super.key, this.existingData});

  @override
  State<StudentRegistrationMedicalCertificate> createState() =>
      _StudentRegistrationMedicalCertificateState();
}

class _StudentRegistrationMedicalCertificateState
    extends State<StudentRegistrationMedicalCertificate> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final _doctorNameController = TextEditingController();
  final _certificateNumberController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _expiryDateController = TextEditingController();

  XFile? _certificateImage;
  DateTime? _selectedIssueDate;
  DateTime? _selectedExpiryDate;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    // ✅ FIX: Load from RegistrationDataManager
    if (RegistrationDataManager.hasMedicalCertificate()) {
      final medicalDocs = RegistrationDataManager.medicalDocuments;
      if (medicalDocs != null && medicalDocs.isNotEmpty) {
        final doc = medicalDocs[0];
        _doctorNameController.text = doc['doctor_name'] ?? '';
        _certificateNumberController.text = doc['certificate_number'] ?? '';

        if (doc['issue_date'] != null &&
            doc['issue_date'].toString().isNotEmpty) {
          try {
            _selectedIssueDate = DateTime.parse(doc['issue_date']);
            _issueDateController.text =
                '${_selectedIssueDate!.day}/${_selectedIssueDate!.month}/${_selectedIssueDate!.year}';
          } catch (e) {
            // Invalid date format
          }
        }

        if (doc['expiry_date'] != null &&
            doc['expiry_date'].toString().isNotEmpty) {
          try {
            _selectedExpiryDate = DateTime.parse(doc['expiry_date']);
            _expiryDateController.text =
                '${_selectedExpiryDate!.day}/${_selectedExpiryDate!.month}/${_selectedExpiryDate!.year}';
          } catch (e) {
            // Invalid date format
          }
        }
      }
    }
  }

  bool _hasAnyData() {
    return _certificateImage != null ||
        _doctorNameController.text.isNotEmpty ||
        _certificateNumberController.text.isNotEmpty ||
        _issueDateController.text.isNotEmpty ||
        _expiryDateController.text.isNotEmpty;
  }

  void _goBack() {
    // ✅ FIX: Save before going back
    _saveToDataManager();
    Navigator.pop(context);
  }

  void _proceedToNextPage() {
    if (!_hasAnyData()) {
      _showCertificateReminderDialog();
    } else {
      _navigateToTerms();
    }
  }

  void _showCertificateReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.orange.shade300, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 28),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'student_registration.certificate_reminder_title'.tr(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'student_registration.certificate_reminder_body'.tr(),
          style: TextStyle(fontSize: 13.sp, color: Colors.black87, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryLight),
            child: Text(
              'student_registration.enter_now'.tr(),
              style: TextStyle(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _navigateToTerms();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'common.continue'.tr(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTerms() {
    // ✅ FIX: Save to RegistrationDataManager
    _saveToDataManager();

    Navigator.pushNamed(
      context,
      AppRoutes.studentRegistrationTermsAndCompletion,
    );
  }

  void _saveToDataManager() {
    if (_hasAnyData()) {
      RegistrationDataManager.medicalDocuments = [
        {
          'file_path': _certificateImage?.path ?? '',
          'file_name': _certificateImage?.name ?? '',
          'upload_date': DateTime.now().toIso8601String(),
          'doctor_name': _doctorNameController.text.trim(),
          'certificate_number': _certificateNumberController.text.trim(),
          'issue_date': _selectedIssueDate?.toIso8601String() ?? '',
          'expiry_date': _selectedExpiryDate?.toIso8601String() ?? '',
        },
      ];
    } else {
      RegistrationDataManager.medicalDocuments = null;
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _certificateImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'student_registration.acquisition_error'.tr(
              namedArgs: {'error': '$e'},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _certificateImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'student_reg_ui.selection_error'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
    }
  }

  Future<void> _selectDate(bool isIssueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryLight,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isIssueDate) {
          _selectedIssueDate = picked;
          _issueDateController.text =
              '${picked.day}/${picked.month}/${picked.year}';
        } else {
          _selectedExpiryDate = picked;
          _expiryDateController.text =
              '${picked.day}/${picked.month}/${picked.year}';
        }
      });
    }
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _certificateNumberController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
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
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
        title: Text(
          'registration.title'.tr(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          RegistrationProgressIndicator(
            currentStep: 3,
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
                      '3. Certificato Medico',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'student_registration.upload_valid_certificate'.tr(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Image Upload Section
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _certificateImage != null
                              ? AppTheme.successLight
                              : const Color(0xFF404040),
                          width: _certificateImage != null ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_certificateImage != null) ...[
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.successLight,
                              size: 40,
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'student_registration.certificate_uploaded'.tr(),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successLight,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              _certificateImage!.name,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 2.h),
                          ] else ...[
                            Icon(
                              Icons.upload_file,
                              color: Colors.grey.shade400,
                              size: 40,
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'student_registration.no_certificate_uploaded'
                                  .tr(),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 2.h),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _captureImage,
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text('profile.take_photo'.tr()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryLight,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickFromGallery,
                                  icon: const Icon(Icons.photo_library),
                                  label: Text('common.gallery'.tr()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryLight,
                                    side: BorderSide(
                                      color: AppTheme.primaryLight,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 3.h),

                    _buildTextField(
                      controller: _doctorNameController,
                      label: 'student_registration.doctor_name_label'.tr(),
                      hint: 'Dr. Mario Rossi',
                    ),

                    SizedBox(height: 2.h),

                    _buildTextField(
                      controller: _certificateNumberController,
                      label: 'student_registration.certificate_number_optional'
                          .tr(),
                      hint: 'ABC123456',
                    ),

                    SizedBox(height: 2.h),

                    _buildTextField(
                      controller: _issueDateController,
                      label: 'student_registration.issue_date_label'.tr(),
                      hint: 'student_registration.date_format_hint'.tr(),
                      readOnly: true,
                      onTap: () => _selectDate(true),
                      suffixIcon: Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryLight,
                      ),
                    ),

                    SizedBox(height: 2.h),

                    _buildTextField(
                      controller: _expiryDateController,
                      label: 'student_registration.expiry_date_label'.tr(),
                      hint: 'student_registration.date_format_hint'.tr(),
                      readOnly: true,
                      onTap: () => _selectDate(false),
                      suffixIcon: Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryLight,
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // Optional reminder info box
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.warningLight.withAlpha(77),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.warningLight,
                            size: 24,
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Text(
                              'student_registration.upload_within_30_personal'
                                  .tr(),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppTheme.textPrimaryLight,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
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
                        side: BorderSide(
                          color: AppTheme.primaryLight,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size(double.infinity, 6.h),
                      ),
                      child: Text(
                        'common.back'.tr(),
                        style: TextStyle(
                          color: AppTheme.primaryLight,
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
                      onPressed: _proceedToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14.sp),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            suffixIcon: suffixIcon,
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
              borderSide: BorderSide(color: AppTheme.primaryLight, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.errorLight, width: 1),
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
}
