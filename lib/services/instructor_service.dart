import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class InstructorProfile {
  final String id;
  final String userId;
  final String? bio;
  final int? yearsExperience;
  final String primaryDiscipline;
  final List<String> disciplines;
  final List<String> specializations;
  final List<String> certifications;
  final List<String> achievements;
  final List<String> languages;
  final String? profileImageUrl;
  final bool isActive;
  final Map<String, dynamic>? availabilitySchedule;
  final Map<String, dynamic>? contactInfo;
  final Map<String, dynamic>? socialMedia;
  final List<dynamic>? studentTestimonials;
  final DateTime? joinDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Additional fields from user_profiles join
  final String? fullName;
  final String? email;
  final String? roleTitle;

  InstructorProfile({
    required this.id,
    required this.userId,
    this.bio,
    this.yearsExperience,
    required this.primaryDiscipline,
    required this.disciplines,
    required this.specializations,
    required this.certifications,
    required this.achievements,
    required this.languages,
    this.profileImageUrl,
    required this.isActive,
    this.availabilitySchedule,
    this.contactInfo,
    this.socialMedia,
    this.studentTestimonials,
    this.joinDate,
    this.createdAt,
    this.updatedAt,
    this.fullName,
    this.email,
    this.roleTitle,
  });

  factory InstructorProfile.fromMap(Map<String, dynamic> map) {
    return InstructorProfile(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      bio: map['bio'],
      yearsExperience: map['years_experience'],
      primaryDiscipline: map['primary_discipline'] ?? '',
      disciplines: List<String>.from(map['disciplines'] ?? []),
      specializations: List<String>.from(map['specializations'] ?? []),
      certifications: List<String>.from(map['certifications'] ?? []),
      achievements: List<String>.from(map['achievements'] ?? []),
      languages: List<String>.from(map['languages'] ?? []),
      profileImageUrl: map['profile_image_url'],
      isActive: map['is_active'] ?? true,
      availabilitySchedule: map['availability_schedule'],
      contactInfo: map['contact_info'],
      socialMedia: map['social_media'],
      studentTestimonials: map['student_testimonials'],
      joinDate: map['join_date'] != null
          ? DateTime.parse(map['join_date'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
      fullName: map['full_name'],
      email: map['email'],
      roleTitle: map['role_title'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'bio': bio,
      'years_experience': yearsExperience,
      'primary_discipline': primaryDiscipline,
      'disciplines': disciplines,
      'specializations': specializations,
      'certifications': certifications,
      'achievements': achievements,
      'languages': languages,
      'profile_image_url': profileImageUrl,
      'is_active': isActive,
      'availability_schedule': availabilitySchedule,
      'contact_info': contactInfo,
      'social_media': socialMedia,
      'student_testimonials': studentTestimonials,
      'join_date': joinDate?.toIso8601String(),
    };
  }

  // Helper methods for UI
  String get experienceText => yearsExperience != null
      ? '+ di $yearsExperience anni di esperienza'
      : 'N/A';
  String get disciplinesText => disciplines.join(', ');
  String get specializationsText => specializations.join(' • ');
  String get languagesText => languages.join(', ');

  // Get display image URL (public bucket)
  String? get displayImageUrl {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) return null;

    // If it's already a full URL, return it as-is
    if (profileImageUrl!.startsWith('http://') ||
        profileImageUrl!.startsWith('https://')) {
      return profileImageUrl;
    }

    // Otherwise, construct the public URL from the filename
    return Supabase.instance.client.storage
        .from('instructor-images')
        .getPublicUrl(profileImageUrl!);
  }
}

class InstructorService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all active instructors with their user profile information
  static Future<List<InstructorProfile>> getInstructors({
    List<String>? disciplines,
    bool activeOnly = true,
  }) async {
    try {
      var query = _supabase.from('instructor_profiles').select('''
            *,
            user_profiles!inner (
              full_name,
              email,
              role,
              role_title
            )
          ''');

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      if (disciplines != null && disciplines.isNotEmpty) {
        query = query.overlaps('disciplines', disciplines);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List<dynamic>).map((data) {
        final instructorData = Map<String, dynamic>.from(data);
        final userProfile = instructorData['user_profiles'];

        if (userProfile != null) {
          instructorData['full_name'] = userProfile['full_name'];
          instructorData['email'] = userProfile['email'];
          instructorData['role_title'] = userProfile['role_title'];
        }

        return InstructorProfile.fromMap(instructorData);
      }).toList();
    } catch (e) {
      throw Exception('Error fetching instructors: $e');
    }
  }

  // Get instructor by ID
  static Future<InstructorProfile?> getInstructorById(
    String instructorId,
  ) async {
    try {
      final response = await _supabase
          .from('instructor_profiles')
          .select('''
            *,
            user_profiles!inner (
              full_name,
              email,
              role,
              role_title
            )
          ''')
          .eq('id', instructorId)
          .maybeSingle();

      if (response == null) return null;

      final instructorData = Map<String, dynamic>.from(response);
      final userProfile = instructorData['user_profiles'];

      if (userProfile != null) {
        instructorData['full_name'] = userProfile['full_name'];
        instructorData['email'] = userProfile['email'];
        instructorData['role_title'] = userProfile['role_title'];
      }

      return InstructorProfile.fromMap(instructorData);
    } catch (e) {
      throw Exception('Error fetching instructor: $e');
    }
  }

  // Get instructor by user ID
  static Future<InstructorProfile?> getInstructorByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('instructor_profiles')
          .select('''
            *,
            user_profiles!inner (
              full_name,
              email,
              role,
              role_title
            )
          ''')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      final instructorData = Map<String, dynamic>.from(response);
      final userProfile = instructorData['user_profiles'];

      if (userProfile != null) {
        instructorData['full_name'] = userProfile['full_name'];
        instructorData['email'] = userProfile['email'];
        instructorData['role_title'] = userProfile['role_title'];
      }

      return InstructorProfile.fromMap(instructorData);
    } catch (e) {
      throw Exception('Error fetching instructor by user ID: $e');
    }
  }

  // Create instructor profile (Admin only)
  static Future<InstructorProfile> createInstructorProfile({
    required String userId,
    required String bio,
    required int yearsExperience,
    required String primaryDiscipline,
    required List<String> disciplines,
    required List<String> specializations,
    required List<String> certifications,
    required List<String> achievements,
    required List<String> languages,
    String? profileImageUrl,
    Map<String, dynamic>? contactInfo,
    Map<String, dynamic>? socialMedia,
  }) async {
    try {
      final instructorData = {
        'user_id': userId,
        'bio': bio,
        'years_experience': yearsExperience,
        'primary_discipline': primaryDiscipline,
        'disciplines': disciplines,
        'specializations': specializations,
        'certifications': certifications,
        'achievements': achievements,
        'languages': languages,
        'profile_image_url': profileImageUrl,
        'contact_info': contactInfo ?? {},
        'social_media': socialMedia ?? {},
        'is_active': true,
      };

      final response = await _supabase
          .from('instructor_profiles')
          .insert(instructorData)
          .select()
          .single();

      return InstructorProfile.fromMap(response);
    } catch (e) {
      throw Exception('Error creating instructor profile: $e');
    }
  }

  // Update instructor profile
  static Future<InstructorProfile> updateInstructorProfile({
    required String instructorId,
    String? bio,
    int? yearsExperience,
    String? primaryDiscipline,
    List<String>? disciplines,
    List<String>? specializations,
    List<String>? certifications,
    List<String>? achievements,
    List<String>? languages,
    String? profileImageUrl,
    bool? isActive,
    Map<String, dynamic>? contactInfo,
    Map<String, dynamic>? socialMedia,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (bio != null) updateData['bio'] = bio;
      if (yearsExperience != null)
        updateData['years_experience'] = yearsExperience;
      if (primaryDiscipline != null)
        updateData['primary_discipline'] = primaryDiscipline;
      if (disciplines != null) updateData['disciplines'] = disciplines;
      if (specializations != null)
        updateData['specializations'] = specializations;
      if (certifications != null) updateData['certifications'] = certifications;
      if (achievements != null) updateData['achievements'] = achievements;
      if (languages != null) updateData['languages'] = languages;
      if (profileImageUrl != null)
        updateData['profile_image_url'] = profileImageUrl;
      if (isActive != null) updateData['is_active'] = isActive;
      if (contactInfo != null) updateData['contact_info'] = contactInfo;
      if (socialMedia != null) updateData['social_media'] = socialMedia;

      if (updateData.isEmpty) {
        throw Exception('No data provided for update');
      }

      final response = await _supabase
          .from('instructor_profiles')
          .update(updateData)
          .eq('id', instructorId)
          .select()
          .single();

      return InstructorProfile.fromMap(response);
    } catch (e) {
      throw Exception('Error updating instructor profile: $e');
    }
  }

  // Upload instructor profile image (Admin only)
  static Future<String> uploadInstructorImage({
    required String instructorId,
    required String filePath,
    required List<int> fileBytes,
  }) async {
    try {
      final fileName =
          '${instructorId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from('instructor-images')
          .uploadBinary(fileName, Uint8List.fromList(fileBytes));

      // Get public URL
      final publicUrl = _supabase.storage
          .from('instructor-images')
          .getPublicUrl(fileName);

      // Update instructor profile with new image URL
      await _supabase
          .from('instructor_profiles')
          .update({'profile_image_url': fileName})
          .eq('id', instructorId);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading instructor image: $e');
    }
  }

  // Delete instructor profile (Admin only)
  static Future<void> deleteInstructorProfile(String instructorId) async {
    try {
      // Get instructor profile to delete associated image
      final instructor = await getInstructorById(instructorId);

      if (instructor?.profileImageUrl != null) {
        // Delete image from storage
        await _supabase.storage.from('instructor-images').remove([
          instructor!.profileImageUrl!,
        ]);
      }

      // Delete instructor profile
      await _supabase
          .from('instructor_profiles')
          .delete()
          .eq('id', instructorId);
    } catch (e) {
      throw Exception('Error deleting instructor profile: $e');
    }
  }

  // Search instructors by name, discipline, or specialization
  static Future<List<InstructorProfile>> searchInstructors({
    required String query,
    List<String>? disciplines,
    bool activeOnly = true,
  }) async {
    try {
      var supabaseQuery = _supabase.from('instructor_profiles').select('''
            *,
            user_profiles!inner (
              full_name,
              email,
              role,
              role_title
            )
          ''');

      if (activeOnly) {
        supabaseQuery = supabaseQuery.eq('is_active', true);
      }

      final response = await supabaseQuery.order(
        'created_at',
        ascending: false,
      );

      List<InstructorProfile> instructors = (response as List<dynamic>).map((
        data,
      ) {
        final instructorData = Map<String, dynamic>.from(data);
        final userProfile = instructorData['user_profiles'];

        if (userProfile != null) {
          instructorData['full_name'] = userProfile['full_name'];
          instructorData['email'] = userProfile['email'];
          instructorData['role_title'] = userProfile['role_title'];
        }

        return InstructorProfile.fromMap(instructorData);
      }).toList();

      // Client-side filtering
      final searchQuery = query.toLowerCase();
      instructors = instructors.where((instructor) {
        return instructor.fullName?.toLowerCase().contains(searchQuery) ==
                true ||
            instructor.disciplines.any(
              (discipline) => discipline.toLowerCase().contains(searchQuery),
            ) ||
            instructor.specializations.any(
              (spec) => spec.toLowerCase().contains(searchQuery),
            );
      }).toList();

      // Additional discipline filtering if provided
      if (disciplines != null && disciplines.isNotEmpty) {
        instructors = instructors.where((instructor) {
          return disciplines.any(
            (discipline) => instructor.disciplines.contains(discipline),
          );
        }).toList();
      }

      return instructors;
    } catch (e) {
      throw Exception('Error searching instructors: $e');
    }
  }

  // Get instructors by discipline
  static Future<List<InstructorProfile>> getInstructorsByDiscipline(
    String discipline,
  ) async {
    return getInstructors(disciplines: [discipline]);
  }

  // Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('user_profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return false;

      final role = response['role'] as String?;
      return role == 'admin' || role == 'principal_admin';
    } catch (e) {
      return false;
    }
  }
}
