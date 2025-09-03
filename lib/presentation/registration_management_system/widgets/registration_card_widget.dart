import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../../theme/app_theme.dart';

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
                                      'Nome non disponibile',
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
                                    'URGENTE',
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
                              'Telefono: ${registration['phone']}',
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
                          'Messaggio del candidato:',
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
                            'Richiesta amministratore - Richiede approvazione principale',
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
                          'Approva',
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
                          'Rifiuta',
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
                        label: 'Richiedi Documenti',
                        icon: Icons.description,
                        color: Colors.blue,
                        onTap: () => _showRequestDocumentsDialog(context),
                      ),
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label: 'Contatta Applicant',
                        icon: Icons.contact_phone,
                        color: Colors.green,
                        onTap: () => _showContactDialog(context),
                      ),
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label: 'Programma Colloquio',
                        icon: Icons.calendar_today,
                        color: Colors.orange,
                        onTap: () => _showScheduleDialog(context),
                      ),
                      SizedBox(width: 8.w),
                      _buildActionChip(
                        label: 'Archivia',
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
                          'Documenti Caricati:',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryLight,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            _buildDocumentChip('Certificato Medico', true),
                            SizedBox(width: 8.w),
                            _buildDocumentChip('Documento Identità', true),
                            SizedBox(width: 8.w),
                            TextButton(
                              onPressed: onViewDocuments,
                              child: Text(
                                'Visualizza Tutti',
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
      return '${difference.inDays} giorni fa';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ore fa';
    } else {
      return 'Oggi';
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Amministratore';
      case 'instructor_admin':
        return 'Istruttore Admin';
      case 'instructor':
        return 'Istruttore';
      case 'student':
      default:
        return 'Studente';
    }
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rifiuta Registrazione',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inserisci il motivo del rifiuto:',
              style: GoogleFonts.inter(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Documenti incompleti, requisiti non soddisfatti...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                onReject(reasonController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Rifiuta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRequestDocumentsDialog(BuildContext context) {
    final documents = <String, bool>{
      'Certificato Medico Aggiornato': false,
      'Documento Identità Fronte/Retro': false,
      'Codice Fiscale': false,
      'Referenze Professionali': false,
      'CV Aggiornato': false,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Richiedi Documenti Aggiuntivi',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleziona i documenti da richiedere:',
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
              child: Text('Annulla'),
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
              child: Text('Richiedi'),
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
          'Contatta Candidato',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email),
              title: Text('Email'),
              onTap: () {
                Navigator.pop(context);
                onContactApplicant('email');
              },
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('Telefono'),
              onTap: () {
                Navigator.pop(context);
                onContactApplicant('phone');
              },
            ),
            ListTile(
              leading: Icon(Icons.message),
              title: Text('SMS'),
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
          'Programma Colloquio',
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
                title: Text('Ora: ${selectedTime.format(context)}'),
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
            child: Text('Annulla'),
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
            child: Text('Programma'),
          ),
        ],
      ),
    );
  }
}
