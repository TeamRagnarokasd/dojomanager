import 'package:supabase_flutter/supabase_flutter.dart';

class StudentRegistrationService {
  static final _supabase = Supabase.instance.client;

  static Future<void> submitRegistration({
    required String fullName,
    required String email,
    required String phone,
    required String birthDate,
    required String birthPlace,
    required String address,
    required String city,
    required String province,
    required String cap,
    required String taxCode, // 🎯 FIX 2: ADD TAX CODE PARAMETER
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? medicalCertificateUrl,
  }) async {
    try {
      // Call the database function to handle registration
      final response = await _supabase.rpc(
        'create_student_registration',
        params: {
          'p_full_name': fullName,
          'p_email': email,
          'p_phone': phone,
          'p_birth_date': birthDate,
          'p_birth_place': birthPlace,
          'p_address': address,
          'p_city': city,
          'p_province': province,
          'p_cap': cap,
          'p_tax_code': taxCode, // 🎯 Include tax code in registration
          'p_emergency_contact': emergencyContactName,
          'p_emergency_phone': emergencyContactPhone,
          'p_medical_certificate_url': medicalCertificateUrl,
        },
      );

      if (response == null) {
        throw Exception('Registration failed - no response from server');
      }
    } catch (e) {
      throw Exception('Failed to submit registration: $e');
    }
  }

  /// Registers a new student with Italian requirements and admin approval workflow
  /// ENHANCED: Updated to use the Supabase function with proper error handling and admin notification
  static Future<Map<String, dynamic>> registerStudent({
    required String email,
    required String password,
    required String nome,
    required String cognome,
    required String telefono,
    required DateTime dataNascita,
    required String codiceFiscale,
    required String indirizzoResidenza,
    required String citta,
    required String provincia,
    required String cap,
    required List<Map<String, String>> emergencyContacts,
    required List<Map<String, dynamic>> medicalDocuments,
    required bool termsAccepted,
    String? parentGuardianName,
    String? parentGuardianSurname,
    String? parentGuardianCodiceFiscale,
    String? parentGuardianEmail,
    String? parentGuardianPhone,
    String? parentGuardianRelation,
  }) async {
    try {
      print('🚀 Starting registration process for: $email');

      // SIMPLIFIED: Just ensure we're signed out before registration
      await _supabase.auth.signOut();

      // Validate required fields
      if (!termsAccepted) {
        throw Exception('Devi accettare i termini e condizioni per procedere');
      }

      if (emergencyContacts.isEmpty ||
          emergencyContacts.first['nome']?.isEmpty == true) {
        throw Exception('Almeno un contatto di emergenza è obbligatorio');
      }

      // Check if user is minor (under 18)
      final age = DateTime.now().difference(dataNascita).inDays ~/ 365;
      final isMinor = age < 18;

      // Validate parent data for minors
      if (isMinor) {
        if (parentGuardianName?.isEmpty ?? true) {
          throw Exception(
            'Informazioni genitore/tutore obbligatorie per i minorenni',
          );
        }
      }

      print('📋 Validating registration data...');
      // Validate registration data using the Supabase function
      final validationResult = await _supabase.rpc(
        'validate_student_registration',
        params: {
          'email': email.toLowerCase(),
          'codice_fiscale': codiceFiscale.toUpperCase(),
          'cap': cap,
          'provincia': provincia.toUpperCase(),
        },
      );

      if (validationResult != null && validationResult['valid'] == false) {
        throw Exception(
          validationResult['error'] ?? 'Dati di registrazione non validi',
        );
      }

      // REMOVED: All unnecessary user existence checks
      // Let Supabase handle duplicate detection naturally
      print('✅ Proceeding directly to registration');

      print('🔐 Creating Supabase Auth user...');
      // Step 1: Sign up the user with Supabase Auth
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': '$nome $cognome',
          'birth_date': dataNascita.toIso8601String(),
          'is_minor': isMinor,
        },
      );

      if (authResponse.user == null) {
        throw Exception(
          'Registrazione fallita. Verifica i dati inseriti e riprova.',
        );
      }

      print('👤 Creating user profile and pending registration...');
      // Step 2: Create user profile directly (with duplicate handling)
      try {
        // First check if profile already exists
        final existingProfile =
            await _supabase
                .from('user_profiles')
                .select('id')
                .eq('id', authResponse.user!.id)
                .maybeSingle();

        if (existingProfile != null) {
          print('⚠️ User profile already exists, skipping creation');
        } else {
          await _supabase.from('user_profiles').insert({
            'id': authResponse.user!.id,
            'email': email.toLowerCase().trim(),
            'full_name': '$nome $cognome',
            'phone': telefono,
            'birth_date': dataNascita.toIso8601String().split('T')[0],
            'codice_fiscale': codiceFiscale.toUpperCase(),
            'address_line': indirizzoResidenza,
            'city': citta,
            'province': provincia.toUpperCase(),
            'cap': cap,
            'emergency_contact':
                emergencyContacts.isNotEmpty
                    ? emergencyContacts.first['nome'] ?? ''
                    : '',
            'emergency_phone':
                emergencyContacts.isNotEmpty
                    ? emergencyContacts.first['telefono'] ?? ''
                    : '',
            'is_minor': isMinor,
            'role': 'student',
            'status': 'pending',
            'parent_guardian_name': isMinor ? parentGuardianName : null,
            'parent_guardian_surname': isMinor ? parentGuardianSurname : null,
            'parent_guardian_codice_fiscale':
                isMinor ? parentGuardianCodiceFiscale?.toUpperCase() : null,
            'parent_guardian_email': isMinor ? parentGuardianEmail : null,
            'parent_guardian_phone': isMinor ? parentGuardianPhone : null,
            'parent_guardian_relation': isMinor ? parentGuardianRelation : null,
            'medical_certificate_status': 'pending',
          });
          print('✅ User profile created successfully');
        }
      } catch (e) {
        print('❌ Error creating user profile: $e');
        // Try to clean up the auth user if profile creation failed
        try {
          await _cleanupFailedRegistration(authResponse.user!.id);
        } catch (cleanupError) {
          print(
            'Warning: Could not cleanup failed registration: $cleanupError',
          );
        }
        throw Exception('Errore durante la creazione del profilo utente: $e');
      }

      // Step 3: Create pending registration (with duplicate handling)
      try {
        // Check if pending registration already exists
        final existingPending =
            await _supabase
                .from('pending_registrations')
                .select('id')
                .eq('email', email.toLowerCase().trim())
                .maybeSingle();

        if (existingPending != null) {
          print('⚠️ Pending registration already exists, skipping creation');
        } else {
          await _supabase.from('pending_registrations').insert({
            'email': email.toLowerCase().trim(),
            'full_name': '$nome $cognome',
            'phone': telefono,
            'requested_role': 'student',
            'status': 'pending',
            'message':
                'Nuova richiesta di registrazione studente: $nome $cognome' +
                (isMinor && parentGuardianName != null
                    ? ' (MINORE - Genitore/Tutore: $parentGuardianName)'
                    : ''),
          });
          print('✅ Pending registration created successfully');
        }
      } catch (e) {
        print('⚠️ Warning: Could not create pending registration: $e');
        // Don't fail the registration if pending registration fails
      }

      print('📧 Sending admin notification...');
      // Step 4: Send admin notification
      await _sendAdminNotification(
        email,
        '$nome $cognome',
        isMinor,
        parentGuardianName,
      );

      // Step 5: Sign out user after all operations are complete
      await _supabase.auth.signOut();

      print('✅ Registration completed successfully');
      return {
        'success': true,
        'user_id': authResponse.user!.id,
        'email': email,
        'message':
            'Registrazione completata con successo!\n\n'
            '📋 La tua richiesta è stata inviata agli amministratori per l\'approvazione.\n'
            '📧 Riceverai una email di conferma una volta che la richiesta sarà approvata.\n'
            '⏳ Il processo di approvazione richiede normalmente 24-48 ore.',
        'requires_verification': true,
        'requires_admin_approval': true,
        'medical_cert_required': medicalDocuments.isEmpty,
        'status': 'pending_approval',
      };
    } catch (e) {
      print('❌ Registration error: $e');
      throw Exception('Errore durante la registrazione: $e');
    }
  }

  /// Sends explicit admin notification for new registration
  static Future<void> _sendAdminNotification(
    String email,
    String fullName,
    bool isMinor,
    String? parentGuardianName,
  ) async {
    try {
      final message =
          'Nuova richiesta di registrazione studente:\n\n'
          '👤 Nome: $fullName\n'
          '📧 Email: $email\n'
          '${isMinor && parentGuardianName != null ? '👨‍👩‍👧‍👦 MINORENNE - Genitore/Tutore: $parentGuardianName\n' : ''}'
          '⏰ Data richiesta: ${DateTime.now().toString().split('.')[0]}\n\n'
          '🔗 Accedi al pannello amministratore per approvare o rifiutare la registrazione.';

      // Send notification to all admins
      await _supabase.from('admin_communications').insert({
        'title': 'Nuova Registrazione in Attesa',
        'content': message,
        'priority': 'high',
        'target_audience': 'admin',
        'status': 'sent',
      });

      print('📧 Admin notification sent successfully');
    } catch (e) {
      print('⚠️ Warning: Failed to send admin notification: $e');
      // Don't fail the registration if notification fails
    }
  }

  /// Cleanup failed registration attempt
  static Future<void> _cleanupFailedRegistration(String userId) async {
    try {
      // Remove any partial data that might have been created
      await _supabase.from('user_profiles').delete().eq('id', userId);
    } catch (e) {
      print('Failed to cleanup registration: $e');
    }
  }

  /// Gets pending registrations count for admins
  static Future<int> getPendingRegistrationsCount() async {
    try {
      final response = await _supabase
          .from('pending_registrations')
          .select('id')
          .eq('status', 'pending');
      return (response as List).length;
    } catch (e) {
      print('Error getting pending registrations count: $e');
      return 0;
    }
  }

  /// Gets pending registrations for admin review
  static Future<List<Map<String, dynamic>>> getPendingRegistrations() async {
    try {
      final response = await _supabase
          .from('pending_registrations')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting pending registrations: $e');
      return [];
    }
  }

  /// Approves a user registration (admin only)
  static Future<bool> approveUserRegistration(
    String email,
    String? adminComment,
  ) async {
    try {
      final response = await _supabase.rpc(
        'approve_user_registration',
        params: {'user_email': email, 'admin_comment': adminComment},
      );

      if (response == true) {
        // Send approval notification to user
        await _sendUserApprovalNotification(email, true, adminComment);
      }

      return response == true;
    } catch (e) {
      print('Error approving user: $e');
      throw Exception('Errore durante l\'approvazione: $e');
    }
  }

  /// Rejects a user registration (admin only)
  static Future<bool> rejectUserRegistration(
    String email,
    String? rejectionReason,
  ) async {
    try {
      final response = await _supabase.rpc(
        'reject_user_registration',
        params: {'user_email': email, 'rejection_reason': rejectionReason},
      );

      if (response == true) {
        // Send rejection notification to user
        await _sendUserApprovalNotification(email, false, rejectionReason);
      }

      return response == true;
    } catch (e) {
      print('Error rejecting user: $e');
      throw Exception('Errore durante il rifiuto: $e');
    }
  }

  /// Send email notification to user about approval/rejection status
  static Future<void> _sendUserApprovalNotification(
    String email,
    bool approved,
    String? reason,
  ) async {
    try {
      // In a real implementation, you would integrate with an email service
      // For now, we'll create a user-specific communication record
      final message =
          approved
              ? '🎉 La tua registrazione è stata approvata!\n\n'
                  'Puoi ora accedere al tuo account e iniziare a utilizzare tutti i servizi.\n\n'
                  '${reason != null ? 'Note dall\'amministratore: $reason' : ''}'
              : '❌ La tua richiesta di registrazione è stata rifiutata.\n\n'
                  '${reason ?? 'Contatta l\'amministratore per maggiori informazioni.'}\n\n'
                  'Puoi presentare una nuova richiesta se ritieni sia stato un errore.';

      await _supabase.from('admin_communications').insert({
        'title':
            approved ? 'Registrazione Approvata' : 'Registrazione Rifiutata',
        'content': message,
        'priority': approved ? 'normal' : 'high',
        'target_audience': email, // Target specific user by email
        'status': 'sent',
      });

      print('📧 User notification sent to $email');
    } catch (e) {
      print('⚠️ Warning: Failed to send user notification: $e');
    }
  }

  /// Checks registration status for a user
  static Future<Map<String, dynamic>?> checkRegistrationStatus(
    String email,
  ) async {
    try {
      // Check user profile status
      final userProfile =
          await _supabase
              .from('user_profiles')
              .select('status, approved_at, approved_by, created_at')
              .eq('email', email.toLowerCase())
              .maybeSingle();

      if (userProfile == null) {
        return null;
      }

      // Check if there's a pending registration entry
      final pendingReg =
          await _supabase
              .from('pending_registrations')
              .select('status, reviewed_at, reviewed_by, created_at')
              .eq('email', email.toLowerCase())
              .maybeSingle();

      return {
        'user_status': userProfile['status'],
        'approved_at': userProfile['approved_at'],
        'created_at': userProfile['created_at'],
        'pending_review': pendingReg != null,
        'pending_status': pendingReg?['status'],
        'reviewed_at': pendingReg?['reviewed_at'],
      };
    } catch (e) {
      throw Exception('Errore verifica stato registrazione: $e');
    }
  }

  /// Validates Italian Codice Fiscale
  static bool validateCodiceFiscale(String codiceFiscale) {
    final regex = RegExp(r'^[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]$');
    return regex.hasMatch(codiceFiscale.toUpperCase()) &&
        codiceFiscale.length == 16;
  }

  /// Validates Italian CAP
  static bool validateCAP(String cap) {
    final regex = RegExp(r'^[0-9]{5}$');
    return regex.hasMatch(cap) && cap.length == 5;
  }

  /// Validates Italian Province Code
  static bool validateProvince(String provincia) {
    return provincia.length == 2 &&
        RegExp(r'^[A-Z]{2}$').hasMatch(provincia.toUpperCase());
  }

  /// Calculates age from birth date
  static int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Updates user profile data
  static Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _supabase.from('user_profiles').update(data).eq('id', userId);
    } catch (e) {
      throw Exception('Errore aggiornamento profilo: $e');
    }
  }

  /// Gets user profile by ID
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response =
          await _supabase
              .from('user_profiles')
              .select('*')
              .eq('id', userId)
              .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Errore caricamento profilo: $e');
    }
  }

  /// Signs out current user
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Force clear all authentication state
  static Future<void> forceSignOut() async {
    try {
      // Multiple sign out attempts to ensure complete cleanup
      await _supabase.auth.signOut();
      await Future.delayed(Duration(milliseconds: 300));
      await _supabase.auth.signOut();
      await Future.delayed(Duration(milliseconds: 300));

      // Verify user is signed out
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        print('⚠️ User still authenticated after force sign out');
        // Try one more time
        await _supabase.auth.signOut();
        await Future.delayed(Duration(milliseconds: 500));
      } else {
        print('✅ User successfully signed out');
      }
    } catch (e) {
      print('Error during force sign out: $e');
    }
  }

  /// Gets current user session
  static Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  /// Gets current user
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }
}
