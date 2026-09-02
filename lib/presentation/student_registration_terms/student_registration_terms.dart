import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/student_registration_service.dart';
import '../student_registration/widgets/progress_indicator_widget.dart';
import '../student_registration/widgets/terms_acceptance_section.dart';

class StudentRegistrationTerms extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const StudentRegistrationTerms({super.key, this.existingData});

  @override
  State<StudentRegistrationTerms> createState() =>
      _StudentRegistrationTermsState();
}

class _StudentRegistrationTermsState extends State<StudentRegistrationTerms> {
  bool _termsAccepted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    if (widget.existingData != null) {
      final data = widget.existingData!;
      _termsAccepted = data['termsAccepted'] ?? false;
    }
  }

  Map<String, dynamic> _gatherFormData() {
    return {
      'termsAccepted': _termsAccepted,
    };
  }

  void _updateTermsAcceptance(bool accepted) {
    setState(() {
      _termsAccepted = accepted;
    });
  }

  Future<void> _submitRegistration() async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('student_registration.must_accept_terms'.tr()),
          backgroundColor: AppTheme.lightTheme.colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final allData = {...?widget.existingData, ..._gatherFormData()};

      // Extract and validate emergency contacts
      final emergencyContactsList =
          List<Map<String, dynamic>>.from(allData['emergencyContacts'] ?? []);
      final validEmergencyContacts = emergencyContactsList
          .where((contact) =>
              (contact['nome'] as String).isNotEmpty &&
              (contact['telefono'] as String).isNotEmpty)
          .map((contact) => {
                'nome': contact['nome'] as String,
                'telefono': contact['telefono'] as String,
              })
          .toList();

      if (validEmergencyContacts.isEmpty) {
        throw Exception('student_registration.emergency_contact_required'.tr());
      }

      // Parse birth date
      DateTime? birthDate;
      if (allData['selectedBirthDate'] != null) {
        birthDate = DateTime.parse(allData['selectedBirthDate']);
      }

      // Call registration service
      final result = await StudentRegistrationService.registerStudent(
        email: allData['email'] ?? '',
        password: allData['password'] ?? '',
        nome: allData['firstName'] ?? '',
        cognome: allData['lastName'] ?? '',
        telefono: allData['phone'] ?? '',
        dataNascita: birthDate ?? DateTime.now(),
        codiceFiscale: (allData['taxCode'] ?? '').toUpperCase(),
        indirizzoResidenza: allData['address'] ?? '',
        citta: allData['city'] ?? '',
        provincia: (allData['province'] ?? '').toUpperCase(),
        cap: allData['cap'] ?? '',
        emergencyContacts: validEmergencyContacts,
        medicalDocuments:
            List<Map<String, dynamic>>.from(allData['uploadedDocuments'] ?? []),
        termsAccepted: _termsAccepted,
        // Parent/guardian info for minors
        parentGuardianName:
            allData['isMinor'] == true ? allData['parentName'] : null,
        parentGuardianSurname:
            allData['isMinor'] == true ? allData['parentSurname'] : null,
        parentGuardianCodiceFiscale: allData['isMinor'] == true
            ? (allData['parentTaxCode'] ?? '').toUpperCase()
            : null,
        parentGuardianEmail:
            allData['isMinor'] == true ? allData['parentEmail'] : null,
        parentGuardianPhone:
            allData['isMinor'] == true ? allData['parentPhone'] : null,
        parentGuardianRelation:
            allData['isMinor'] == true ? allData['parentRelation'] : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          _showSuccessDialog(result);
        } else {
          throw Exception(
              result['message'] ?? 'user_mgmt.registration_error'.tr());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showGeneralErrorDialog(
          'user_mgmt.registration_error_detail'
              .tr(namedArgs: {'detail': e.toString()}),
        );
      }
    }
  }

  void _goBackToPreviousPage() {
    final formData = _gatherFormData();
    final existingData = widget.existingData ?? {};
    final mergedData = {...existingData, ...formData};

    Navigator.pushReplacementNamed(
      context,
      AppRoutes.studentRegistrationMedicalCertificate,
      arguments: mergedData,
    );
  }

  void _showGeneralErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'error',
              color: AppTheme.lightTheme.colorScheme.error,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text('common.error'.tr()),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.ok'.tr()),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'check_circle',
              color: AppTheme.lightTheme.colorScheme.tertiary,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text('student_registration.completed_title'.tr()),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result['message'] ??
                  'student_registration.registration_completed_message'.tr(),
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.primaryContainer
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'pending',
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          'student_registration.approval_pending_admin'.tr(),
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightTheme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    '📧 Gli amministratori sono stati notificati della tua richiesta.\n'
                            '⏳ Riceverai una email di conferma entro 24-48 ore.\n'
                            'student_registration.account_activation_after_approval'
                        .tr(),
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppTheme.lightTheme.colorScheme.onSurface,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'student_registration.what_happens_now'.tr(),
                        style: AppTheme.lightTheme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'student_registration.approval_steps'.tr(),
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            child: Text('student_registration.go_to_login'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('registration.title'.tr()),
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.colorScheme.onSurface,
            size: 24,
          ),
          onPressed: _goBackToPreviousPage,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  children: [
                    ProgressIndicatorWidget(
                      currentStep: 3,
                      totalSteps: 4,
                      stepLabels: [
                        'registration.personal_info'.tr(),
                        'registration.emergency_contacts'.tr(),
                        'profile.medical_certificate'.tr(),
                        'registration.step_terms'.tr(),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    TermsAcceptanceSection(
                      isAccepted: _termsAccepted,
                      onChanged: _updateTermsAcceptance,
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.lightTheme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _goBackToPreviousPage,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: AppTheme.lightTheme.colorScheme.primary,
                ),
              ),
              child: Text(
                'common.back'.tr(),
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed:
                  _termsAccepted && !_isLoading ? _submitRegistration : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: _termsAccepted && !_isLoading
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.lightTheme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Text('student_reg_ui.registering'.tr()),
                      ],
                    )
                  : Text(
                      'student_registration.register_account'.tr(),
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: _termsAccepted && !_isLoading
                            ? AppTheme.lightTheme.colorScheme.onPrimary
                            : AppTheme.lightTheme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
