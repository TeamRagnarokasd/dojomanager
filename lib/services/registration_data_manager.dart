/// Centralized Registration Data Manager
///
/// Static singleton class that holds ALL registration data throughout the multi-step process.
/// This ensures data persistence across navigation and eliminates "Missing Data" errors.
class RegistrationDataManager {
  // Private constructor for singleton pattern
  RegistrationDataManager._();

  // ========== STEP 1: Personal Information ==========
  static String? nome;
  static String? cognome;
  static String? email;
  static String? password;
  static String? telefono;
  static DateTime? dataNascita;
  static String? dataNascitaDisplay;
  static String? luogoNascita;

  // 🔥 CRITICAL: Tax Code field used for receipt generation
  static String? taxCode;

  // Legacy field name (for backward compatibility)
  static String? codiceFiscale;

  static String? indirizzoResidenza;
  static String? citta;
  static String? provincia;
  static String? cap;

  // ========== STEP 2: Emergency Contacts ==========
  static List<Map<String, String>> emergencyContacts = [];

  // ========== STEP 3: Medical Certificate (Optional) ==========
  static List<Map<String, dynamic>>? medicalDocuments;

  // ========== STEP 4: Terms Acceptance ==========
  static bool termsAccepted = false;
  static bool privacyAccepted = false;

  // ========== Optional Parent/Guardian Fields ==========
  static String? parentGuardianName;
  static String? parentGuardianSurname;
  static String? parentGuardianCodiceFiscale;
  static String? parentGuardianEmail;
  static String? parentGuardianPhone;
  static String? parentGuardianRelation;

  // ========== Parent/Guardian Document Fields (for 14-17 minor flow) ==========
  static String? parentGuardianDocumentType;
  static String? parentGuardianDocumentNumber;

  /// Reset all data (call when starting new registration or after successful submission)
  static void reset() {
    // Step 1
    nome = null;
    cognome = null;
    email = null;
    password = null;
    telefono = null;
    dataNascita = null;
    dataNascitaDisplay = null;
    luogoNascita = null;
    taxCode = null; // 🔥 ADDED: Reset taxCode field
    codiceFiscale = null;
    indirizzoResidenza = null;
    citta = null;
    provincia = null;
    cap = null;

    // Step 2
    emergencyContacts.clear();

    // Step 3
    medicalDocuments = null;

    // Step 4
    termsAccepted = false;
    privacyAccepted = false;

    // Optional Parent/Guardian
    parentGuardianName = null;
    parentGuardianSurname = null;
    parentGuardianCodiceFiscale = null;
    parentGuardianEmail = null;
    parentGuardianPhone = null;
    parentGuardianRelation = null;
    parentGuardianDocumentType = null;
    parentGuardianDocumentNumber = null;
  }

  /// Validate that all mandatory fields are filled before final submission
  static Map<String, dynamic> validateAndGetCompleteData() {
    // Validate Step 1 (Personal Info) - All mandatory
    if (nome == null || nome!.trim().isEmpty) {
      throw Exception('Nome mancante');
    }
    if (cognome == null || cognome!.trim().isEmpty) {
      throw Exception('Cognome mancante');
    }
    if (email == null || email!.trim().isEmpty) {
      throw Exception('Email mancante');
    }
    if (password == null || password!.isEmpty) {
      throw Exception('Password mancante');
    }
    if (telefono == null || telefono!.trim().isEmpty) {
      throw Exception('Telefono mancante');
    }
    if (dataNascita == null) {
      throw Exception('Data di nascita mancante');
    }
    if (luogoNascita == null || luogoNascita!.trim().isEmpty) {
      throw Exception('Luogo di nascita mancante');
    }
    if (codiceFiscale == null || codiceFiscale!.trim().isEmpty) {
      throw Exception('Codice fiscale mancante');
    }
    if (indirizzoResidenza == null || indirizzoResidenza!.trim().isEmpty) {
      throw Exception('Indirizzo di residenza mancante');
    }
    if (citta == null || citta!.trim().isEmpty) {
      throw Exception('Città mancante');
    }
    if (provincia == null || provincia!.trim().isEmpty) {
      throw Exception('Provincia mancante');
    }
    if (cap == null || cap!.trim().isEmpty) {
      throw Exception('CAP mancante');
    }

    // Validate Step 2 (Emergency Contacts) - At least one required
    if (emergencyContacts.isEmpty) {
      throw Exception('Almeno un contatto di emergenza è richiesto');
    }

    // Validate Step 4 (Terms) - Must be accepted
    if (!termsAccepted || !privacyAccepted) {
      throw Exception('Devi accettare termini e condizioni');
    }

    // Return complete validated data
    return {
      // Step 1
      'nome': nome!.trim(),
      'cognome': cognome!.trim(),
      'email': email!.trim().toLowerCase(),
      'password': password!,
      'telefono': telefono!.trim(),
      'dataNascita': dataNascita!,
      'dataNascitaDisplay': dataNascitaDisplay ?? '',
      'luogoNascita': luogoNascita!.trim(),
      'codiceFiscale': codiceFiscale!.trim().toUpperCase(),
      'indirizzoResidenza': indirizzoResidenza!.trim(),
      'citta': citta!.trim(),
      'provincia': provincia!.trim().toUpperCase(),
      'cap': cap!.trim(),

      // Step 2
      'emergencyContacts': emergencyContacts,

      // Step 3 (Optional)
      'medicalDocuments': medicalDocuments,

      // Step 4
      'termsAccepted': termsAccepted,
      'privacyAccepted': privacyAccepted,

      // Optional Parent/Guardian
      if (parentGuardianName != null) 'parentGuardianName': parentGuardianName,
      if (parentGuardianSurname != null)
        'parentGuardianSurname': parentGuardianSurname,
      if (parentGuardianCodiceFiscale != null)
        'parentGuardianCodiceFiscale': parentGuardianCodiceFiscale,
      if (parentGuardianEmail != null)
        'parentGuardianEmail': parentGuardianEmail,
      if (parentGuardianPhone != null)
        'parentGuardianPhone': parentGuardianPhone,
      if (parentGuardianRelation != null)
        'parentGuardianRelation': parentGuardianRelation,
      if (parentGuardianDocumentType != null)
        'parentGuardianDocumentType': parentGuardianDocumentType,
      if (parentGuardianDocumentNumber != null)
        'parentGuardianDocumentNumber': parentGuardianDocumentNumber,
    };
  }

  /// Check if we have data from previous steps (for back navigation)
  static bool hasPersonalInfo() {
    return nome != null && email != null;
  }

  static bool hasEmergencyContacts() {
    return emergencyContacts.isNotEmpty;
  }

  static bool hasMedicalCertificate() {
    return medicalDocuments != null && medicalDocuments!.isNotEmpty;
  }

  /// Returns true if the registered user is between 14 and 17 years old (inclusive).
  static bool isMinor1417() {
    if (dataNascita == null) return false;
    final today = DateTime.now();
    int age = today.year - dataNascita!.year;
    if (today.month < dataNascita!.month ||
        (today.month == dataNascita!.month && today.day < dataNascita!.day)) {
      age--;
    }
    return age >= 14 && age < 18;
  }

  /// Returns true if the registered user is under 14 years old.
  static bool isUnder14() {
    if (dataNascita == null) return false;
    final today = DateTime.now();
    int age = today.year - dataNascita!.year;
    if (today.month < dataNascita!.month ||
        (today.month == dataNascita!.month && today.day < dataNascita!.day)) {
      age--;
    }
    return age < 14;
  }
}
