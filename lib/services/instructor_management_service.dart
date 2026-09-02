import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './supabase_service.dart';

class InstructorManagementService {
  final SupabaseService _supabaseService = SupabaseService.instance;

  // Update the available disciplines to match the schema - replace "prep_atletica" with "fitness"
  final List<String> availableDisciplines = [
    'bjj',
    'mma',
    'sambo',
    'grappling',
    'fitness', // Fixed: Changed from 'prep_atletica' to match database enum
  ];

  // Method to get display name for disciplines
  String getDisciplineDisplayName(String discipline) {
    switch (discipline) {
      case 'bjj':
        return 'BJJ';
      case 'mma':
        return 'MMA';
      case 'sambo':
        return 'SAMBO';
      case 'grappling':
        return 'GRAPPLING';
      case 'fitness': // Fixed: Updated to match database enum
        return 'Prep. Atletica'; // Fixed: Changed from 'FITNESS' to 'Prep. Atletica'
      default:
        return discipline.toUpperCase();
    }
  }

  /// Get all instructors for management
  static Future<List<Map<String, dynamic>>> getAllInstructors() async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('''
            id,
            full_name,
            email,
            phone,
            profile_image_url,
            role,
            is_active,
            status,
            created_at,
            updated_at
          ''')
          .inFilter('role', [
            'instructor',
            'instructor_admin',
            'instructor_student',
          ])
          .order('full_name');

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching all instructors: $error');
      throw Exception('Errore nel caricamento degli istruttori: $error');
    }
  }

  /// Get instructor details by ID
  static Future<Map<String, dynamic>?> getInstructorDetails(
    String instructorId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('''
            id,
            full_name,
            email,
            phone,
            profile_image_url,
            role,
            is_active,
            status,
            birth_date,
            emergency_contact,
            emergency_phone,
            medical_certificate_status,
            created_at,
            updated_at,
            approved_at,
            approved_by
          ''')
          .eq('id', instructorId)
          .single();

      return response;
    } catch (error) {
      print('Error fetching instructor details: $error');
      return null;
    }
  }

  /// Update instructor profile information (static version)
  static Future<Map<String, dynamic>?> updateInstructorProfile({
    required String instructorId,
    String? fullName,
    String? phone,
    String? emergencyContact,
    String? emergencyPhone,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (emergencyContact != null)
        updates['emergency_contact'] = emergencyContact;
      if (emergencyPhone != null) updates['emergency_phone'] = emergencyPhone;
      if (isActive != null) updates['is_active'] = isActive;

      final response = await Supabase.instance.client
          .from('user_profiles')
          .update(updates)
          .eq('id', instructorId)
          .select()
          .single();

      return response;
    } catch (error) {
      print('Error updating instructor profile: $error');
      throw Exception(
        'Errore nell\'aggiornamento del profilo istruttore: $error',
      );
    }
  }

  /// Update instructor (alias for updateInstructorProfile - static version)
  static Future<Map<String, dynamic>?> updateInstructor({
    required String instructorId,
    String? fullName,
    String? phone,
    String? emergencyContact,
    String? emergencyPhone,
    bool? isActive,
  }) async {
    return updateInstructorProfile(
      instructorId: instructorId,
      fullName: fullName,
      phone: phone,
      emergencyContact: emergencyContact,
      emergencyPhone: emergencyPhone,
      isActive: isActive,
    );
  }

  /// Upload instructor profile image
  static Future<String?> uploadInstructorImage({
    required String instructorId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final path = 'instructors/$instructorId/$fileName';

      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('profile-images')
          .uploadBinary(
            path,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl(path);

      // Update user profile with new image URL
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'profile_image_url': publicUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', instructorId);

      return publicUrl;
    } catch (error) {
      print('Error uploading instructor image: $error');
      throw Exception('Errore nel caricamento dell\'immagine: $error');
    }
  }

  /// Get instructor's teaching disciplines
  static Future<List<String>> getInstructorDisciplines(
    String instructorId,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('weekly_schedule_templates')
          .select('discipline')
          .eq('instructor_id', instructorId);

      final disciplines = response
          .map((item) => item['discipline'] as String)
          .toSet()
          .toList();

      return disciplines;
    } catch (error) {
      print('Error fetching instructor disciplines: $error');
      return [];
    }
  }

  /// Get instructor's schedule statistics
  static Future<Map<String, dynamic>> getInstructorStats(
    String instructorId,
  ) async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // Get total classes this month
      final totalClassesResponse = await Supabase.instance.client
          .from('schedule_instances')
          .select('id')
          .eq('instructor_id', instructorId)
          .gte('class_date', firstDayOfMonth.toIso8601String().split('T')[0])
          .lte('class_date', lastDayOfMonth.toIso8601String().split('T')[0]);

      // Get completed classes this month
      final completedClassesResponse = await Supabase.instance.client
          .from('schedule_instances')
          .select('id')
          .eq('instructor_id', instructorId)
          .eq('is_cancelled', false)
          .gte('class_date', firstDayOfMonth.toIso8601String().split('T')[0])
          .lt('class_date', DateTime.now().toIso8601String().split('T')[0]);

      // Get upcoming classes
      final upcomingClassesResponse = await Supabase.instance.client
          .from('schedule_instances')
          .select('id')
          .eq('instructor_id', instructorId)
          .eq('is_cancelled', false)
          .gte('class_date', DateTime.now().toIso8601String().split('T')[0]);

      // Get cancelled classes this month
      final cancelledClassesResponse = await Supabase.instance.client
          .from('schedule_instances')
          .select('id')
          .eq('instructor_id', instructorId)
          .eq('is_cancelled', true)
          .gte('class_date', firstDayOfMonth.toIso8601String().split('T')[0])
          .lte('class_date', lastDayOfMonth.toIso8601String().split('T')[0]);

      return {
        'total_classes_month': totalClassesResponse.length,
        'completed_classes': completedClassesResponse.length,
        'upcoming_classes': upcomingClassesResponse.length,
        'cancelled_classes': cancelledClassesResponse.length,
        'completion_rate': totalClassesResponse.length > 0
            ? ((completedClassesResponse.length / totalClassesResponse.length) *
                      100)
                  .round()
            : 0,
      };
    } catch (error) {
      print('Error fetching instructor stats: $error');
      return {
        'total_classes_month': 0,
        'completed_classes': 0,
        'upcoming_classes': 0,
        'cancelled_classes': 0,
        'completion_rate': 0,
      };
    }
  }

  /// Update instructor role (admin only)
  static Future<bool> updateInstructorRole(
    String instructorId,
    String newRole,
  ) async {
    try {
      // Verify current user has admin privileges
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final currentUserResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('role')
          .eq('id', currentUserId)
          .single();

      final currentUserRole = currentUserResponse['role'] as String;
      if (![
        'admin',
        'instructor_admin',
        'principal_admin',
      ].contains(currentUserRole)) {
        return false;
      }

      // Update instructor role
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'role': newRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', instructorId);

      return true;
    } catch (error) {
      print('Error updating instructor role: $error');
      return false;
    }
  }

  /// Deactivate/Activate instructor
  static Future<bool> toggleInstructorStatus(
    String instructorId,
    bool isActive,
  ) async {
    try {
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', instructorId);

      return true;
    } catch (error) {
      print('Error toggling instructor status: $error');
      return false;
    }
  }

  /// Get instructor's recent activity
  static Future<List<Map<String, dynamic>>> getInstructorActivity(
    String instructorId, {
    int limit = 20,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('schedule_instances')
          .select('''
            id,
            class_date,
            start_time,
            end_time,
            discipline,
            location,
            is_cancelled,
            created_at,
            updated_at
          ''')
          .eq('instructor_id', instructorId)
          .order('updated_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      print('Error fetching instructor activity: $error');
      return [];
    }
  }

  /// Delete instructor profile image
  static Future<bool> deleteInstructorImage(String instructorId) async {
    try {
      // Get current image URL to extract path
      final profileResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('profile_image_url')
          .eq('id', instructorId)
          .single();

      final imageUrl = profileResponse['profile_image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Extract path from URL
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length > 3) {
          final path = pathSegments.sublist(3).join('/');

          // Delete from storage
          await Supabase.instance.client.storage.from('profile-images').remove([
            path,
          ]);
        }
      }

      // Update profile to remove image URL
      await Supabase.instance.client
          .from('user_profiles')
          .update({
            'profile_image_url': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', instructorId);

      return true;
    } catch (error) {
      print('Error deleting instructor image: $error');
      return false;
    }
  }

  /// Get all instructors with their user profile information
  Future<List<Map<String, dynamic>>> getAllInstructorsWithProfiles() async {
    try {
      // 1. Fetch instructors who have a full instructor_profiles entry
      final response = await _supabaseService.client
          .from('instructor_profiles')
          .select('''
            *,
            user_profiles!inner(
              id,
              full_name,
              email,
              phone,
              is_active,
              status,
              role,
              profile_image_url
            )
          ''')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> fullInstructors = response
          .map<Map<String, dynamic>>((item) {
            final instructor = Map<String, dynamic>.from(item);
            final userProfile =
                instructor['user_profiles'] as Map<String, dynamic>;

            return {
              'instructor_id': instructor['id'],
              'user_id': instructor['user_id'],
              'full_name': userProfile['full_name'],
              'email': userProfile['email'],
              'phone': userProfile['phone'],
              'profile_image_url':
                  instructor['profile_image_url'] ??
                  userProfile['profile_image_url'],
              'bio': instructor['bio'],
              'primary_discipline': instructor['primary_discipline'],
              'disciplines': instructor['disciplines'],
              'specializations': instructor['specializations'],
              'years_experience': instructor['years_experience'],
              'achievements': instructor['achievements'],
              'certifications': instructor['certifications'],
              'languages': instructor['languages'],
              'is_active': instructor['is_active'],
              'join_date': instructor['join_date'],
              'created_at': instructor['created_at'],
              'user_status': userProfile['status'],
              'user_role': userProfile['role'],
              'profile_incomplete': false,
            };
          })
          .toList();

      // 2. Collect user_ids that already have a full instructor profile
      final Set<String> existingUserIds = fullInstructors
          .map((i) => i['user_id'] as String)
          .toSet();

      // 3. Fetch users with role='instructor' who don't have an instructor_profiles entry
      final usersResponse = await _supabaseService.client
          .from('user_profiles')
          .select(
            'id, full_name, email, phone, profile_image_url, is_active, status, role, created_at',
          )
          .inFilter('role', [
            'instructor',
            'instructor_student',
            'instructor_admin',
          ]);

      final List<Map<String, dynamic>> incompleteInstructors = [];
      for (final user in usersResponse) {
        final userId = user['id'] as String;
        if (!existingUserIds.contains(userId)) {
          incompleteInstructors.add({
            'instructor_id': null,
            'user_id': userId,
            'full_name': user['full_name'],
            'email': user['email'],
            'phone': user['phone'],
            'profile_image_url': user['profile_image_url'],
            'bio': null,
            'primary_discipline': null,
            'disciplines': null,
            'specializations': null,
            'years_experience': null,
            'achievements': null,
            'certifications': null,
            'languages': null,
            'is_active': user['is_active'] ?? true,
            'join_date': null,
            'created_at': user['created_at'],
            'user_status': user['status'],
            'user_role': user['role'],
            'profile_incomplete': true,
          });
        }
      }

      // 4. Incomplete profiles appear first so they are visible at the top
      return [...incompleteInstructors, ...fullInstructors];
    } catch (e) {
      throw Exception('Errore nel caricamento degli istruttori: $e');
    }
  }

  /// Get all users who can be promoted to instructors (including admins)
  Future<List<Map<String, dynamic>>> getApprovedStudents() async {
    try {
      final response = await _supabaseService.client
          .from('user_profiles')
          .select('*')
          .neq('role', 'instructor')
          .order('full_name', ascending: true);

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Errore nel caricamento degli utenti: $e');
    }
  }

  /// Promote a student to instructor
  Future<void> promoteStudentToInstructor(String userId) async {
    try {
      // Start a transaction-like operation
      // 1. Update user role to instructor
      await _supabaseService.client
          .from('user_profiles')
          .update({'role': 'instructor'})
          .eq('id', userId);

      // 2. Create instructor profile with basic information
      await _supabaseService.client.from('instructor_profiles').insert({
        'user_id': userId,
        'bio': 'Nuovo istruttore promosso. Biografia da completare.',
        'primary_discipline': 'bjj', // Default, can be changed later
        'disciplines': ['bjj'], // Default, can be changed later
        'years_experience': 1,
        'is_active': true,
        'join_date': DateTime.now().toIso8601String().split('T')[0],
      });
    } catch (e) {
      throw Exception('Errore nella promozione dello studente: $e');
    }
  }

  /// Creates a new instructor with comprehensive data handling - ENHANCED VERSION
  Future<void> createNewInstructor(Map<String, dynamic> instructorData) async {
    final user = _supabaseService.client.auth.currentUser;

    if (user == null) {
      throw Exception('Utente non autenticato');
    }

    try {
      print('🔄 Starting instructor creation process...');

      // Extract image data
      final XFile? imageFile = instructorData['profile_image_file'] as XFile?;
      final Uint8List? webImageBytes =
          instructorData['web_image_bytes'] as Uint8List?;
      String? profileImageUrl;

      // Handle image upload if provided
      if (imageFile != null) {
        print('📸 Processing profile image...');
        profileImageUrl = await _uploadProfileImage(imageFile, webImageBytes);
        if (profileImageUrl != null) {
          print('✅ Profile image uploaded successfully');
        }
      }

      // Prepare function parameters
      final params = {
        'instructor_email': instructorData['email'],
        'instructor_name': instructorData['full_name'],
        'instructor_password':
            instructorData['password'], // NEW: Include password
        'instructor_phone': instructorData['phone'],
        'instructor_bio': instructorData['bio'],
        'primary_discipline': instructorData['primary_discipline'],
        'selected_disciplines': instructorData['disciplines'],
        'years_of_experience': instructorData['years_experience'],
        'profile_image_url': profileImageUrl,
      };

      print(
        '📤 Calling database function with parameters: ${params.keys.toList()}',
      );

      // Use the database function to create instructor profile
      final result = await _supabaseService.client.rpc(
        'create_instructor_profile',
        params: params,
      );

      print('📥 Database function result: $result');

      // Check if the function call was successful
      final success = result['success'] as bool? ?? false;
      if (!success) {
        final error =
            result['error'] as String? ??
            'Errore sconosciuto nella creazione dell\'istruttore';
        print('❌ Database function reported error: $error');
        throw Exception(error);
      }

      final userId = result['user_id'] as String?;
      final message = result['message'] as String?;

      print('✅ Instructor created successfully');
      print('👤 New instructor ID: $userId');
      print('📝 Success message: $message');
    } catch (e) {
      print('❌ Error in createNewInstructor: $e');

      if (e.toString().contains('duplicate key value') ||
          e.toString().contains('esiste già nel sistema')) {
        throw Exception('Un istruttore con questa email esiste già');
      } else if (e.toString().contains('permission denied') ||
          e.toString().contains('amministratori possono')) {
        throw Exception(
          'Autorizzazioni insufficienti per creare l\'istruttore',
        );
      } else if (e.toString().contains('violates foreign key constraint')) {
        throw Exception(
          'Errore nella creazione del profilo utente. Verifica che tutti i dati siano corretti',
        );
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        throw Exception(
          'Errore di connessione. Verifica la tua connessione internet e riprova',
        );
      } else {
        throw Exception(
          'Errore nella creazione dell\'istruttore: ${e.toString()}',
        );
      }
    }
  }

  /// Completes the instructor profile for a user already promoted to instructor role.
  /// This does NOT create a new auth user — it only inserts/updates the instructor_profiles entry.
  Future<void> completeInstructorProfile(
    String userId,
    Map<String, dynamic> instructorData,
  ) async {
    try {
      print('🔄 Completing instructor profile for user: $userId');

      // Extract image data
      final XFile? imageFile = instructorData['profile_image_file'] as XFile?;
      final Uint8List? webImageBytes =
          instructorData['web_image_bytes'] as Uint8List?;
      String? profileImageUrl;

      // Handle image upload if provided
      if (imageFile != null) {
        print('📸 Processing profile image...');
        profileImageUrl = await _uploadProfileImage(imageFile, webImageBytes);
        if (profileImageUrl != null) {
          print('✅ Profile image uploaded successfully');
          // Also update user_profiles with the new image
          await _supabaseService.client
              .from('user_profiles')
              .update({
                'profile_image_url': profileImageUrl,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', userId);
        }
      }

      final profileData = {
        'user_id': userId,
        'bio': instructorData['bio'] ?? '',
        'primary_discipline': instructorData['primary_discipline'],
        'disciplines': instructorData['disciplines'] ?? [],
        'years_experience': instructorData['years_experience'] ?? 1,
        'achievements': instructorData['achievements'] ?? [],
        'certifications': instructorData['certifications'] ?? [],
        'languages': instructorData['languages'] ?? [],
        'is_active': true,
        'join_date': DateTime.now().toIso8601String().split('T')[0],
        if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      };

      // Upsert so it works even if a partial record already exists
      await _supabaseService.client
          .from('instructor_profiles')
          .upsert(profileData, onConflict: 'user_id');

      print('✅ Instructor profile completed successfully');
    } catch (e) {
      print('❌ Error completing instructor profile: $e');
      throw Exception('Errore nel completamento del profilo istruttore: $e');
    }
  }

  /// Generate a temporary password for new instructors
  String _generateTemporaryPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'Temp${random}!';
  }

  /// Upload profile image with cross-platform support
  Future<String?> _uploadProfileImage(
    XFile imageFile,
    Uint8List? webBytes,
  ) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'instructor_${timestamp}_${imageFile.name}';

      Uint8List imageData;

      if (kIsWeb) {
        // On web, use provided bytes or read from file
        if (webBytes != null) {
          imageData = webBytes;
        } else {
          imageData = await imageFile.readAsBytes();
        }
      } else {
        // On mobile, read from file path
        final file = File(imageFile.path);
        imageData = await file.readAsBytes();
      }

      if (imageData.isEmpty) {
        print('⚠️ Image data is empty, skipping upload');
        return null;
      }

      // Upload to Supabase Storage
      final uploadPath = await _supabaseService.client.storage
          .from('instructor-images')
          .uploadBinary(fileName, imageData);

      // Get public URL
      final publicUrl = _supabaseService.client.storage
          .from('instructor-images')
          .getPublicUrl(fileName);

      print('✅ Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      // Don't fail the entire operation for image upload issues
      return null;
    }
  }

  /// Update instructor profile (instance version)
  Future<void> updateInstructorDetails(
    String instructorId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      await _supabaseService.client
          .from('instructor_profiles')
          .update(updateData)
          .eq('id', instructorId);
    } catch (e) {
      throw Exception('Errore nell\'aggiornamento del profilo: $e');
    }
  }

  /// Update instructor profile (instance version - renamed to avoid conflict)
  Future<void> updateInstructorProfileDetails(
    String instructorId,
    Map<String, dynamic> updateData,
  ) async {
    return updateInstructorDetails(instructorId, updateData);
  }

  /// Update instructor profile (instance version - alias for updateInstructorDetails)
  Future<void> updateInstructorProfileInstance(
    String instructorId,
    Map<String, dynamic> updateData,
  ) async {
    return updateInstructorDetails(instructorId, updateData);
  }

  /// Delete instructor profile (and optionally demote to student)
  Future<void> deleteInstructorProfile(String instructorId) async {
    try {
      // Get instructor details first
      final instructor = await _supabaseService.client
          .from('instructor_profiles')
          .select('user_id')
          .eq('id', instructorId)
          .single();

      final userId = instructor['user_id'];

      // 1. Delete instructor profile
      await _supabaseService.client
          .from('instructor_profiles')
          .delete()
          .eq('id', instructorId);

      // 2. Demote user to student role
      await _supabaseService.client
          .from('user_profiles')
          .update({'role': 'student'})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Errore nell\'eliminazione dell\'istruttore: $e');
    }
  }

  /// Get instructor statistics
  Future<Map<String, dynamic>> getInstructorStatistics() async {
    try {
      final response = await _supabaseService.client
          .from('instructor_profiles')
          .select('is_active, disciplines, primary_discipline');

      final total = response.length;
      final active = response.where((i) => i['is_active'] == true).length;

      // Count disciplines
      final disciplineCount = <String, int>{};
      for (final instructor in response) {
        final disciplines = instructor['disciplines'] as List<dynamic>?;
        if (disciplines != null) {
          for (final discipline in disciplines) {
            disciplineCount[discipline] =
                (disciplineCount[discipline] ?? 0) + 1;
          }
        }
      }

      return {
        'total_instructors': total,
        'active_instructors': active,
        'inactive_instructors': total - active,
        'discipline_distribution': disciplineCount,
      };
    } catch (e) {
      throw Exception('Errore nel caricamento delle statistiche: $e');
    }
  }

  /// Search instructors by name or discipline
  Future<List<Map<String, dynamic>>> searchInstructors({
    String? query,
    String? discipline,
    bool? isActive,
  }) async {
    try {
      var queryBuilder = _supabaseService.client
          .from('instructor_profiles')
          .select('''
            *,
            user_profiles!inner(
              id,
              full_name,
              email,
              phone,
              is_active,
              status,
              role
            )
          ''');

      if (isActive != null) {
        queryBuilder = queryBuilder.eq('is_active', isActive);
      }

      if (discipline != null && discipline != 'Tutte') {
        queryBuilder = queryBuilder.contains('disciplines', [discipline]);
      }

      final response = await queryBuilder.order('created_at', ascending: false);

      var filteredResults = response.map<Map<String, dynamic>>((item) {
        final instructor = Map<String, dynamic>.from(item);
        final userProfile = instructor['user_profiles'] as Map<String, dynamic>;

        return {
          'instructor_id': instructor['id'],
          'user_id': instructor['user_id'],
          'full_name': userProfile['full_name'],
          'email': userProfile['email'],
          'phone': userProfile['phone'],
          'profile_image_url': instructor['profile_image_url'],
          'bio': instructor['bio'],
          'primary_discipline': instructor['primary_discipline'],
          'disciplines': instructor['disciplines'],
          'specializations': instructor['specializations'],
          'years_experience': instructor['years_experience'],
          'achievements': instructor['achievements'],
          'certifications': instructor['certifications'],
          'languages': instructor['languages'],
          'is_active': instructor['is_active'],
          'join_date': instructor['join_date'],
          'created_at': instructor['created_at'],
        };
      }).toList();

      // Apply text search filter on client side
      if (query != null && query.isNotEmpty) {
        final searchLower = query.toLowerCase();
        filteredResults = filteredResults.where((instructor) {
          final name = instructor['full_name']?.toString().toLowerCase() ?? '';
          final email = instructor['email']?.toString().toLowerCase() ?? '';
          return name.contains(searchLower) || email.contains(searchLower);
        }).toList();
      }

      return filteredResults;
    } catch (e) {
      throw Exception('Errore nella ricerca degli istruttori: $e');
    }
  }
}
