import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math';

import './supabase_service.dart';

class UserProfileService {
  static final _supabase = Supabase.instance.client;

  // Get user profile by ID
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response =
          await _supabase
              .from('user_profiles')
              .select('*')
              .eq('id', userId)
              .single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch user profile: $e');
    }
  }

  // Update user profile
  static Future<void> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? birthDate,
    String? birthPlace,
    String? address,
    String? city,
    String? province,
    String? cap,
    String? taxCode, // 🎯 FIX 5: ADD TAX CODE UPDATE
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (fullName != null) updateData['full_name'] = fullName;
      if (phone != null) updateData['phone'] = phone;
      if (birthDate != null) updateData['birth_date'] = birthDate;
      if (birthPlace != null) updateData['birth_place'] = birthPlace;
      if (address != null) updateData['address_line'] = address;
      if (city != null) updateData['city'] = city;
      if (province != null) updateData['province'] = province;
      if (cap != null) updateData['cap'] = cap;
      if (taxCode != null)
        updateData['tax_code'] =
            taxCode.toUpperCase(); // 🎯 Allow tax code update
      if (emergencyContact != null)
        updateData['emergency_contact'] = emergencyContact;
      if (emergencyPhone != null)
        updateData['emergency_phone'] = emergencyPhone;

      await _supabase.from('user_profiles').update(updateData).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Upload profile photo to Supabase storage
  Future<Map<String, dynamic>> uploadProfilePhoto(XFile imageFile) async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'Utente non autenticato'};
      }

      // Get file bytes based on platform
      Uint8List imageBytes;
      String fileName;

      if (kIsWeb) {
        imageBytes = await imageFile.readAsBytes();
        fileName = imageFile.name;
      } else {
        final file = File(imageFile.path);
        imageBytes = await file.readAsBytes();
        fileName =
            imageFile.name.isNotEmpty
                ? imageFile.name
                : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last.toLowerCase();
      final uniqueFileName = 'profile_${user.id}_$timestamp.$fileExtension';

      // Upload to Supabase Storage
      final uploadResponse = await client.storage
          .from('profile-images')
          .uploadBinary(uniqueFileName, imageBytes);

      // Get public URL
      final publicUrl = client.storage
          .from('profile-images')
          .getPublicUrl(uniqueFileName);

      // Update user profile with new image URL
      await client
          .from('user_profiles')
          .update({
            'profile_image_url': publicUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      return {
        'success': true,
        'profile_image_url': publicUrl,
        'message': 'Foto profilo aggiornata con successo!',
      };
    } catch (e) {
      print('Error in uploadProfilePhoto: $e');
      return {
        'success': false,
        'message': 'Errore durante l\'aggiornamento della foto: $e',
      };
    }
  }

  /// Upload medical certificate to private storage
  Future<Map<String, dynamic>> uploadMedicalCertificate(
    XFile certificateFile,
  ) async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        return {'success': false, 'message': 'Utente non autenticato'};
      }

      // Get file bytes based on platform
      Uint8List fileBytes;
      String fileName;

      if (kIsWeb) {
        fileBytes = await certificateFile.readAsBytes();
        fileName = certificateFile.name;
      } else {
        final file = File(certificateFile.path);
        fileBytes = await file.readAsBytes();
        fileName =
            certificateFile.name.isNotEmpty
                ? certificateFile.name
                : 'certificate_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last.toLowerCase();
      final uniqueFileName =
          'medical_cert_${user.id}_$timestamp.$fileExtension';

      // Upload to private medical-certificates bucket
      final uploadResponse = await client.storage
          .from('medical-certificates')
          .uploadBinary(uniqueFileName, fileBytes);

      // Create signed URL for private access (valid for 1 year)
      final signedUrl = await client.storage
          .from('medical-certificates')
          .createSignedUrl(uniqueFileName, 31536000); // 1 year in seconds

      // Update user profile with medical certificate info
      await client
          .from('user_profiles')
          .update({
            'medical_certificate_url': signedUrl,
            'medical_certificate_status': 'pending_review',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      return {
        'success': true,
        'certificate_url': signedUrl,
        'message': 'Certificato medico caricato con successo!',
      };
    } catch (e) {
      print('Error in uploadMedicalCertificate: $e');
      return {
        'success': false,
        'message': 'Errore durante il caricamento del certificato: $e',
      };
    }
  }

  /// Update medical certificate with complete details including start and end dates
  Future<Map<String, dynamic>> updateMedicalCertificateComplete({
    required String userId,
    required String certificateUrl,
    DateTime? startDate,
    DateTime? expiryDate,
    String? doctorName,
    String? medicalCenter,
    String? certificateType,
    String certificateStatus = 'pending',
  }) async {
    try {
      final response = await _supabase.rpc(
        'update_user_medical_certificate_complete',
        params: {
          'user_uuid': userId,
          'certificate_url': certificateUrl,
          'start_date': startDate?.toIso8601String().split('T')[0],
          'expiry_date': expiryDate?.toIso8601String().split('T')[0],
          'doctor_name': doctorName,
          'medical_center': medicalCenter,
          'certificate_type': certificateType,
          'certificate_status': certificateStatus,
        },
      );

      if (response != null && response['success'] == true) {
        return {'success': true, 'data': response};
      } else {
        return {
          'success': false,
          'error': response?['error'] ?? 'Unknown error occurred',
        };
      }
    } catch (e) {
      print('Error updating medical certificate: $e');
      return {
        'success': false,
        'error': 'Failed to update medical certificate: $e',
      };
    }
  }

  // Get complete medical certificate details
  Future<Map<String, dynamic>> getMedicalCertificateDetails(
    String userId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_user_medical_certificate_details',
        params: {'user_uuid': userId},
      );

      if (response != null && response['success'] == true) {
        return {
          'success': true,
          'data': {
            'medical_certificate_url': response['medical_certificate_url'],
            'medical_certificate_start_date':
                response['medical_certificate_start_date'] != null
                    ? DateTime.parse(response['medical_certificate_start_date'])
                    : null,
            'medical_certificate_expiry':
                response['medical_certificate_expiry'] != null
                    ? DateTime.parse(response['medical_certificate_expiry'])
                    : null,
            'medical_certificate_doctor_name':
                response['medical_certificate_doctor_name'],
            'medical_certificate_medical_center':
                response['medical_certificate_medical_center'],
            'medical_certificate_type': response['medical_certificate_type'],
            'medical_certificate_status':
                response['medical_certificate_status'],
          },
        };
      } else {
        return {
          'success': false,
          'error': response?['error'] ?? 'Unknown error occurred',
        };
      }
    } catch (e) {
      print('Error getting medical certificate details: $e');
      return {
        'success': false,
        'error': 'Failed to get medical certificate details: $e',
      };
    }
  }

  // Get user upload status with automatic signed URL regeneration
  Future<Map<String, dynamic>> getUserUploadStatus() async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        print('❌ getUserUploadStatus: No authenticated user');
        return {
          'success': false,
          'profile_image_uploaded': false,
          'medical_certificate_uploaded': false,
          'medical_certificate_status': 'pending',
        };
      }

      print('📥 Fetching user profile for user: ${user.id}');

      final response =
          await client
              .from('user_profiles')
              .select('''
            profile_image_url, 
            medical_certificate_url, 
            medical_certificate_status,
            medical_certificate_start_date,
            medical_certificate_expiry,
            medical_certificate_doctor_name,
            medical_certificate_medical_center,
            medical_certificate_type
          ''')
              .eq('id', user.id)
              .single();

      print('✅ Profile data retrieved: ${response.keys.join(", ")}');

      String? certificateUrl = response['medical_certificate_url'];

      // Always regenerate signed URL for medical certificates to prevent bucket errors
      if (certificateUrl != null && certificateUrl.isNotEmpty) {
        print(
          '📄 Certificate URL found: ${certificateUrl.substring(0, min(50, certificateUrl.length))}...',
        );

        try {
          // Extract filename from the URL
          final uri = Uri.parse(certificateUrl);
          final pathSegments = uri.pathSegments;

          // Find the actual filename (not the sign segment)
          final fileName = pathSegments.lastWhere(
            (segment) => segment.isNotEmpty && !segment.startsWith('sign'),
            orElse: () => pathSegments.last.split('?').first,
          );

          print('📝 Certificate filename: $fileName');

          // Generate new signed URL (valid for 7 days)
          certificateUrl = await client.storage
              .from('medical-certificates')
              .createSignedUrl(fileName, 604800); // 7 days

          print('✅ New signed URL generated successfully');

          // Update the database with new signed URL
          await client
              .from('user_profiles')
              .update({
                'medical_certificate_url': certificateUrl,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', user.id);

          print('✅ Database updated with new signed URL');
        } catch (e) {
          print('⚠️ Error regenerating signed URL: $e');
          // Set certificate URL to null if regeneration fails to prevent errors
          certificateUrl = null;
        }
      } else {
        print('ℹ️ No medical certificate URL found in database');
      }

      return {
        'success': true,
        'profile_image_uploaded': response['profile_image_url'] != null,
        'medical_certificate_uploaded':
            certificateUrl != null && certificateUrl.isNotEmpty,
        'medical_certificate_url': certificateUrl,
        'medical_certificate_status':
            response['medical_certificate_status'] ?? 'pending',
        'medical_certificate_start_date':
            response['medical_certificate_start_date'],
        'medical_certificate_expiry': response['medical_certificate_expiry'],
        'medical_certificate_doctor_name':
            response['medical_certificate_doctor_name'],
        'medical_certificate_medical_center':
            response['medical_certificate_medical_center'],
        'medical_certificate_type': response['medical_certificate_type'],
      };
    } catch (e) {
      print('❌ Error getting upload status: $e');
      return {
        'success': false,
        'profile_image_uploaded': false,
        'medical_certificate_uploaded': false,
        'medical_certificate_status': 'pending',
      };
    }
  }

  // Keep existing methods for backward compatibility
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final client = SupabaseService.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return null;

    final response =
        await client
            .from('user_profiles')
            .select()
            .eq('id', user.id)
            .single();

    return response;
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    DateTime? birthDate,
    String? birthPlace,
    String? address,
    String? city,
    String? cap,
    String? province,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    final client = SupabaseService.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return false;

    final updateData = <String, dynamic>{};

    if (fullName != null) updateData['full_name'] = fullName;
    if (phone != null) updateData['phone'] = phone;
    if (birthDate != null)
      updateData['birth_date'] = birthDate.toIso8601String();
    if (birthPlace != null) updateData['birth_place'] = birthPlace;
    if (address != null) updateData['address_line'] = address;
    if (city != null) updateData['city'] = city;
    if (cap != null) updateData['cap'] = cap;
    if (province != null) updateData['province'] = province;
    if (emergencyContact != null)
      updateData['emergency_contact'] = emergencyContact;
    if (emergencyPhone != null) updateData['emergency_phone'] = emergencyPhone;

    updateData['updated_at'] = DateTime.now().toIso8601String();

    await client.from('user_profiles').update(updateData).eq('id', user.id);

    return true;
  }

  Future<Map<String, dynamic>?> getUserSubscription() async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final response = await client
          .from('user_subscriptions')
          .select('''
            *,
            subscription_plans(
              name,
              description,
              price,
              entry_count,
              plan_type
            )
          ''')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);

      return response.isNotEmpty ? response.first : null;
    } catch (e) {
      print('Error fetching user subscription: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getUserProgress() async {
    try {
      final client = SupabaseService.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return {};

      final attendanceResponse = await client
          .from('subscription_entry_usage')
          .select('used_at')
          .eq('user_id', user.id)
          .order('used_at', ascending: false);

      final subscription = await getUserSubscription();

      final totalClasses = attendanceResponse.length;
      final thisMonthClasses =
          attendanceResponse.where((entry) {
            final usedAt = DateTime.parse(entry['used_at']);
            final now = DateTime.now();
            return usedAt.year == now.year && usedAt.month == now.month;
          }).length;

      return {
        'total_classes': totalClasses,
        'this_month_classes': thisMonthClasses,
        'current_plan':
            subscription?['subscription_plans']?['name'] ??
            'Nessun piano attivo',
        'remaining_entries': subscription?['entries_remaining'] ?? 0,
      };
    } catch (e) {
      print('Error fetching user progress: $e');
      return {};
    }
  }
}