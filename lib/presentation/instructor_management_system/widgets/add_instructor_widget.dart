import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../../../services/instructor_management_service.dart';
import './new_instructor_form_widget.dart';
import './student_selection_dialog_widget.dart';
import '../../../core/app_export.dart';

class AddInstructorWidget extends StatefulWidget {
  final VoidCallback onInstructorAdded;

  const AddInstructorWidget({super.key, required this.onInstructorAdded});

  @override
  State<AddInstructorWidget> createState() => _AddInstructorWidgetState();
}

class _AddInstructorWidgetState extends State<AddInstructorWidget> {
  final InstructorManagementService _instructorService =
      InstructorManagementService();

  Future<void> _showStudentSelectionDialog() async {
    try {
      // Haptic feedback for better user experience
      HapticFeedback.mediumImpact();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StudentSelectionDialogWidget(
          onStudentPromoted: () {
            Navigator.of(context).pop();
            widget.onInstructorAdded();
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Studente promosso a istruttore con successo!',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('instructor_management.dialog_open_error'
              .tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showNewInstructorForm() async {
    try {
      // Haptic feedback for better user experience
      HapticFeedback.mediumImpact();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => NewInstructorFormWidget(
          onInstructorCreated: () {
            Navigator.of(context).pop();
            widget.onInstructorAdded();
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('instructor_management.created_success'.tr()),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('instructor_management.form_open_error'
              .tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Enhanced Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF0000),
                      const Color(0xFFFF0000).withAlpha(204),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withAlpha(77),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aggiungi Nuovo Istruttore',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Espandi il team con nuovi talenti',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withAlpha(230),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scegli il metodo migliore per aggiungere il nuovo membro del team. Puoi promuovere uno studente esistente oppure creare un profilo completamente nuovo.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withAlpha(230),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Option 1: Select from Students
              _buildEnhancedOptionCard(
                icon: Icons.school_outlined,
                title: 'instructor_management.select_from_students'.tr(),
                subtitle: 'Promuovi uno studente esistente',
                description:
                    'Trasforma uno studente qualificato in istruttore mantenendo tutte le sue informazioni esistenti.',
                features: [
                  'Ricerca nella lista studenti approvati',
                  'Mantiene tutte le informazioni esistenti',
                  'Cambio automatico del ruolo e permessi',
                  'instructor_management.custom_disciplines_config'.tr(),
                ],
                onTap: _showStudentSelectionDialog,
                buttonText: 'Cerca Utente',
                buttonColor: const Color(0xFF4CAF50),
                gradientColors: [
                  const Color(0xFF4CAF50).withAlpha(26),
                  const Color(0xFF4CAF50).withAlpha(13),
                ],
              ),

              const SizedBox(height: 20),

              // Option 2: Create New Profile
              _buildEnhancedOptionCard(
                icon: Icons.person_add_outlined,
                title: 'instructor_management.create_new_profile'.tr(),
                subtitle: 'Profilo istruttore da zero',
                description:
                    'instructor_management.create_new_profile_desc'.tr(),
                features: [
                  'Inserimento completo delle informazioni',
                  'Creazione account e profilo personalizzato',
                  'instructor_management.advanced_disciplines_config'.tr(),
                  'user_mgmt.upload_photo_certs'.tr(),
                ],
                onTap: _showNewInstructorForm,
                buttonText: 'instructor_management.create_new_profile'.tr(),
                buttonColor: const Color(0xFFFF0000),
                gradientColors: [
                  const Color(0xFFFF0000).withAlpha(26),
                  const Color(0xFFFF0000).withAlpha(13),
                ],
              ),

              const SizedBox(height: 30),

              // Enhanced Quick Stats
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF333333), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(26),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'instructor_management.useful_info'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'I nuovi istruttori avranno accesso immediato al dashboard specifico per gestire le proprie classi, studenti e orari. Le discipline e i permessi possono essere modificati in qualsiasi momento attraverso il pannello di amministrazione.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[300],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withAlpha(77)),
                      ),
                      child: Text(
                        '💡 Suggerimento: Inizia sempre con la promozione degli studenti più esperti',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue[300],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required List<String> features,
    required VoidCallback onTap,
    required String buttonText,
    required Color buttonColor,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: buttonColor.withAlpha(77), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: buttonColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: buttonColor.withAlpha(102)),
                      ),
                      child: Icon(icon, color: buttonColor, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: buttonColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Description
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.grey[300],
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // Features List
                Column(
                  children: features.map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: buttonColor.withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.check,
                              color: buttonColor,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[200],
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Enhanced Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: buttonColor.withAlpha(102),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20, color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          buttonText,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
