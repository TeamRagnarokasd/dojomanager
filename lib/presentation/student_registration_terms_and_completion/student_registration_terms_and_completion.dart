import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../services/registration_data_manager.dart';
import '../../services/terms_document_service.dart';
import '../student_registration_personal_info/widgets/progress_indicator_widget.dart';

/// Step 4 of 4: Terms and Completion
/// Final step with terms acceptance and registration submission.
/// For 14-17 minors: shows specific terms, generates the 14-17 PDF, and shows 7-day warning.
class StudentRegistrationTermsAndCompletion extends StatefulWidget {
  const StudentRegistrationTermsAndCompletion({super.key});

  @override
  State<StudentRegistrationTermsAndCompletion> createState() =>
      _StudentRegistrationTermsAndCompletionState();
}

class _StudentRegistrationTermsAndCompletionState
    extends State<StudentRegistrationTermsAndCompletion> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _isSubmitting = false;
  late bool _isMinor1417;

  @override
  void initState() {
    super.initState();
    _isMinor1417 = RegistrationDataManager.isMinor1417();
    _loadExistingData();
  }

  void _loadExistingData() {
    _termsAccepted = RegistrationDataManager.termsAccepted;
    _privacyAccepted = RegistrationDataManager.privacyAccepted;
  }

  bool _isFormValid() {
    return _termsAccepted && _privacyAccepted;
  }

  void _goBack() {
    RegistrationDataManager.termsAccepted = _termsAccepted;
    RegistrationDataManager.privacyAccepted = _privacyAccepted;
    Navigator.pop(context);
  }

  Future<void> _completeRegistration() async {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('student_registration.must_accept_terms'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final nome = RegistrationDataManager.nome ?? '';
      final cognome = RegistrationDataManager.cognome ?? '';
      final email = RegistrationDataManager.email ?? '';
      final password = RegistrationDataManager.password ?? '';
      final telefono = RegistrationDataManager.telefono ?? '';
      final codFisc = RegistrationDataManager.codiceFiscale ?? '';
      final indirizzo = RegistrationDataManager.indirizzoResidenza ?? '';
      final citta = RegistrationDataManager.citta ?? '';
      final cap = RegistrationDataManager.cap ?? '';
      final provincia = RegistrationDataManager.provincia ?? '';
      final dataNascita = RegistrationDataManager.dataNascita;
      final luogoNascita = RegistrationDataManager.luogoNascita ?? '';

      final emergencyContacts = RegistrationDataManager.emergencyContacts;
      String? emergencyContact;
      String? emergencyPhone;
      if (emergencyContacts.isNotEmpty) {
        emergencyContact = emergencyContacts[0]['nome'];
        emergencyPhone = emergencyContacts[0]['telefono'];
      }

      final parentGuardianName = RegistrationDataManager.parentGuardianName;
      final parentGuardianSurname =
          RegistrationDataManager.parentGuardianSurname;
      final parentGuardianCodiceFiscale =
          RegistrationDataManager.parentGuardianCodiceFiscale;
      final parentGuardianEmail = RegistrationDataManager.parentGuardianEmail;
      final parentGuardianPhone = RegistrationDataManager.parentGuardianPhone;
      final parentGuardianRelation =
          RegistrationDataManager.parentGuardianRelation;
      final parentGuardianDocumentType =
          RegistrationDataManager.parentGuardianDocumentType;
      final parentGuardianDocumentNumber =
          RegistrationDataManager.parentGuardianDocumentNumber;

      // 1. Create Auth user
      final authRes = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      if (authRes.user == null) {
        throw Exception(
          "Errore Auth: Creazione utente fallita. Verifica i dati inseriti.",
        );
      }

      if (authRes.user!.identities != null &&
          authRes.user!.identities!.isEmpty) {
        throw Exception(
          "Questa email è già registrata. Usa un'altra email o accedi con le credenziali esistenti.",
        );
      }

      // 2. Upsert user profile via SECURITY DEFINER RPC (bypasses RLS during registration)
      final isMinorFlag =
          RegistrationDataManager.isMinor1417() ||
          RegistrationDataManager.isUnder14();

      // Retry loop: up to 3 attempts with 500ms delay between retries
      // to handle the case where the auth.users row is not yet visible to the DB
      // immediately after signUp().
      bool profileUpsertSuccess = false;
      dynamic profileUpsertError;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final profileResult = await Supabase.instance.client.rpc(
            'upsert_registration_profile',
            params: {
              'p_user_id': authRes.user!.id,
              'p_email': email.toLowerCase().trim(),
              'p_full_name': '$nome $cognome',
              'p_first_name': nome,
              'p_last_name': cognome,
              'p_phone': telefono,
              'p_birth_date': dataNascita != null
                  ? '${dataNascita.year.toString().padLeft(4, '0')}-${dataNascita.month.toString().padLeft(2, '0')}-${dataNascita.day.toString().padLeft(2, '0')}'
                  : null,
              'p_birth_place': luogoNascita,
              'p_codice_fiscale': codFisc.toUpperCase(),
              'p_address_line': indirizzo,
              'p_city': citta,
              'p_province': provincia.toUpperCase(),
              'p_cap': cap,
              'p_emergency_contact': emergencyContact ?? '',
              'p_emergency_phone': emergencyPhone ?? '',
              'p_is_minor': isMinorFlag,
              'p_parent_guardian_name': isMinorFlag ? parentGuardianName : null,
              'p_parent_guardian_surname': isMinorFlag
                  ? parentGuardianSurname
                  : null,
              'p_parent_guardian_codice_fiscale': isMinorFlag
                  ? parentGuardianCodiceFiscale
                  : null,
              'p_parent_guardian_email': isMinorFlag
                  ? parentGuardianEmail
                  : null,
              'p_parent_guardian_phone': isMinorFlag
                  ? parentGuardianPhone
                  : null,
              'p_parent_guardian_relation': isMinorFlag
                  ? parentGuardianRelation
                  : null,
            },
          );
          if (profileResult is Map && profileResult['success'] == false) {
            final errMsg = profileResult['error'] ?? 'Errore sconosciuto';
            if (errMsg.toString().contains('già registrata')) {
              throw Exception(errMsg);
            }
            print('upsert_registration_profile warning: $errMsg');
          }
          profileUpsertSuccess = true;
          break;
        } catch (e) {
          profileUpsertError = e;
          print('REGISTRATION STEP 2 attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }

      if (!profileUpsertSuccess) {
        // All retries exhausted — show specific error and do NOT proceed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Si è verificato un errore durante il salvataggio del tuo profilo. '
              'Il tuo account è stato creato ma i dati non sono stati salvati. '
              'Contatta il supporto indicando la tua email: $email',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // 3. Save terms document
      bool termsDocSaved = true;
      try {
        if (_isMinor1417 &&
            parentGuardianName != null &&
            parentGuardianSurname != null &&
            parentGuardianCodiceFiscale != null &&
            parentGuardianDocumentNumber != null) {
          // Generate the 14-17 specific PDF form
          final birthDateStr = dataNascita != null
              ? '${dataNascita.day.toString().padLeft(2, '0')}/${dataNascita.month.toString().padLeft(2, '0')}/${dataNascita.year}'
              : '';
          await TermsDocumentService().saveMinor1417TermsDocument(
            userId: authRes.user!.id,
            minorFullName: '$nome $cognome',
            minorTaxCode: codFisc,
            minorBirthDate: birthDateStr,
            parentFullName: '$parentGuardianName $parentGuardianSurname',
            parentTaxCode: parentGuardianCodiceFiscale,
            parentDocumentNumber:
                '${parentGuardianDocumentType ?? ''} N. $parentGuardianDocumentNumber',
            userEmail: email,
          );
        } else {
          // Standard terms document for adults / under-14
          await TermsDocumentService().saveTermsAcceptanceDocument(
            userId: authRes.user!.id,
            userName: '$nome $cognome',
            userEmail: email,
          );
        }
      } catch (termsError) {
        termsDocSaved = false;
        print('REGISTRATION STEP 3 (terms document) failed: $termsError');
      }

      // 4. Insert into pending_registrations via SECURITY DEFINER RPC
      try {
        final message = parentGuardianName != null
            ? 'Nuova registrazione studente: $nome $cognome (MINORE 14-17 - Genitore/Tutore: $parentGuardianName $parentGuardianSurname)'
            : 'Nuova registrazione studente: $nome $cognome';
        await Supabase.instance.client.rpc(
          'create_pending_registration',
          params: {
            'p_email': email.toLowerCase().trim(),
            'p_full_name': '$nome $cognome',
            'p_phone': telefono,
            'p_message': message,
          },
        );
      } catch (pendingError) {
        debugPrint(
          'Non-critical: create_pending_registration RPC failed: $pendingError',
        );
      }

      // Sign out after registration
      await Supabase.instance.client.auth.signOut();

      // 5. Reset manager
      RegistrationDataManager.reset();

      if (!mounted) return;

      // Show warning if terms document failed (registration still succeeded)
      if (!termsDocSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registrazione completata. Il documento dei termini non è stato salvato e verrà ri-richiesto al prossimo accesso.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 8),
          ),
        );
      }

      // 6. Show success dialog (with 7-day warning for 14-17 minors)
      if (_isMinor1417) {
        _showMinor1417SuccessDialog();
      } else {
        _showStandardSuccessDialog();
      }
    } catch (e) {
      if (!mounted) return;

      if (kDebugMode) {
        print('REGISTRATION ERROR: $e');
      }

      String errorMessage;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('user already registered') ||
          errorStr.contains('already registered') ||
          errorStr.contains('email già registrata') ||
          errorStr.contains('questa email è già registrata')) {
        errorMessage =
            'Questa email è già registrata nel sistema. Usa un\'altra email oppure contatta l\'amministratore.';
      } else {
        errorMessage = 'student_registration.registration_error'.tr(
          namedArgs: {'error': e.toString()},
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showStandardSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Registrazione Completata!',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: Text(
          'La tua registrazione è stata completata con successo. Attendi l\'approvazione dell\'amministratore.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('student_registration.go_to_login'.tr()),
          ),
        ],
      ),
    );
  }

  void _showMinor1417SuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Registrazione Completata!',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La tua registrazione è stata completata con successo.',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 2.h),
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF8C00),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFF8C00),
                          size: 22,
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            'AZIONE RICHIESTA ENTRO 7 GIORNI',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF8C00),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      'Troverà il modulo PDF da stampare e far firmare nella sezione Profilo della propria area personale.\n\n'
                      'Nella stessa pagina sarà possibile caricare il modulo firmato unitamente al documento d\'identità del genitore/tutore legale.\n\n'
                      'Si ricorda che il completamento di questa procedura è obbligatorio entro e non oltre 7 giorni dalla data di registrazione.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Acceda alla sezione "Profilo" per procedere con il caricamento dei documenti richiesti.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                'Attendi l\'approvazione dell\'amministratore per accedere all\'app.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Ho capito, vai al Login',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
          onPressed: _isSubmitting ? null : _goBack,
        ),
        title: const Text(
          'Registrazione Studente',
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
            currentStep: 4,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4. Termini e Condizioni',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    _isMinor1417
                        ? 'Modulo specifico per minori di età 14-17 anni'
                        : 'Leggi e accetta i termini per completare la registrazione',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: _isMinor1417
                          ? const Color(0xFFFF8C00)
                          : Colors.grey.shade400,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  if (_isMinor1417) _buildMinor1417WarningBanner(),
                  if (_isMinor1417) SizedBox(height: 2.h),
                  _buildTermsSection(),
                  SizedBox(height: 4.h),
                ],
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
                      onPressed: _isSubmitting ? null : _goBack,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isSubmitting
                              ? Colors.grey
                              : const Color(0xFFFF0000),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size(double.infinity, 6.h),
                      ),
                      child: Text(
                        'Indietro',
                        style: TextStyle(
                          color: _isSubmitting
                              ? Colors.grey
                              : const Color(0xFFFF0000),
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
                      onPressed: _isFormValid() && !_isSubmitting
                          ? _completeRegistration
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0000),
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size(double.infinity, 6.h),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Completa Registrazione',
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

  Widget _buildMinor1417WarningBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C00).withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF8C00), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF8C00),
                size: 22,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'ATTENZIONE – AZIONE RICHIESTA ENTRO 7 GIORNI',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF8C00),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'Il modulo PDF da stampare e far firmare è disponibile nella sezione Profilo. Nella stessa pagina sarà possibile caricare il modulo firmato unitamente al documento d\'identità del genitore/tutore legale, entro e non oltre 7 giorni dalla registrazione.',
            style: TextStyle(fontSize: 11.sp, color: Colors.white, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    final termsText = _isMinor1417
        ? _getMinor1417TermsPreviewText()
        : _getStandardTermsText();

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
            _isMinor1417
                ? 'Modulo di Iscrizione Minore (14-17 anni) e Consenso Genitoriale'
                : 'Modulo di Iscrizione e Regolamento Interno',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            height: 35.h,
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF404040)),
            ),
            child: SingleChildScrollView(
              child: Text(
                termsText,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade300,
                  height: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),
          CheckboxListTile(
            value: _termsAccepted,
            onChanged: (value) =>
                setState(() => _termsAccepted = value ?? false),
            activeColor: const Color(0xFFFF0000),
            checkColor: Colors.white,
            title: Text(
              _isMinor1417
                  ? 'Accetto i Termini e Condizioni, il Regolamento Minori (14-17 anni) e il Codice Etico Genitori'
                  : 'Accetto i Termini e Condizioni',
              style: TextStyle(fontSize: 13.sp, color: Colors.white),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            value: _privacyAccepted,
            onChanged: (value) =>
                setState(() => _privacyAccepted = value ?? false),
            activeColor: const Color(0xFFFF0000),
            checkColor: Colors.white,
            title: Text(
              _isMinor1417
                  ? 'Accetto il trattamento dei dati personali (GDPR) del minore e del genitore, e la liberatoria per la diffusione di immagini'
                  : 'Accetto il trattamento dei dati personali (GDPR)',
              style: TextStyle(fontSize: 13.sp, color: Colors.white),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50).withAlpha(77),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF00A8FF),
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    _isMinor1417
                        ? 'La registrazione sarà soggetta ad approvazione. Il PDF da firmare e i documenti richiesti sono disponibili nella sezione Profilo entro 7 giorni.'
                        : 'La tua registrazione sarà soggetta ad approvazione da parte dell\'amministratore',
                    style: TextStyle(fontSize: 11.sp, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMinor1417TermsPreviewText() {
    final nome = RegistrationDataManager.nome ?? '';
    final cognome = RegistrationDataManager.cognome ?? '';
    final cf = RegistrationDataManager.codiceFiscale ?? '';
    final dataNascita = RegistrationDataManager.dataNascita;
    final birthStr = dataNascita != null
        ? '${dataNascita.day.toString().padLeft(2, '0')}/${dataNascita.month.toString().padLeft(2, '0')}/${dataNascita.year}'
        : '';
    final parentName = RegistrationDataManager.parentGuardianName ?? '';
    final parentSurname = RegistrationDataManager.parentGuardianSurname ?? '';
    final parentCF = RegistrationDataManager.parentGuardianCodiceFiscale ?? '';
    final docType = RegistrationDataManager.parentGuardianDocumentType ?? '';
    final docNum = RegistrationDataManager.parentGuardianDocumentNumber ?? '';

    return '''MODULO DI ISCRIZIONE MINORE (14-17 ANNI), REGOLAMENTO INTERNO E CONSENSO GENITORIALE
TEAM RAGNAROK A.S.D.
================================================================================

1. ACCETTAZIONE DEL REGOLAMENTO, CONDOTTA DEL MINORE E CODICE ETICO GENITORI/TUTORI

A) Condotta del Minore:
Il sottoscritto minore (di età compresa tra i 14 e i 17 anni) dichiara di aver preso visione e di accettare integralmente il regolamento interno del Team Ragnarok A.S.D.
Il minore si impegna a mantenere un comportamento rispettoso, disciplinato e leale verso gli istruttori, i compagni di squadra, gli avversari e le strutture. È severamente vietato qualsiasi atto di bullismo, violenza verbale o fisica non sportiva, dentro e fuori dal campo di allenamento.

B) Autorizzazione, Manleva e Codice di Comportamento dei Genitori e Tutori Legali:
Il genitore/tutore legale autorizza la partecipazione del minore alle attività sportive e promozionali del Team Ragnarok A.S.D.
I genitori/tutori si impegnano a sostenere il percorso sportivo del minore in modo sano e positivo.

--------------------------------------------------------------------------------

2. LIBERATORIA PER LA DIFFUSIONE DI IMMAGINI DI MINORI (FOTOGRAFIE E VIDEO)

I sottoscritti autorizzano il Team Ragnarok A.S.D. alla ripresa, trasmissione e pubblicazione delle immagini ritraenti il minore durante gli allenamenti, le competizioni e gli eventi ufficiali del team.

--------------------------------------------------------------------------------

3. CONSENSO AL TRATTAMENTO DEI DATI PERSONALI (GDPR UE 2016/679)

Si autorizza il Team Ragnarok A.S.D. al trattamento dei dati personali del minore e del genitore per le finalità associative e di legge.

================================================================================
DATI DI ACCETTAZIONE (AUTOCOMPILATI):

Minore: $nome $cognome | C.F.: $cf | Nato il: $birthStr
Genitore/Tutore: $parentName $parentSurname | C.F.: $parentCF | Doc.: $docType N. $docNum

Firma per esteso del Minore (14-17 anni): ____________________________________

Firma per esteso del Genitore / Tutore Legale: ____________________________________

(È obbligatorio allegare copia del documento d'identità del genitore/tutore legale)
================================================================================
Documento generato automaticamente dall'app Team Ragnarok ASD''';
  }

  String _getStandardTermsText() {
    return '''MODULO DI ISCRIZIONE E REGOLAMENTO INTERNO
TEAM RAGNAROK A.S.D.
============================================================

1. ACCETTAZIONE DEL REGOLAMENTO E COMPORTAMENTO

Con la presente iscrizione, il sottoscritto (o il genitore/tutore legale per i minori) dichiara di aver preso visione e di accettare integralmente il regolamento interno del Team Ragnarok.

Il partecipante si impegna a mantenere un comportamento rispettoso e leale verso gli istruttori, i compagni di squadra, gli avversari e chiunque sia presente durante gli allenamenti, gli eventi e le competizioni.

È severamente vietato commettere atti che costituiscano reato o che siano contrari alla legge. Qualsiasi comportamento illegale o gravemente scorretto comporterà l'immediata espulsione dal team, senza diritto a rimborso.

------------------------------------------------------------

2. LIBERATORIA PER LA DIFFUSIONE DI IMMAGINI (FOTOGRAFIE E VIDEO)

Il sottoscritto acconsente alla ripresa e alla pubblicazione di proprie immagini, fotografie e/o video realizzati durante gli allenamenti, le competizioni, gli stage o qualsiasi altro evento ufficiale del Team Ragnarok.

Le immagini potranno essere pubblicate sui canali ufficiali del Team Ragnarok, inclusi sito web, profili social media, materiale promozionale e articoli di giornale.

------------------------------------------------------------

3. CONSENSO AL TRATTAMENTO DEI DATI PERSONALI (GDPR)

Con la presente, ai sensi del Regolamento UE 2016/679 (GDPR), si autorizza il Team Ragnarok al trattamento dei dati personali forniti in questo modulo per le finalità associative e di legge.

============================================================
DICHIARAZIONE DI ACCETTAZIONE

Il sottoscritto dichiara di aver letto, compreso e accettato integralmente:
[X] I Termini e Condizioni del Regolamento Interno
[X] Il trattamento dei dati personali (GDPR)
[X] La liberatoria per la diffusione di immagini
============================================================''';
  }
}
