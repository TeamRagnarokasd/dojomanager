import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing child/minor profiles linked to an adult guardian.
class ChildProfileService {
  static final _supabase = Supabase.instance.client;

  // ─── Active Profile State ────────────────────────────────────────────────

  /// Returns the currently active profile context.
  /// If [activeChildId] is null, the adult profile is active.
  static String? _activeChildProfileId;

  static String? get activeChildProfileId => _activeChildProfileId;

  static bool get isChildProfileActive => _activeChildProfileId != null;

  /// Sets the active profile to a child profile (or back to adult if null).
  static Future<void> setActiveProfile(String? childProfileId) async {
    _activeChildProfileId = childProfileId;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('user_profiles')
          .update({'active_child_profile_id': childProfileId})
          .eq('id', userId);
    } catch (e) {
      print('⚠️ ChildProfileService: could not persist active profile: $e');
    }
  }

  /// Loads the persisted active profile from the database on app start.
  static Future<void> loadActiveProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final row = await _supabase
          .from('user_profiles')
          .select('active_child_profile_id')
          .eq('id', userId)
          .maybeSingle();
      _activeChildProfileId = row?['active_child_profile_id'] as String?;
    } catch (e) {
      print('⚠️ ChildProfileService: could not load active profile: $e');
    }
  }

  /// Returns the user_id to use for purchases/subscriptions.
  /// If a child profile is active, returns the child profile id.
  /// Otherwise returns the authenticated adult user id.
  static String? getActiveUserId() {
    if (_activeChildProfileId != null) return _activeChildProfileId;
    return _supabase.auth.currentUser?.id;
  }

  // ─── CRUD ────────────────────────────────────────────────────────────────

  /// Fetches all child profiles for the current authenticated guardian.
  static Future<List<Map<String, dynamic>>> getChildProfiles() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utente non autenticato');
    try {
      final response = await _supabase
          .from('child_profiles')
          .select('*')
          .eq('guardian_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Errore nel caricamento dei profili figli: $e');
    }
  }

  /// Creates a new child profile linked to the current guardian.
  static Future<Map<String, dynamic>> createChildProfile({
    required String firstName,
    required String lastName,
    DateTime? birthDate,
    String? birthPlace,
    String? taxCode,
    String? phone,
    String? email,
    String? addressLine,
    String? city,
    String? province,
    String? cap,
    String? gender,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? medicalNotes,
    bool imageConsent = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utente non autenticato');
    try {
      final data = <String, dynamic>{
        'guardian_id': userId,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'is_active': true,
        'image_consent': imageConsent,
      };
      if (birthDate != null)
        data['birth_date'] = birthDate.toIso8601String().split('T')[0];
      if (birthPlace != null && birthPlace.isNotEmpty)
        data['birth_place'] = birthPlace.trim();
      if (taxCode != null && taxCode.isNotEmpty) {
        data['tax_code'] = taxCode.trim().toUpperCase();
        data['codice_fiscale'] = taxCode.trim().toUpperCase();
      }
      if (phone != null && phone.isNotEmpty) data['phone'] = phone.trim();
      if (email != null && email.isNotEmpty) data['email'] = email.trim();
      if (addressLine != null && addressLine.isNotEmpty)
        data['address_line'] = addressLine.trim();
      if (city != null && city.isNotEmpty) data['city'] = city.trim();
      if (province != null && province.isNotEmpty)
        data['province'] = province.trim();
      if (cap != null && cap.isNotEmpty) data['cap'] = cap.trim();
      if (gender != null && gender.isNotEmpty) data['gender'] = gender;
      if (emergencyContactName != null && emergencyContactName.isNotEmpty) {
        data['emergency_contact_name'] = emergencyContactName.trim();
      }
      if (emergencyContactPhone != null && emergencyContactPhone.isNotEmpty) {
        data['emergency_contact_phone'] = emergencyContactPhone.trim();
      }
      if (medicalNotes != null && medicalNotes.isNotEmpty)
        data['medical_notes'] = medicalNotes.trim();

      final response = await _supabase
          .from('child_profiles')
          .insert(data)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Errore nella creazione del profilo figlio: $e');
    }
  }

  /// Updates an existing child profile.
  static Future<Map<String, dynamic>> updateChildProfile({
    required String childProfileId,
    required String firstName,
    required String lastName,
    DateTime? birthDate,
    String? birthPlace,
    String? taxCode,
    String? phone,
    String? email,
    String? addressLine,
    String? city,
    String? province,
    String? cap,
    String? gender,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? medicalNotes,
  }) async {
    try {
      final data = <String, dynamic>{
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
      };
      if (birthDate != null)
        data['birth_date'] = birthDate.toIso8601String().split('T')[0];
      if (birthPlace != null) data['birth_place'] = birthPlace.trim();
      if (taxCode != null) {
        data['tax_code'] = taxCode.trim().toUpperCase();
        data['codice_fiscale'] = taxCode.trim().toUpperCase();
      }
      if (phone != null) data['phone'] = phone.trim();
      if (email != null) data['email'] = email.trim();
      if (addressLine != null) data['address_line'] = addressLine.trim();
      if (city != null) data['city'] = city.trim();
      if (province != null) data['province'] = province.trim();
      if (cap != null) data['cap'] = cap.trim();
      if (gender != null) data['gender'] = gender;
      if (emergencyContactName != null)
        data['emergency_contact_name'] = emergencyContactName.trim();
      if (emergencyContactPhone != null)
        data['emergency_contact_phone'] = emergencyContactPhone.trim();
      if (medicalNotes != null) data['medical_notes'] = medicalNotes.trim();

      final response = await _supabase
          .from('child_profiles')
          .update(data)
          .eq('id', childProfileId)
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Errore nell\'aggiornamento del profilo figlio: $e');
    }
  }

  /// Soft-deletes a child profile (sets is_active = false).
  static Future<void> deleteChildProfile(String childProfileId) async {
    try {
      // If this was the active profile, switch back to adult
      if (_activeChildProfileId == childProfileId) {
        await setActiveProfile(null);
      }
      await _supabase
          .from('child_profiles')
          .update({'is_active': false})
          .eq('id', childProfileId);
    } catch (e) {
      throw Exception('Errore nella rimozione del profilo figlio: $e');
    }
  }

  // ─── Medical Certificate ─────────────────────────────────────────────────

  /// Uploads a medical certificate for a child profile and updates the record.
  /// Returns the public URL of the uploaded file.
  static Future<String> uploadChildMedicalCertificate({
    required String childProfileId,
    required Uint8List fileBytes,
    required String fileName,
    DateTime? expiryDate,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utente non autenticato');
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final storagePath =
          'child_certificates/$userId/$childProfileId/${timestamp}_certificato.$ext';

      await _supabase.storage
          .from('user_docs')
          .uploadBinary(storagePath, fileBytes);

      final data = <String, dynamic>{
        'medical_certificate_url': storagePath,
        'medical_certificate_uploaded_at': DateTime.now().toIso8601String(),
        'medical_certificate_pending': false,
      };
      if (expiryDate != null) {
        data['medical_certificate_expiry_date'] = expiryDate
            .toIso8601String()
            .split('T')[0];
      }

      await _supabase
          .from('child_profiles')
          .update(data)
          .eq('id', childProfileId);

      return storagePath;
    } catch (e) {
      throw Exception('Errore nel caricamento del certificato: $e');
    }
  }

  /// Marks a child profile as having a pending medical certificate
  /// (registered without certificate — 30-day grace period).
  static Future<void> markChildCertificatePending(String childProfileId) async {
    try {
      await _supabase
          .from('child_profiles')
          .update({
            'medical_certificate_pending': true,
            'medical_certificate_url': null,
            'medical_certificate_uploaded_at': null,
          })
          .eq('id', childProfileId);
    } catch (e) {
      print('⚠️ ChildProfileService: could not mark certificate pending: $e');
    }
  }

  // ─── Profile Photo ───────────────────────────────────────────────────────

  /// Uploads a profile photo for a child profile and updates the record.
  /// Returns the storage path of the uploaded file.
  static Future<String> uploadChildProfilePhoto({
    required String childProfileId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Utente non autenticato');
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final storagePath =
          'child_photos/$userId/$childProfileId/${timestamp}_foto.$ext';

      await _supabase.storage
          .from('user_docs')
          .uploadBinary(storagePath, fileBytes);

      await _supabase
          .from('child_profiles')
          .update({'profile_photo_url': storagePath})
          .eq('id', childProfileId);

      return storagePath;
    } catch (e) {
      throw Exception('Errore nel caricamento della foto profilo: $e');
    }
  }

  /// Returns a signed URL for a child profile photo stored in user_docs bucket.
  static Future<String?> getChildProfilePhotoUrl(String storagePath) async {
    try {
      final response = await _supabase.storage
          .from('user_docs')
          .createSignedUrl(storagePath, 3600);
      return response;
    } catch (e) {
      return null;
    }
  }

  // ─── Discount Logic ──────────────────────────────────────────────────────

  /// Returns true if the current guardian has an active non-annual subscription,
  /// which unlocks the "Total Submission Kids" discount.
  static Future<bool> guardianHasActiveSubscription() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final result = await _supabase.rpc(
        'guardian_has_active_subscription',
        params: {'guardian_uuid': userId},
      );
      return result == true;
    } catch (e) {
      print('⚠️ ChildProfileService: discount check failed: $e');
      return false;
    }
  }

  /// Returns the discounted price for "Total Submission Kids" if the guardian
  /// has an active subscription, otherwise returns the standard price.
  static Future<double> getKidsDiscountedPrice({
    double standardPrice = 50.0,
    double discountedPrice = 45.0,
  }) async {
    final hasDiscount = await guardianHasActiveSubscription();
    return hasDiscount ? discountedPrice : standardPrice;
  }

  // ─── Receipt Helpers ─────────────────────────────────────────────────────

  /// Returns the guardian (adult) profile for receipt generation.
  /// Receipts for child purchases must be addressed to the adult guardian.
  static Future<Map<String, dynamic>?> getGuardianProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final response = await _supabase
          .from('user_profiles')
          .select(
            'id, full_name, first_name, last_name, email, tax_code, codice_fiscale, address_line, city, province, cap',
          )
          .eq('id', userId)
          .maybeSingle();
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      return null;
    }
  }

  /// Returns the active child profile data (if a child profile is active).
  static Future<Map<String, dynamic>?> getActiveChildProfile() async {
    if (_activeChildProfileId == null) return null;
    try {
      final response = await _supabase
          .from('child_profiles')
          .select('*')
          .eq('id', _activeChildProfileId!)
          .maybeSingle();
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      return null;
    }
  }

  /// Builds the "minor note" string for receipts when purchasing for a child.
  static String buildMinorNote(Map<String, dynamic> childProfile) {
    final name =
        childProfile['full_name'] as String? ??
        '${childProfile['first_name'] ?? ''} ${childProfile['last_name'] ?? ''}'
            .trim();
    final taxCode =
        childProfile['tax_code'] as String? ??
        childProfile['codice_fiscale'] as String? ??
        '';
    final birthDate = childProfile['birth_date'] as String? ?? '';
    final parts = <String>['Quota relativa al minore: $name'];
    if (taxCode.isNotEmpty) parts.add('C.F.: $taxCode');
    if (birthDate.isNotEmpty) parts.add('Data di nascita: $birthDate');
    return parts.join(' | ');
  }
}
