import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RegistrationCardWidget extends StatelessWidget {
  final Map<String, dynamic> registration;
  final bool isSelected;
  final bool isPrincipalAdmin;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final Function(String) onReject;
  final Function(List<String>) onRequestDocuments;
  final Function(String) onContactApplicant;
  final Function(DateTime) onScheduleInterview;
  final VoidCallback onArchive;
  final VoidCallback onViewDocuments;

  const RegistrationCardWidget({
    super.key,
    required this.registration,
    required this.isSelected,
    required this.isPrincipalAdmin,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
    required this.onRequestDocuments,
    required this.onContactApplicant,
    required this.onScheduleInterview,
    required this.onArchive,
    required this.onViewDocuments,
  });

  @override
  Widget build(BuildContext context) {
    final requestedRole =
        registration['requested_role']?.toString() ?? 'instructor';
    final isAdminRequest =
        ['admin', 'instructor_admin'].contains(requestedRole);
    final urgencyLevel = _getUrgencyLevel();
    final submissionTime = _getSubmissionTime();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withAlpha(26) : Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        elevation: isSelected ? 4 : 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              border: isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isAdminRequest
                          ? Colors.orange.withAlpha(26)
                          : Colors.blue.withAlpha(26),
                      child: Icon(
                        isAdminRequest
                            ? Icons.admin_panel_settings
                            : Icons.person_add,
                        color: isAdminRequest ? Colors.orange : Colors.blue,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  registration['full_name']?.toString() ??
                                      'registration_mgmt.name_unavailable'.tr(),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                    color: AppTheme.textPrimaryLight,
                                  ),
                                ),
                              ),
                              if (urgencyLevel['isUrgent'])
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withAlpha(26),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Text(
                                    'registration_card.urgent'.tr(),
                                    style: GoogleFonts.inter(
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            registration['email']?.toString() ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: AppTheme.textSecondaryLight,
                            ),
                          ),
                          if (registration['phone'] != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'registration_card.phone_label'.tr(
                                namedArgs: {
                                  'phone': '${registration['phone']}',
                                },
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: isAdminRequest
                                ? Colors.orange.withAlpha(26)
                                : Colors.blue.withAlpha(26),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            _getRoleLabel(requestedRole),
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color:
                                  isAdminRequest ? Colors.orange : Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          submissionTime,
                          style: GoogleFonts.inter(
                            fontSize: 9.sp,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    if (isSelected)
                      Container(
                        margin: EdgeInsets.only(left: 8.w),
                        child: CircleAvatar(
                          radius: 10.w,
                          backgroundColor: AppTheme.primaryColor,
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14.sp,
                          ),
                        ),
                      ),
                  ],
                ),

                if (registration['message'] != null &&
                    registration['message'].toString().isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight.withAlpha(128),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'registration_card.candidate_message'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          registration['message'].toString(),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: AppTheme.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 12.h),

                // Document verification section
                if (isAdminRequest)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, color: Colors.orange, size: 16.sp),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'registration_card.admin_request_approval'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 12.h),

                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: Icon(Icons.check, size: 16.sp),
                        label: Text(
                          'registration_card.approve'.tr(),
                          style: GoogleFonts.inter(fontSize: 12.sp),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(context),
                        icon: Icon(Icons.close, size: 16.sp),
                        label: Text(
                          'registration_mgmt.reject'.tr(),
                          style: GoogleFonts.inter(fontSize: 12.sp),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 8.h),

                // Swipe actions row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildActionChip(
                        label: 'registration_card.request_documents'.tr(),
                        icon: Icons.description,
                        color: Colors.blue,
                        onTap: () => _showRequestDocumentsDialog(context),
                      ),
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label: 'registration_card.contact_applicant'.tr(),
                        icon: Icons.contact_phone,
                        color: Colors.green,
                        onTap: () => _showContactDialog(context),
                      ),
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label: 'registration_card.schedule_interview'.tr(),
                        icon: Icons.calendar_today,
                        color: Colors.orange,
                        onTap: () => _showScheduleDialog(context),
                      ),
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label: 'registration_card.archive'.tr(),
                        icon: Icons.archive,
                        color: Colors.grey,
                        onTap: onArchive,
                      ),
                    ],
                  ),
                ),

                // Document gallery preview
                if (isAdminRequest) ...[
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundLight.withAlpha(128),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'registration_card.uploaded_documents'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            _buildDocumentChip(
                                'profile.medical_certificate'.tr(), true),
                            SizedBox(width: 8.w),
                            _buildDocumentChip(
                                'registration_card.identity_document'.tr(),
                                true),
                            SizedBox(width: 8.w),
                            TextButton(
                              onPressed: onViewDocuments,
                              child: Text(
                                'registration_card.view_all'.tr(),
                                style: GoogleFonts.inter(fontSize: 10.sp),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: color.withAlpha(77)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentChip(String name, bool isUploaded) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color:
            isUploaded ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUploaded ? Icons.check_circle : Icons.error,
            color: isUploaded ? Colors.green : Colors.red,
            size: 12.sp,
          ),
          SizedBox(width: 4.w),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 9.sp,
              color: isUploaded ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getUrgencyLevel() {
    final createdAt = DateTime.parse(registration['created_at']);
    final daysSinceSubmission = DateTime.now().difference(createdAt).inDays;
    final requestedRole =
        registration['requested_role']?.toString() ?? 'instructor';
    final isAdminRequest =
        ['admin', 'instructor_admin'].contains(requestedRole);

    return {
      'isUrgent': daysSinceSubmission >= 7 || isAdminRequest,
      'days': daysSinceSubmission,
    };
  }

  String _getSubmissionTime() {
    final createdAt = DateTime.parse(registration['created_at']);
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return 'registration_card.days_ago'
          .tr(namedArgs: {'count': '${difference.inDays}'});
    } else if (difference.inHours > 0) {
      return 'registration_card.hours_ago'
          .tr(namedArgs: {'count': '${difference.inHours}'});
    } else {
      return 'registration_card.today'.tr();
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'roles.admin'.tr();
      case 'instructor_admin':
        return 'dashboard.role_instructor_admin'.tr();
      case 'instructor':
        return 'dashboard.role_instructor'.tr();
      case 'student':
      default:
        return 'dashboard.role_student'.tr();
    }
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'registration_mgmt.reject_title'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'registration_card.reject_reason_prompt'.tr(),
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'registration_card.reject_reason_hint'.tr(),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                onReject(reasonController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('registration_mgmt.reject'.tr(),
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRequestDocumentsDialog(BuildContext context) {
    final documents = <String, bool>{
      'Certificato Medico Aggiornato': false,
      'Documento Identità Fronte/Retro': false,
      'profile.tax_code'.tr(): false,
      'Referenze Professionali': false,
      'CV Aggiornato': false,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'registration_card.request_additional_docs'.tr(),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'registration_mgmt.select_documents_prompt'.tr(),
                style: GoogleFonts.inter(fontSize: 14.sp),
              ),
              SizedBox(height: 12.h),
              ...documents.keys.map((doc) => CheckboxListTile(
                    title: Text(doc, style: GoogleFonts.inter(fontSize: 12.sp)),
                    value: documents[doc],
                    onChanged: (value) {
                      setDialogState(() {
                        documents[doc] = value ?? false;
                      });
                    },
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final selectedDocs = documents.entries
                    .where((entry) => entry.value)
                    .map((entry) => entry.key)
                    .toList();

                if (selectedDocs.isNotEmpty) {
                  Navigator.pop(context);
                  onRequestDocuments(selectedDocs);
                }
              },
              child: Text('registration_mgmt.request_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'registration_card.contact_candidate'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email),
              title: Text('common.email'.tr()),
              onTap: () {
                Navigator.pop(context);
                onContactApplicant('email');
              },
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('profile.phone'.tr()),
              onTap: () {
                Navigator.pop(context);
                onContactApplicant('phone');
              },
            ),
            ListTile(
              leading: Icon(Icons.message),
              title: Text('reminders.sms'.tr()),
              onTap: () {
                Navigator.pop(context);
                onContactApplicant('sms');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now().add(Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay(hour: 10, minute: 0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'registration_card.schedule_interview_title'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                    'Data: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 30)),
                  );
                  if (date != null) {
                    setDialogState(() {
                      selectedDate = date;
                    });
                  }
                },
              ),
              ListTile(
                title: Text('registration_card.time_label'
                    .tr(namedArgs: {'time': selectedTime.format(context)})),
                trailing: Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) {
                    setDialogState(() {
                      selectedTime = time;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final dateTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selectedTime.hour,
                selectedTime.minute,
              );
              Navigator.pop(context);
              onScheduleInterview(dateTime);
            },
            child: Text('communication.schedule_button'.tr()),
          ),
        ],
      ),
    );
  }
}
